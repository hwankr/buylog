import 'package:buylog/models/group.dart';
import 'package:buylog/models/item.dart';
import 'package:buylog/models/item_scope.dart';
import 'package:buylog/models/manual_quantity_snapshot.dart';
import 'package:buylog/screens/add_item_screen.dart';
import 'package:buylog/services/group_store.dart';
import 'package:buylog/services/item_store.dart';
import 'package:buylog/services/supabase_service.dart';
import 'package:buylog/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _RecordingItemDatabaseGateway gateway;

  setUp(() {
    gateway = _RecordingItemDatabaseGateway();
    SupabaseService.debugItemDatabaseGateway = gateway;
    GroupStore.instance.resetForTesting();
    ItemStore.instance.value = [];
  });

  tearDown(() {
    SupabaseService.debugItemDatabaseGateway = null;
    GroupStore.instance.resetForTesting();
    ItemStore.instance.value = [];
  });

  testWidgets('personal target scope is selected by default', (tester) async {
    _seedGroups();

    await tester.pumpWidget(_wrap(const AddItemScreen()));

    expect(_scopeChip('personal'), findsOneWidget);
    expect(tester.widget<ChoiceChip>(_scopeChip('personal')).selected, isTrue);
    expect(
      tester.widget<ChoiceChip>(_scopeChip('group:group-1')).selected,
      isFalse,
    );
  });

  testWidgets('group target scope is selected by default', (tester) async {
    _seedGroups();

    await tester.pumpWidget(
      _wrap(
        const AddItemScreen(
          targetScope: ItemScope.group(id: 'group-1', label: 'Family'),
        ),
      ),
    );

    expect(tester.widget<ChoiceChip>(_scopeChip('personal')).selected, isFalse);
    expect(
      tester.widget<ChoiceChip>(_scopeChip('group:group-1')).selected,
      isTrue,
    );
  });

  testWidgets('switching from personal to group saves with group id', (
    tester,
  ) async {
    _seedGroups();

    await tester.pumpWidget(_wrap(const AddItemScreen()));
    await tester.tap(_scopeChip('group:group-1'));
    await tester.pump();
    await _submitMinimalItem(tester);

    expect(gateway.upsertedItemPayload?['user_id'], isNull);
    expect(gateway.upsertedItemPayload?['group_id'], 'group-1');
  });

  testWidgets('switching from group to personal saves as personal item', (
    tester,
  ) async {
    _seedGroups();

    await tester.pumpWidget(
      _wrap(
        const AddItemScreen(
          targetScope: ItemScope.group(id: 'group-1', label: 'Family'),
        ),
      ),
    );
    await tester.tap(_scopeChip('personal'));
    await tester.pump();
    await _submitMinimalItem(tester);

    expect(
      gateway.upsertedItemPayload?['user_id'],
      SupabaseService.currentUserId,
    );
    expect(gateway.upsertedItemPayload?['group_id'], isNull);
  });

  testWidgets('edit mode hides scope toggle and preserves item group scope', (
    tester,
  ) async {
    _seedGroups();

    await tester.pumpWidget(
      _wrap(
        AddItemScreen(
          editItem: ConsumableItem(
            id: 'item-1',
            name: 'filter',
            brand: 'Coway',
            category: 'Kitchen',
            icon: Icons.kitchen_outlined,
            daysRemaining: 10,
            cycleDays: 30,
            progress: 0.2,
            groupId: 'group-1',
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('add_item_scope_toggle')), findsNothing);
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    expect(gateway.upsertedItemPayload?['user_id'], isNull);
    expect(gateway.upsertedItemPayload?['group_id'], 'group-1');
  });

  testWidgets('shows the target group while adding a group item', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const AddItemScreen(
          targetScope: ItemScope.group(id: 'group-1', label: '우리 가족'),
        ),
      ),
    );

    expect(find.text('우리 가족에 추가 중'), findsOneWidget);
  });

  testWidgets('vision tracking is off by default when adding an item', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const AddItemScreen()));

    expect(
      tester
          .widget<Switch>(find.byKey(const ValueKey('vision_tracking_switch')))
          .value,
      isFalse,
    );

    await _submitMinimalItem(tester);

    expect(gateway.upsertedItemPayload?['vision_tracking_enabled'], isFalse);
    expect(
      gateway.upsertedItemPayload?['vision_measure_interval_minutes'],
      360,
    );
  });

  testWidgets('vision tracking interval can be selected before saving', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const AddItemScreen()));

    await tester.ensureVisible(
      find.byKey(const ValueKey('vision_tracking_switch')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('vision_tracking_switch')));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('vision_interval_720')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('vision_interval_720')));
    await tester.pump();
    await _submitMinimalItem(tester);

    expect(gateway.upsertedItemPayload?['vision_tracking_enabled'], isTrue);
    expect(
      gateway.upsertedItemPayload?['vision_measure_interval_minutes'],
      720,
    );
  });

  testWidgets('purchase quantity defaults to one when adding an item', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const AddItemScreen()));

    expect(find.byKey(const ValueKey('purchase_quantity_0')), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('purchase_quantity_0')),
          )
          .controller
          ?.text,
      '1',
    );

    await _submitMinimalItem(tester);

    expect(gateway.insertedPurchasePayloads.single['quantity'], 1);
    expect(gateway.manualQuantityRemainingQuantity, 1);
  });

  testWidgets('entered purchase quantity is saved and initializes inventory', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const AddItemScreen()));

    await tester.ensureVisible(find.byKey(const ValueKey('purchase_quantity_0')));
    await tester.enterText(find.byKey(const ValueKey('purchase_quantity_0')), '10');
    await _submitMinimalItem(tester);

    expect(gateway.insertedPurchasePayloads.single['quantity'], 10);
    expect(gateway.manualQuantityRemainingQuantity, 10);
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(theme: AppTheme.lightTheme, home: child);
}

