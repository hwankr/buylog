import 'package:buylog/models/item_scope.dart';
import 'package:buylog/screens/scan_screen.dart';
import 'package:buylog/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the target group while scanning for a group', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: ScanScreen(
            targetScope: ItemScope.group(id: 'group-1', label: '우리 가족'),
          ),
        ),
      ),
    );

    expect(find.text('우리 가족에 스캔 추가'), findsOneWidget);
  });
}
