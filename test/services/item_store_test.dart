import 'package:flutter_test/flutter_test.dart';
import 'package:buylog/models/item.dart';
import 'package:buylog/services/item_store.dart';

ConsumableItem _seed(String id, {String name = 'X', int days = 10}) =>
    ConsumableItem(
      id: id,
      name: name,
      brand: 'B',
      category: '기타',
      icon: ConsumableItem.iconForCategory('기타'),
      daysRemaining: days,
      cycleDays: 30,
      progress: 0.5,
    );

void main() {
  group('ItemStore rollback', () {
    test('add: Supabase 실패 시 이전 리스트 상태로 복원되고 rethrow', () async {
      ItemStore.instance.value = [_seed('a')];
      final before = List.of(ItemStore.instance.value);

      // SupabaseService 미초기화 → saveItem 내부에서 throw
      await expectLater(
        ItemStore.instance.add(_seed('b')),
        throwsA(isA<Object>()),
      );

      expect(
        ItemStore.instance.value.map((e) => e.id).toList(),
        before.map((e) => e.id).toList(),
        reason: '실패 후 리스트가 원상복구되어야 한다',
      );
    });

    test('delete: Supabase 실패 시 삭제된 아이템이 복원된다', () async {
      ItemStore.instance.value = [_seed('a'), _seed('b')];

      await expectLater(
        ItemStore.instance.delete('a'),
        throwsA(isA<Object>()),
      );

      expect(
        ItemStore.instance.value.map((e) => e.id).toSet(),
        {'a', 'b'},
        reason: '실패 후 삭제된 항목이 복원되어야 한다',
      );
    });

    test('update: Supabase 실패 시 이전 항목 값이 유지된다', () async {
      final original = _seed('a', name: 'old');
      ItemStore.instance.value = [original];

      await expectLater(
        ItemStore.instance.update(_seed('a', name: 'new')),
        throwsA(isA<Object>()),
      );

      expect(ItemStore.instance.value.single.name, 'old');
    });
  });
}