Finder _scopeChip(String storageKey) {
  return find.byKey(ValueKey('add_item_scope_$storageKey'));
}

void _seedGroups() {
  GroupStore.instance.value = GroupState(
    groups: <BuylogGroup>[
      BuylogGroup(
        id: 'group-1',
        name: 'Family',
        inviteCode: 'BUY-ABC123',
        createdBy: SupabaseService.currentUserId,
        createdAt: DateTime.parse('2026-05-26T00:00:00.000Z'),
      ),
    ],
    selectedScope: const ItemScope.group(id: 'group-1', label: 'Family'),
  );
}

Future<void> _submitMinimalItem(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'filter');
  await tester.enterText(find.byType(TextFormField).at(1), 'Coway');
  await tester.enterText(find.byType(TextFormField).at(2), '30');
  await tester.enterText(find.byType(TextFormField).at(3), '8900');
  await tester.enterText(find.byType(TextFormField).at(5), 'Market');
  await tester.tap(find.byType(FilledButton).last);
  await tester.pumpAndSettle();
}

class _RecordingItemDatabaseGateway implements ItemDatabaseGateway {
  Map<String, dynamic>? upsertedItemPayload;
  final List<Map<String, dynamic>> insertedPurchasePayloads = [];
  String? manualQuantityProductItemId;
  int? manualQuantityRemainingQuantity;

  @override
  Future<List<Map<String, dynamic>>> loadItems({
    required String? userId,
    required String? groupId,
  }) async {
    return const <Map<String, dynamic>>[];
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
    upsertedItemPayload = Map<String, dynamic>.from(payload);
  }

  @override
  Future<void> insertPurchase(Map<String, dynamic> payload) async {
    insertedPurchasePayloads.add(Map<String, dynamic>.from(payload));
  }

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
    manualQuantityProductItemId = productItemId;
    manualQuantityRemainingQuantity = remainingQuantity;
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
