import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:buylog/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    try {
      await Supabase.initialize(
        url: 'https://mock.supabase.co',
        anonKey: 'mock-anon-key',
        authOptions: const FlutterAuthClientOptions(
          localStorage: EmptyLocalStorage(),
        ),
      );
    } catch (_) {
      // 400 에러 무시
    }
  });

  testWidgets('App should render', (WidgetTester tester) async {
    await tester.pumpWidget(const BuylogApp());
    expect(find.text('내 아이템'), findsOneWidget);
  });
}
