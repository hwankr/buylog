import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:buylog/main.dart';

void main() {
  // 테스트 환경에서 플러그인(Shared Preferences 등) 에러를 방지하기 위한 설정
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    try {
      // 억지로 실제 초기화를 시도하지 않고, 테스트용 인스턴스만 생성되게끔 유도
      await Supabase.initialize(
        url: 'https://mock.supabase.co',
        anonKey: 'mock-anon-key',
        debug: false, // 불필요한 로그 방지
      );
    } catch (_) {
    }
  });

  testWidgets('App should render', (WidgetTester tester) async {
    // 앱을 렌더링합니다.
    await tester.pumpWidget(const BuylogApp());
    
    // 화면에 '내 아이템'이 있는지 확인 (실제 데이터가 없어도 위젯 구조상 존재하면 통과)
    expect(find.text('내 아이템'), findsOneWidget);
  });
}