import 'package:buylog/models/item_scope.dart';
import 'package:buylog/theme/app_theme.dart';
import 'package:buylog/widgets/group/item_scope_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders joined group tabs and reports group selection', (
    tester,
  ) async {
    ItemScope? selected;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ItemScopeTabs(
            scopes: const <ItemScope>[
              ItemScope.group(id: 'group-1', label: '우리 가족'),
              ItemScope.group(id: 'group-2', label: '사무실'),
            ],
            selectedScope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
            onSelected: (scope) => selected = scope,
          ),
        ),
      ),
    );

    expect(find.text('내 물품'), findsNothing);
    expect(find.text('우리 가족'), findsOneWidget);
    expect(find.text('사무실'), findsOneWidget);

    await tester.tap(find.text('사무실'));
    expect(selected, const ItemScope.group(id: 'group-2', label: '사무실'));
  });
}
