import 'package:buylog/models/item.dart';
import 'package:buylog/screens/items_screen.dart';
import 'package:buylog/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('group item row shows the registrant label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ItemRow(
            item: _item(
              groupId: 'group-1',
              registeredByDisplayName: 'Minseo',
              registeredByEmail: 'minseo@example.com',
            ),
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.textContaining('추가: Minseo'), findsOneWidget);
  });

  testWidgets('personal item row does not show registrant metadata', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ItemRow(
            item: _item(
              registeredByDisplayName: 'Minseo',
              registeredByEmail: 'minseo@example.com',
            ),
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.textContaining('추가:'), findsNothing);
  });

  testWidgets('item row shows current remaining quantity when available', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ItemRow(item: _item(remainingQuantity: 3), onTap: () {}),
        ),
      ),
    );

    expect(find.textContaining('현재 3개'), findsOneWidget);
  });
}

ConsumableItem _item({
  String? groupId,
  String? registeredByDisplayName,
  String? registeredByEmail,
  int? remainingQuantity,
}) {
  return ConsumableItem(
    id: 'item-1',
    name: 'filter',
    brand: 'Coway',
    category: 'filter',
    icon: Icons.filter_alt_outlined,
    daysRemaining: 20,
    cycleDays: 30,
    progress: 0.3,
    groupId: groupId,
    registeredBy: 'user-1',
    registeredByDisplayName: registeredByDisplayName,
    registeredByEmail: registeredByEmail,
    remainingQuantity: remainingQuantity,
  );
}
