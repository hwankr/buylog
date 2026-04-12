import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:buylog/main.dart';
import 'dart:io';

void main() {
  // 테스트 환경에서 외부 네트워크 요청 차단으로 인한 에러를 방지합니다.
  setUpAll(() async {
    // 테스트용 바인딩 초기화 (네트워크 관련 설정을 위해 필요할 수 있음)
    TestWidgetsFlutterBinding.ensureInitialized();

    try {
      await Supabase.initialize(
        url: 'https://mock.supabase.co',
        anonKey: 'mock-anon-key',
        // 네트워크 연결을 실제로 시도하지 않도록 내부 옵션을 조절할 수도 있지만,
        // 가장 확실한 방법은 초기화 시 발생하는 HTTP 400 에러를 캐치하는 것입니다.
      );
    } catch (e) {
      // 테스트 환경에서 400 에러(네트워크 차단)가 나더라도 
      // 인스턴스 자체는 생성되므로 무시하고 진행합니다.
      print('Supabase mock init warning: $e');
    }
  });

  testWidgets('App should render', (WidgetTester tester) async {
    await tester.pumpWidget(const BuylogApp());
    expect(find.text('내 아이템'), findsOneWidget);
  });
}