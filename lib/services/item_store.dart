import 'package:flutter/foundation.dart';
import '../models/item.dart';
import 'supabase_service.dart';

/// 제품 상태 저장소
///
/// [ValueNotifier]를 상속하여 [ValueListenableBuilder]로 UI가 자동 갱신됩니다.
/// add / update / delete는 로컬 상태를 즉시 반영한 뒤 Supabase에 동기화합니다.
/// Supabase가 실패하면 이전 상태로 롤백하고 예외를 호출자에게 rethrow 합니다.
class ItemStore extends ValueNotifier<List<ConsumableItem>> {
  static final ItemStore instance = ItemStore._();
  ItemStore._() : super([]);

  bool _initialized = false;

  /// Supabase에서 초기 제품 목록을 불러옵니다.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    value = await SupabaseService.loadItems();
    debugPrint('[ItemStore] 초기 로드 완료: ${value.length}개');
  }

  /// 새 제품 추가 — 로컬 즉시 반영 후 Supabase 동기화. 실패 시 롤백.
  Future<void> add(ConsumableItem item) async {
    final previous = List<ConsumableItem>.unmodifiable(value);
    value = [...value, item];
    try {
      await SupabaseService.saveItem(item);
    } catch (e) {
      value = List.of(previous);
      rethrow;
    }
  }

  /// 기존 제품 수정 — 로컬 즉시 반영 후 Supabase 동기화. 실패 시 롤백.
  Future<void> update(ConsumableItem updated) async {
    final previous = List<ConsumableItem>.unmodifiable(value);
    value = value
        .map((item) => item.id == updated.id ? updated : item)
        .toList();
    try {
      await SupabaseService.saveItem(updated);
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
}
