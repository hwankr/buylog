import 'package:flutter/foundation.dart';
import '../models/item.dart';
import '../data/sample_data.dart';

/// 인메모리 제품 상태 저장소
///
/// [ValueNotifier]를 상속하여 [ValueListenableBuilder]로 UI가 자동 갱신됩니다.
/// Firebase 연동 시 이 클래스를 Firestore 스트림 구독으로 교체합니다.
class ItemStore extends ValueNotifier<List<ConsumableItem>> {
  static final ItemStore instance = ItemStore._();
  ItemStore._() : super(List.of(SampleData.items));

  /// 새 제품 추가
  void add(ConsumableItem item) {
    value = [...value, item];
  }

  /// 기존 제품 수정 (id 기준으로 교체)
  void update(ConsumableItem updated) {
    value = value
        .map((item) => item.id == updated.id ? updated : item)
        .toList();
  }

  /// 제품 삭제
  void delete(String id) {
    value = value.where((item) => item.id != id).toList();
  }

  /// id로 제품 조회 (없으면 null)
  ConsumableItem? findById(String id) {
    final matches = value.where((item) => item.id == id);
    return matches.isEmpty ? null : matches.first;
  }
}
