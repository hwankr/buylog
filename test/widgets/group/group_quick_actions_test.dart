import 'package:buylog/theme/app_theme.dart';
import 'package:buylog/widgets/group/group_quick_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders group page quick actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: GroupQuickActions(
            onAddItem: () {},
            onScanReceipt: () {},
            onCreateGroup: () {},
          ),
        ),
      ),
    );

    expect(find.text('물품 추가'), findsOneWidget);
    expect(find.text('영수증 스캔'), findsOneWidget);
    expect(find.text('그룹 추가'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsWidgets);
    expect(find.byIcon(Icons.document_scanner_outlined), findsOneWidget);
    expect(find.byIcon(Icons.group_add_outlined), findsOneWidget);
  });

  testWidgets('invokes each quick action callback', (tester) async {
    var addItemCalls = 0;
    var scanCalls = 0;
    var createGroupCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: GroupQuickActions(
            onAddItem: () => addItemCalls += 1,
            onScanReceipt: () => scanCalls += 1,
            onCreateGroup: () => createGroupCalls += 1,
          ),
        ),
      ),
    );

    await tester.tap(find.text('물품 추가'));
    await tester.tap(find.text('영수증 스캔'));
    await tester.tap(find.text('그룹 추가'));

    expect(addItemCalls, 1);
    expect(scanCalls, 1);
    expect(createGroupCalls, 1);
  });

  testWidgets('disables group creation while the store is saving', (
    tester,
  ) async {
    var createGroupCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: GroupQuickActions(
            onAddItem: () {},
            onScanReceipt: () {},
            onCreateGroup: () => createGroupCalls += 1,
            isCreateGroupDisabled: true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('그룹 추가'));

    expect(createGroupCalls, 0);
  });
}
