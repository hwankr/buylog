import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:buylog/main.dart';

void main() {
  // 테스트 환경 바인딩 초기화
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // 리눅스 환경에 없는 shared_preferences 플러그인을 가짜로 만듭니다.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getAll') {
              return <String, dynamic>{}; // 빈 저장소를 반환합니다.
            }
            return null;
          },
        );

    try {
      await Supabase.initialize(
        url: 'https://mock.supabase.co',
        anonKey: 'mock-anon-key',
        authOptions: const FlutterAuthClientOptions(
          localStorage: EmptyLocalStorage(),
        ),
      );
    } catch (_) {}
  });

  testWidgets('App should render', (WidgetTester tester) async {
    // 앱을 렌더링합니다.
    await tester.pumpWidget(const BuylogApp());

    // 하단 탭의 '모든 제품' 라벨로 새 디자인 셸이 렌더링되었는지 확인합니다.
    expect(find.text('모든 제품'), findsOneWidget);
  });
}
