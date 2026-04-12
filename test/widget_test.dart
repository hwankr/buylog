import 'package:flutter_test/flutter_test.dart';
import 'package:buylog/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    await Supabase.initialize(
      url: 'https://mock.supabase.co',
      anonKey: 'mock-anon-key',
    );
  });

  testWidgets('App should render', (WidgetTester tester) async {
    await tester.pumpWidget(const BuylogApp());
    expect(find.text('내 아이템'), findsOneWidget);
  });
}
