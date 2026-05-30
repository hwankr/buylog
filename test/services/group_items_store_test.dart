import 'dart:async';

import 'package:buylog/services/group_items_store.dart';
import 'package:buylog/services/group_dashboard_summary.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buylog/models/item_scope.dart';
import 'package:buylog/models/manual_quantity_snapshot.dart';
import 'package:buylog/services/supabase_service.dart';

void main() {
  late _RecordingItemDatabaseGateway gateway;
  late GroupItemsStore store;

  setUp(() {
    gateway = _RecordingItemDatabaseGateway();
    SupabaseService.debugItemDatabaseGateway = gateway;
    store = GroupItemsStore();
  });

  tearDown(() {
    SupabaseService.debugItemDatabaseGateway = null;
    store.dispose();
  });

  test('loads personal items for personal scope', () async {
    gateway.loadItemsResult = <Map<String, dynamic>>[
      _itemRow(id: 'personal-1', userId: SupabaseService.currentUserId),
    ];

    await store.load(const ItemScope.personal());

    expect(store.value.scope, const ItemScope.personal());
    expect(store.value.items.single.id, 'personal-1');
    expect(store.value.isLoading, isFalse);
    expect(store.value.errorMessage, isNull);
  });

  test('loads group items for group scope', () async {
    gateway.loadItemsResult = <Map<String, dynamic>>[
      _itemRow(id: 'group-item-1', groupId: 'group-1'),
    ];

    await store.load(const ItemScope.group(id: 'group-1', label: '우리 가족'));

    expect(store.value.scope.label, '우리 가족');
    expect(store.value.items.single.groupId, 'group-1');
  });

  test('sets Korean error message when scoped load throws', () async {
    gateway.error = StateError('network failed');

    await store.load(const ItemScope.personal());

    expect(store.value.items, isEmpty);
    expect(store.value.isLoading, isFalse);
    expect(store.value.errorMessage, '물품 목록을 불러오지 못했습니다.');
  });

  test('ignores stale results when a newer scope finishes first', () async {
    final first = Completer<List<Map<String, dynamic>>>();
    final second = Completer<List<Map<String, dynamic>>>();
    gateway.pendingResults
      ..add(first)
      ..add(second);

    final personalLoad = store.load(const ItemScope.personal());
    await Future<void>.delayed(Duration.zero);
    final groupLoad = store.load(
      const ItemScope.group(id: 'group-1', label: '우리 가족'),
    );
    await Future<void>.delayed(Duration.zero);

    second.complete(<Map<String, dynamic>>[
      _itemRow(id: 'group-item-1', groupId: 'group-1'),
    ]);
    await groupLoad;

    first.complete(<Map<String, dynamic>>[
      _itemRow(id: 'personal-1', userId: SupabaseService.currentUserId),
    ]);
    await personalLoad;

    expect(store.value.scope.label, '우리 가족');
    expect(store.value.items.single.id, 'group-item-1');
  });

  test(
    'does not start a duplicate load while the same scope is loading',
    () async {
      final pending = Completer<List<Map<String, dynamic>>>();
      gateway.pendingResults.add(pending);

      final firstLoad = store.load(const ItemScope.personal());
      await Future<void>.delayed(Duration.zero);
      await store.load(const ItemScope.personal());

      expect(gateway.loadItemsCalls, 1);

      pending.complete(<Map<String, dynamic>>[
        _itemRow(id: 'personal-1', userId: SupabaseService.currentUserId),
      ]);
      await firstLoad;
    },
  );

  test('selectFilter updates filter without reloading items', () async {
    gateway.loadItemsResult = <Map<String, dynamic>>[
      _itemRow(id: 'item-1', groupId: 'group-1'),
    ];

    await store.load(const ItemScope.group(id: 'group-1', label: '우리 가족'));
    store.selectFilter(GroupItemFilter.urgent);

    expect(store.value.selectedFilter, GroupItemFilter.urgent);
    expect(store.value.items.single.id, 'item-1');
    expect(gateway.loadItemsCalls, 1);
  });
}

Map<String, dynamic> _itemRow({
  required String id,
  String? userId,
  String? groupId,
}) {
  return <String, dynamic>{
    'id': id,
    'user_id': userId,
    'group_id': groupId,
    'registered_by': userId ?? SupabaseService.currentUserId,
    'name': '세제',
    'brand': '브랜드',
    'image_url': null,
    'replacement_cycle_days': 30,
    'created_at': '2026-05-26T00:00:00.000Z',
    'categories': <String, dynamic>{'id': 'category-1', 'name': '주방/세제'},
    'purchases': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'purchase-1',
        'purchase_date': '2026-05-20',
        'price': 8900,
        'store_name': '마트',
      },
    ],
    'ai_predictions': <Map<String, dynamic>>[],
  };
}

class _RecordingItemDatabaseGateway implements ItemDatabaseGateway {
  Object? error;
  int loadItemsCalls = 0;
  List<Map<String, dynamic>> loadItemsResult = const [];
  final List<Completer<List<Map<String, dynamic>>>> pendingResults = [];

  @override
  Future<List<Map<String, dynamic>>> loadItems({
    required String? userId,
    required String? groupId,
  }) async {
    loadItemsCalls += 1;
    if (error != null) {
      throw error!;
    }
    if (pendingResults.isNotEmpty) {
      return pendingResults.removeAt(0).future;
    }
    return loadItemsResult;
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
  Future<void> upsertItem(Map<String, dynamic> payload) async {}

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
