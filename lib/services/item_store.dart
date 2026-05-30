import 'package:flutter/foundation.dart';
import '../models/item.dart';
import '../models/item_scope.dart';
import 'supabase_service.dart';
import 'daily_usage_service.dart';
import 'ai/personal_regression_service.dart';
import 'ai/regression_coefficients.dart';

class ItemSaveEvent {
  const ItemSaveEvent({required this.scope, required this.serial});

  final ItemScope scope;
  final int serial;
}

/// 제품 상태 저장소
///
/// [ValueNotifier]를 상속하여 [ValueListenableBuilder]로 UI가 자동 갱신됩니다.
/// add / update / delete는 로컬 상태를 즉시 반영한 뒤 Supabase에 동기화합니다.
/// Supabase가 실패하면 이전 상태로 롤백하고 예외를 호출자에게 rethrow 합니다.
class ItemStore extends ValueNotifier<List<ConsumableItem>> {
  static final ItemStore instance = ItemStore._();
  ItemStore._() : super([]);

  bool _initialized = false;
  int _saveEventSerial = 0;
  final ValueNotifier<ItemSaveEvent?> _lastSaveEvent =
      ValueNotifier<ItemSaveEvent?>(null);

  ValueListenable<ItemSaveEvent?> get lastSaveEvent => _lastSaveEvent;

  /// Supabase에서 초기 제품 목록을 불러옵니다.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    value = await SupabaseService.loadItems();
    debugPrint('[ItemStore] 초기 로드 완료: ${value.length}개');
  }

  /// 새 제품 추가 — 로컬 즉시 반영 후 Supabase 동기화. 실패 시 롤백.
  ///
  /// ConsumableItem은 모든 필드가 final인 불변 객체이므로, 스냅샷을 얕은 복사(List.unmodifiable)로 저장해도 안전합니다.
  Future<void> add(
    ConsumableItem item, {
    ItemScope scope = const ItemScope.personal(),
  }) async {
    if (scope.isGroup) {
      await SupabaseService.saveItem(item, scope: scope);
      _notifySaved(scope);
      _triggerPersonalModelUpdate(item);
      return;
    }

    final previous = List<ConsumableItem>.unmodifiable(value);
    value = [...value, item];
    try {
      await SupabaseService.saveItem(item, scope: scope);
      _notifySaved(scope);
      _triggerPersonalModelUpdate(item);
    } catch (e) {
      value = List.of(previous);
      rethrow;
    }
  }

  /// 기존 제품 수정 — 로컬 즉시 반영 후 Supabase 동기화. 실패 시 롤백.
  Future<void> update(
    ConsumableItem updated, {
    ItemScope scope = const ItemScope.personal(),
  }) async {
    if (scope.isGroup) {
      await SupabaseService.saveItem(updated, scope: scope);
      _notifySaved(scope);
      _triggerPersonalModelUpdate(updated);
      return;
    }

    final previous = List<ConsumableItem>.unmodifiable(value);
    value = value
        .map((item) => item.id == updated.id ? updated : item)
        .toList();
    try {
      await SupabaseService.saveItem(updated, scope: scope);
      _notifySaved(scope);
      _triggerPersonalModelUpdate(updated);
    } catch (e) {
      value = List.of(previous);
      rethrow;
    }
  }

  /// 제품 삭제 — 로컬 즉시 반영 후 Supabase 동기화. 실패 시 롤백.
  Future<void> delete(String id) async {
    final previous = List<ConsumableItem>.unmodifiable(value);
    value = value.where((item) => item.id != id).toList();
    try {
      await SupabaseService.deleteItem(id);
    } catch (e) {
      value = List.of(previous);
      rethrow;
    }
  }

  /// id로 제품 조회 (없으면 null)
  ConsumableItem? findById(String id) {
    final matches = value.where((item) => item.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  ConsumableItem? findDuplicateByName(
    String name, {
    ItemScope scope = const ItemScope.personal(),
  }) {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    final matches = value.where((item) {
      final sameName = item.name.trim().toLowerCase() == normalized;
      if (!sameName) return false;
      if (scope.isPersonal) return item.groupId == null;
      return item.groupId == scope.id;
    });

    return matches.isEmpty ? null : matches.first;
  }

  void _notifySaved(ItemScope scope) {
    _saveEventSerial += 1;
    _lastSaveEvent.value = ItemSaveEvent(
      scope: scope,
      serial: _saveEventSerial,
    );
  }

  /// 구매 이력 15회 이상이면 개인화 β 계수를 비동기로 업데이트한다.
  void _triggerPersonalModelUpdate(ConsumableItem item) {
    if (item.purchaseHistory.length < kPhase4Threshold) return;
    final group =
        ConsumableCycleCoefficients.categoryToGroup[item.category] ?? 'average';
    final dailyUsage =
        DailyUsageService.instance.getInternalValue(item.category) ??
        (ConsumableCycleCoefficients.baseUsageRef[group] ?? 1.0);
    final purchaseDates = item.purchaseHistory.map((p) => p.date).toList();
    PersonalRegressionService.instance
        .updateIfNeeded(
          group: group,
          purchaseDates: purchaseDates,
          dailyUsage: dailyUsage,
        )
        .then((updated) {
          if (updated) {
            debugPrint('[ItemStore] Phase4 β 업데이트 완료: ${item.category}');
          }
        }, onError: (e) => debugPrint('[ItemStore] Phase4 β 업데이트 실패: $e'));
  }
}
