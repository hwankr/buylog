import 'package:flutter/foundation.dart';
import '../models/item.dart';
import 'supabase_service.dart';

/// 제품 상태 저장소
///
/// [ValueNotifier]를 상속하여 [ValueListenableBuilder]로 UI가 자동 갱신됩니다.
/// add / update / delete는 로컬 상태를 즉시 반영한 뒤 Supabase에 비동기 동기화합니다.
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

  /// 새 제품 추가 — 로컬 즉시 반영 후 Supabase 동기화
  Future<void> add(ConsumableItem item) async {
    value = [...value, item];
    await SupabaseService.saveItem(item);
  }

  /// 기존 제품 수정 — 로컬 즉시 반영 후 Supabase 동기화
  Future<void> update(ConsumableItem updated) async {
    value = value
        .map((item) => item.id == updated.id ? updated : item)
        .toList();
    await SupabaseService.saveItem(updated);
  }

  /// 제품 삭제 — 로컬 즉시 반영 후 Supabase 동기화
  Future<void> delete(String id) async {
    value = value.where((item) => item.id != id).toList();
    await SupabaseService.deleteItem(id);
  }

  /// id로 제품 조회 (없으면 null)
  ConsumableItem? findById(String id) {
    final matches = value.where((item) => item.id == id);
    return matches.isEmpty ? null : matches.first;
  }
}
