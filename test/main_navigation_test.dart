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

      await tester.tap(find.text('그룹').last);
      await tester.pump();
      await tester.tap(find.byTooltip('제품 추가'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('직접 등록'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '정수기 필터');
      await tester.tap(find.text('등록 완료'));
      await tester.pumpAndSettle();

      expect(gateway.ensureCategoryUserId, isNull);
      expect(gateway.ensureCategoryGroupId, 'group-1');
      expect(gateway.upsertPayload?['group_id'], 'group-1');
      expect(gateway.upsertPayload?['user_id'], isNull);
    },
  );
}

BuylogGroup _group() {
  return BuylogGroup(
    id: 'group-1',
    name: '우리 가족',
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
