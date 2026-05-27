import 'package:buylog/models/item_scope.dart';
import 'package:buylog/screens/add_item_screen.dart';
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
    ItemStore.instance.value = [];
  });

  tearDown(() {
    SupabaseService.debugItemDatabaseGateway = null;
  });

  testWidgets('manual group registration saves with selected group id', (
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

    await tester.enterText(find.byType(TextFormField).at(0), '세제');
    await tester.enterText(find.byType(TextFormField).at(1), '브랜드');
    await tester.enterText(find.byType(TextFormField).at(2), '30');
    await tester.enterText(find.byType(TextFormField).at(3), '8900');
    await tester.enterText(find.byType(TextFormField).at(4), '마트');

    await tester.tap(find.text('등록 완료'));
    await tester.pumpAndSettle();

    expect(gateway.upsertedItemPayload?['group_id'], 'group-1');
    expect(gateway.upsertedItemPayload?['user_id'], isNull);
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
}

class _RecordingItemDatabaseGateway implements ItemDatabaseGateway {
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
    upsertedItemPayload = Map<String, dynamic>.from(payload);
  }

  @override
  Future<void> insertPurchase(Map<String, dynamic> payload) async {}
}
