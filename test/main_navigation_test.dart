import 'package:buylog/main.dart';
import 'package:buylog/models/group.dart';
import 'package:buylog/models/item_scope.dart';
import 'package:buylog/services/group_store.dart';
import 'package:buylog/services/item_store.dart';
import 'package:buylog/services/supabase_service.dart';
import 'package:buylog/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    GroupStore.instance.resetForTesting();
    ItemStore.instance.value = [];
    SupabaseService.debugItemDatabaseGateway = _RecordingItemDatabaseGateway();
  });

  tearDown(() {
    GroupStore.instance.resetForTesting();
    ItemStore.instance.value = [];
    SupabaseService.debugItemDatabaseGateway = null;
  });

  testWidgets(
    'group tab add action targets the first group when selected scope is personal',
    (tester) async {
      final gateway = _RecordingItemDatabaseGateway();
      SupabaseService.debugItemDatabaseGateway = gateway;
      GroupStore.instance.value = GroupState(
        groups: <BuylogGroup>[_group()],
        selectedScope: const ItemScope.personal(),
      );

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const MainNavigation()),
      );

      await tester.tap(find.byIcon(Icons.group_outlined));
      await tester.pump();
      await _addManualItem(tester, expectedSelectedScopeKey: 'group:group-1');

      expect(gateway.ensureCategoryUserId, isNull);
      expect(gateway.ensureCategoryGroupId, 'group-1');
      expect(gateway.upsertPayload?['group_id'], 'group-1');
      expect(gateway.upsertPayload?['user_id'], isNull);
      expect(
        gateway.upsertPayload?['registered_by'],
        SupabaseService.currentUserId,
      );
    },
  );

  testWidgets('home tab add action still targets personal items', (
    tester,
  ) async {
    final gateway = _RecordingItemDatabaseGateway();
    SupabaseService.debugItemDatabaseGateway = gateway;
    GroupStore.instance.value = GroupState(
      groups: <BuylogGroup>[_group()],
      selectedScope: const ItemScope.group(id: 'group-1', label: 'Family'),
    );

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const MainNavigation()),
    );

    await _addManualItem(tester, expectedSelectedScopeKey: 'personal');

    expect(gateway.ensureCategoryUserId, SupabaseService.currentUserId);
    expect(gateway.ensureCategoryGroupId, isNull);
    expect(gateway.upsertPayload?['user_id'], SupabaseService.currentUserId);
    expect(gateway.upsertPayload?['group_id'], isNull);
    expect(
      gateway.upsertPayload?['registered_by'],
      SupabaseService.currentUserId,
    );
  });
}

Future<void> _addManualItem(
  WidgetTester tester, {
  required String expectedSelectedScopeKey,
}) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.edit_outlined));
  await tester.pumpAndSettle();

  final chip = tester.widget<ChoiceChip>(
    find.byKey(ValueKey('add_item_scope_$expectedSelectedScopeKey')),
  );
  expect(chip.selected, isTrue);

  await tester.enterText(find.byType(TextFormField).first, 'filter');
  await tester.tap(find.byType(FilledButton).last);
  await tester.pumpAndSettle();
}

BuylogGroup _group() {
  return BuylogGroup(
    id: 'group-1',
    name: 'Family',
    inviteCode: 'BUY-ABC123',
    createdBy: SupabaseService.currentUserId,
    createdAt: DateTime.parse('2026-05-26T00:00:00.000Z'),
    members: <BuylogGroupMember>[],
  );
}

class _RecordingItemDatabaseGateway implements ItemDatabaseGateway {
  String? ensureCategoryUserId;
  String? ensureCategoryGroupId;
  Map<String, dynamic>? upsertPayload;

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
    ensureCategoryUserId = userId;
    ensureCategoryGroupId = groupId;
    return 'category-1';
  }

  @override
  Future<void> upsertItem(Map<String, dynamic> payload) async {
    upsertPayload = Map<String, dynamic>.from(payload);
  }

  @override
  Future<void> insertPurchase(Map<String, dynamic> payload) async {}
}
