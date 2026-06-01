import 'package:buylog/models/item_scope.dart';
import 'package:buylog/theme/app_theme.dart';
import 'package:buylog/widgets/reports/report_scope_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders personal and group report scopes', (tester) async {
    ItemScope? selected;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ReportScopeTabs(
            scopes: const <ItemScope>[
              ItemScope.personal(),
              ItemScope.group(id: 'group-1', label: '우리 가족'),
              ItemScope.group(id: 'group-2', label: '사무실'),
            ],
            selectedScope: const ItemScope.personal(),
            onSelected: (scope) => selected = scope,
          ),
        ),
      ),
    );

    expect(find.text('내 물품'), findsOneWidget);
    expect(find.text('우리 가족'), findsOneWidget);
    expect(find.text('사무실'), findsOneWidget);

    await tester.tap(find.text('우리 가족'));

    expect(selected, const ItemScope.group(id: 'group-1', label: '우리 가족'));
  });

  testWidgets('marks the selected group scope as active', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ReportScopeTabs(
            scopes: const <ItemScope>[
              ItemScope.personal(),
              ItemScope.group(id: 'group-1', label: '우리 가족'),
            ],
            selectedScope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
            onSelected: (_) {},
          ),
        ),
      ),
    );

    final personalChip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, '내 물품'),
    );
    final groupChip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, '우리 가족'),
    );

    expect(personalChip.selected, isFalse);
    expect(groupChip.selected, isTrue);
  });
}
