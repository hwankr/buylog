import 'package:flutter_test/flutter_test.dart';
import 'package:buylog/models/item.dart';
import 'package:buylog/models/item_scope.dart';
import 'package:buylog/models/manual_quantity_snapshot.dart';
import 'package:buylog/services/item_store.dart';
import 'package:buylog/services/supabase_service.dart';

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
    setUp(() {
      ItemStore.instance.value = [];
    });

    test('add: Supabase 실패 시 이전 리스트 상태로 복원되고 rethrow', () async {
      ItemStore.instance.value = [_seed('a')];
      final before = List.of(ItemStore.instance.value);

      // SupabaseService 미초기화 → saveItem 내부에서 throw
      await expectLater(ItemStore.instance.add(_seed('b')), throwsA(anything));

      expect(
        ItemStore.instance.value.map((e) => e.id).toList(),
        before.map((e) => e.id).toList(),
        reason: '실패 후 리스트가 원상복구되어야 한다',
      );
    });

    test('delete: Supabase 실패 시 삭제된 아이템이 복원된다', () async {
      ItemStore.instance.value = [_seed('a'), _seed('b')];

      await expectLater(ItemStore.instance.delete('a'), throwsA(anything));

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
        throwsA(anything),
      );

      expect(ItemStore.instance.value.single.name, 'old');
    });

    test('add: group scope saves without appending to personal list', () async {
      final gateway = _RecordingItemDatabaseGateway();
      SupabaseService.debugItemDatabaseGateway = gateway;
      addTearDown(() => SupabaseService.debugItemDatabaseGateway = null);

      ItemStore.instance.value = [_seed('personal')];

      await ItemStore.instance.add(
        _seed('group-item'),
        scope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
      );

      expect(ItemStore.instance.value.map((item) => item.id), ['personal']);
      expect(gateway.upsertedItemPayload?['group_id'], 'group-1');
      expect(gateway.upsertedItemPayload?['user_id'], isNull);
    });

    test('findDuplicateByName only matches items in the requested scope', () {
      ItemStore.instance.value = [
        _seed('personal', name: '세제'),
        ConsumableItem(
          id: 'group-item',
          name: '세제',
          brand: 'B',
          category: '기타',
          icon: ConsumableItem.iconForCategory('기타'),
          daysRemaining: 10,
          cycleDays: 30,
          progress: 0.5,
          groupId: 'group-1',
        ),
      ];

      final personal = ItemStore.instance.findDuplicateByName(
        ' 세제 ',
        scope: const ItemScope.personal(),
      );
      final group = ItemStore.instance.findDuplicateByName(
        '세제',
        scope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
      );
      final otherGroup = ItemStore.instance.findDuplicateByName(
        '세제',
        scope: const ItemScope.group(id: 'group-2', label: '사무실'),
      );

      expect(personal?.id, 'personal');
      expect(group?.id, 'group-item');
      expect(otherGroup, isNull);
    });
  });
}

class _RecordingItemDatabaseGateway implements ItemDatabaseGateway {
  Object? saveError;
  Map<String, dynamic>? upsertedItemPayload;

  @override
  Future<List<Map<String, dynamic>>> loadItems({
    required String? userId,
    required String? groupId,
  }) async {
    return const [];
  }

  @override
  Future<String> ensureCategory({
    required String name,
    required String? userId,
    required String? groupId,
  }) async {
    return 'category-1';
  }

  @override
  Future<void> upsertItem(Map<String, dynamic> payload) async {
    if (saveError != null) throw saveError!;
    upsertedItemPayload = Map<String, dynamic>.from(payload);
  }

  @override
  Future<void> insertPurchase(Map<String, dynamic> payload) async {}

  @override
  Future<void> updatePurchase({
    required String purchaseId,
    required Map<String, dynamic> payload,
  }) async {}

  @override
  Future<ManualQuantitySnapshot> setManualQuantity({
    required String productItemId,
    required int remainingQuantity,
    required DateTime observedAt,
  }) async {
    return ManualQuantitySnapshot(
      remainingQuantity: remainingQuantity,
      confidence: 1,
      sourceName: 'manual',
      observedAt: observedAt,
    );
  }

  @override
  Future<ManualQuantitySnapshot> recordManualUsage({
    required String productItemId,
    required int usedQuantity,
    required DateTime usedAt,
  }) async {
    return ManualQuantitySnapshot(
      remainingQuantity: 0,
      confidence: 1,
      sourceName: 'manual',
      observedAt: usedAt,
    );
  }
}
