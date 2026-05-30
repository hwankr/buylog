import 'package:buylog/models/group.dart';
import 'package:buylog/models/item.dart';
import 'package:buylog/models/item_scope.dart';
import 'package:buylog/models/manual_quantity_snapshot.dart';
import 'package:buylog/screens/reports_screen.dart';
import 'package:buylog/services/group_store.dart';
import 'package:buylog/services/item_store.dart';
import 'package:buylog/services/supabase_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ValueNotifier<GroupState> groupState;
  late ValueNotifier<List<ConsumableItem>> personalItems;
  late ValueNotifier<ItemSaveEvent?> saveEvents;
  late _RecordingItemDatabaseGateway gateway;

  setUp(() {
    groupState = ValueNotifier<GroupState>(
      GroupState(
        groups: <BuylogGroup>[
          _group(id: 'group-1', name: '우리 가족'),
          _group(id: 'group-2', name: '사무실'),
        ],
      ),
    );
    personalItems = ValueNotifier<List<ConsumableItem>>(<ConsumableItem>[
      _item(id: 'personal-filter', name: '개인 필터', price: 30000),
    ]);
    saveEvents = ValueNotifier<ItemSaveEvent?>(null);
    gateway = _RecordingItemDatabaseGateway();
    SupabaseService.debugItemDatabaseGateway = gateway;
  });

  tearDown(() {
    SupabaseService.debugItemDatabaseGateway = null;
    groupState.dispose();
    personalItems.dispose();
    saveEvents.dispose();
  });

  testWidgets('renders personal and joined group report scope tabs', (
    tester,
  ) async {
    await _pump(
      tester,
      groupState: groupState,
      personalItems: personalItems,
      saveEvents: saveEvents,
    );

    expect(find.text('내 물품'), findsOneWidget);
    expect(find.text('우리 가족'), findsOneWidget);
    expect(find.text('사무실'), findsOneWidget);
    expect(find.text('리포트'), findsOneWidget);
  });

  testWidgets(
    'defaults to personal items and switches report totals after group tap',
    (tester) async {
      gateway.resultsByGroupId['group-1'] = <Map<String, dynamic>>[
        _itemRow(id: 'group-filter', groupId: 'group-1', price: 12000),
      ];

      await _pump(
        tester,
        groupState: groupState,
        personalItems: personalItems,
        saveEvents: saveEvents,
      );

      expect(find.textContaining('30,000'), findsWidgets);

      await tester.tap(find.text('우리 가족'));
      await tester.pump();
      await tester.pump();

      expect(gateway.lastGroupId, 'group-1');
      expect(find.textContaining('12,000'), findsWidgets);
    },
  );

  testWidgets('falls back to personal scope when selected group disappears', (
    tester,
  ) async {
    gateway.resultsByGroupId['group-1'] = <Map<String, dynamic>>[
      _itemRow(id: 'group-filter', groupId: 'group-1', price: 12000),
    ];

    await _pump(
      tester,
      groupState: groupState,
      personalItems: personalItems,
      saveEvents: saveEvents,
    );

    await tester.tap(find.text('우리 가족'));
    await tester.pump();
    await tester.pump();

    groupState.value = const GroupState(groups: <BuylogGroup>[]);
    await tester.pump();

    final personalChip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, '내 물품'),
    );
    expect(personalChip.selected, isTrue);
    expect(find.text('우리 가족'), findsNothing);
  });

  testWidgets('updates selected group label when group is renamed', (
    tester,
  ) async {
    gateway.resultsByGroupId['group-1'] = <Map<String, dynamic>>[
      _itemRow(id: 'group-filter', groupId: 'group-1', price: 12000),
    ];

    await _pump(
      tester,
      groupState: groupState,
      personalItems: personalItems,
      saveEvents: saveEvents,
    );

    await tester.tap(find.text('우리 가족'));
    await tester.pump();
    await tester.pump();

    groupState.value = GroupState(
      groups: <BuylogGroup>[
        _group(id: 'group-1', name: '새 가족'),
        _group(id: 'group-2', name: '사무실'),
      ],
    );
    await tester.pump();

    expect(find.text('새 가족'), findsOneWidget);
    final groupChip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, '새 가족'),
    );
    expect(groupChip.selected, isTrue);
  });

  testWidgets('reloads selected group report after matching save event', (
    tester,
  ) async {
    gateway.resultsByGroupId['group-1'] = <Map<String, dynamic>>[
      _itemRow(id: 'group-filter', groupId: 'group-1', price: 12000),
    ];

    await _pump(
      tester,
      groupState: groupState,
      personalItems: personalItems,
      saveEvents: saveEvents,
    );

    await tester.tap(find.text('우리 가족'));
    await tester.pump();
    await tester.pump();
    expect(gateway.loadItemsCalls, 1);

    saveEvents.value = const ItemSaveEvent(
      scope: ItemScope.group(id: 'group-1', label: '우리 가족'),
      serial: 1,
    );
    await tester.pump();
    await tester.pump();

    expect(gateway.loadItemsCalls, 2);
  });

  testWidgets('shows Korean error message when group report load fails', (
    tester,
  ) async {
    gateway.error = StateError('network failed');

    await _pump(
      tester,
      groupState: groupState,
      personalItems: personalItems,
      saveEvents: saveEvents,
    );

    await tester.tap(find.text('우리 가족'));
    await tester.pump();
    await tester.pump();

    expect(find.text('리포트 데이터를 불러오지 못했습니다.'), findsOneWidget);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required ValueListenable<GroupState> groupState,
  required ValueListenable<List<ConsumableItem>> personalItems,
  required ValueListenable<ItemSaveEvent?> saveEvents,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 3200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ReportsScreen(
          groupListenable: groupState,
          personalItemsListenable: personalItems,
          saveEventListenable: saveEvents,
        ),
      ),
    ),
  );
}

