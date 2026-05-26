import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:buylog/services/group_store.dart';
import 'package:buylog/services/supabase_service.dart';
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

    await Supabase.initialize(
      url: 'https://mock.supabase.co',
      anonKey: 'mock-anon-key',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
      ),
    );
  });

  tearDown(() {
    GroupStore.instance.resetForTesting();
    SupabaseService.debugGroupDatabaseGateway = null;
  });

  testWidgets(
    'preloadGroupForStartup keeps app renderable when group preload fails',
    (WidgetTester tester) async {
      SupabaseService.debugGroupDatabaseGateway =
          _ThrowingGroupDatabaseGateway();

      await preloadGroupForStartup();

      expect(GroupStore.instance.value.errorMessage, '그룹 정보를 불러오지 못했습니다.');
      await tester.pumpWidget(const BuylogApp());
      await tester.pump();
      expect(find.byType(MainNavigation), findsOneWidget);
    },
  );

  testWidgets('App should render', (WidgetTester tester) async {
    // 앱을 렌더링합니다.
    await tester.pumpWidget(const BuylogApp());

    // 하단 탭의 '모든 제품' 라벨로 새 디자인 셸이 렌더링되었는지 확인합니다.
    expect(find.text('모든 제품'), findsOneWidget);
  });
}

class _ThrowingGroupDatabaseGateway implements GroupDatabaseGateway {
  @override
  Future<Map<String, dynamic>?> loadDefaultGroup(String userId) async {
    throw StateError('group preload failed');
  }

  @override
  Future<Map<String, dynamic>> createGroupWithOwner({
    required String name,
    required String inviteCode,
  }) {
    throw UnsupportedError('createGroupWithOwner is not used in this test');
  }

  @override
  Future<List<Map<String, dynamic>>> loadGroupMembers({
    required String groupId,
  }) {
    throw UnsupportedError('loadGroupMembers is not used in this test');
  }
}
