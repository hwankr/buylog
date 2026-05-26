import 'package:buylog/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SettingsScreen shows a neutralized profile card', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SettingsScreen())),
    );

    expect(find.text('사용자'), findsOneWidget);
    expect(find.text('사'), findsOneWidget);
    expect(find.text('계정 정보 없음'), findsOneWidget);

    expect(find.text('지민'), findsNothing);
    expect(find.text('김지민'), findsNothing);
    expect(find.text('김민수'), findsNothing);
    expect(find.text('minsu@email.com'), findsNothing);
  });
}