ConsumableItem _item({
  required String id,
  required String name,
  required int price,
  String? groupId,
}) {
  return ConsumableItem(
    id: id,
    name: name,
    brand: '브랜드',
    category: '가전/필터',
    icon: Icons.circle,
    daysRemaining: 10,
    cycleDays: 30,
    progress: 0.5,
    groupId: groupId,
    purchaseHistory: <PurchaseRecord>[
      PurchaseRecord(
        date: DateTime(DateTime.now().year, DateTime.now().month, 10),
        price: price,
        store: '마트',
      ),
    ],
  );
}

Map<String, dynamic> _itemRow({
  required String id,
  required String groupId,
  required int price,
}) {
  final now = DateTime.now();
  final month = now.month.toString().padLeft(2, '0');
  return <String, dynamic>{
    'id': id,
    'user_id': null,
    'group_id': groupId,
    'registered_by': SupabaseService.currentUserId,
    'name': '그룹 필터',
    'brand': '브랜드',
    'image_url': null,
    'replacement_cycle_days': 30,
    'created_at': '2026-05-26T00:00:00.000Z',
    'categories': <String, dynamic>{'id': 'category-1', 'name': '가전/필터'},
    'purchases': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'purchase-$id',
        'purchase_date': '${now.year}-$month-10',
        'price': price,
        'store_name': '마트',
      },
    ],
    'ai_predictions': <Map<String, dynamic>>[],
  };
}

BuylogGroup _group({required String id, required String name}) {
  return BuylogGroup(
    id: id,
    name: name,
    inviteCode: 'BUY-${id.toUpperCase()}',
    createdBy: SupabaseService.currentUserId,
    createdAt: DateTime.parse('2026-05-26T00:00:00.000Z'),
  );
}

class _RecordingItemDatabaseGateway implements ItemDatabaseGateway {
  Object? error;
  int loadItemsCalls = 0;
  String? lastGroupId;
  final Map<String, List<Map<String, dynamic>>> resultsByGroupId =
      <String, List<Map<String, dynamic>>>{};

  @override
  Future<List<Map<String, dynamic>>> loadItems({
    required String? userId,
    required String? groupId,
  }) async {
    loadItemsCalls += 1;
    lastGroupId = groupId;
    if (error != null) throw error!;
    return resultsByGroupId[groupId] ?? const <Map<String, dynamic>>[];
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
