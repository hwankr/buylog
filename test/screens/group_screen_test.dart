import 'package:buylog/models/group.dart';
import 'package:buylog/models/item.dart';
import 'package:buylog/models/item_scope.dart';
import 'package:buylog/screens/add_item_screen.dart';
import 'package:buylog/screens/group_screen.dart';
import 'package:buylog/screens/scan_screen.dart';
import 'package:buylog/services/group_store.dart';
import 'package:buylog/services/item_store.dart';
import 'package:buylog/services/supabase_service.dart';
import 'package:buylog/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    GroupStore.instance.resetForTesting();
    SupabaseService.debugGroupDatabaseGateway = null;
    SupabaseService.debugItemDatabaseGateway = null;
    ItemStore.instance.value = [];
  });

  tearDown(() {
    GroupStore.instance.resetForTesting();
    SupabaseService.debugGroupDatabaseGateway = null;
    SupabaseService.debugItemDatabaseGateway = null;
    ItemStore.instance.value = [];
  });

  testWidgets('empty state renders group title and create CTA', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap());

    expect(find.text('그룹'), findsOneWidget);
    expect(find.text('아직 연결된 그룹이 없습니다.'), findsOneWidget);
    expect(find.text('그룹 만들기'), findsOneWidget);
  });

  testWidgets('blank group name shows validation message', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap());

    await tester.tap(find.text('그룹 만들기'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('만들기'));
    await tester.pump();

    expect(find.text('그룹 이름을 입력해 주세요.'), findsOneWidget);
  });

  testWidgets('valid group creation uses fake gateway and renders group card', (
    WidgetTester tester,
  ) async {
    final gateway = _FakeGroupDatabaseGateway();
    SupabaseService.debugGroupDatabaseGateway = gateway;

    await tester.pumpWidget(_wrap());

    await tester.tap(find.text('그룹 만들기'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '우리 가족');
    await tester.tap(find.text('만들기'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(gateway.createGroupWithOwnerCalls, 1);
    expect(gateway.loadDefaultGroupCalls, 0);
    expect(gateway.createdGroupValues?['name'], '우리 가족');
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('우리 가족'), findsAtLeastNWidgets(1));
    expect(
      find.text('초대 코드: ${gateway.createdGroupValues?['invite_code']}'),
      findsOneWidget,
    );
    expect(find.text('사용자'), findsOneWidget);
  });

  testWidgets('creation failure keeps dialog open and shows error message', (
    WidgetTester tester,
  ) async {
    final gateway = _FakeGroupDatabaseGateway()
      ..createGroupWithOwnerError = StateError('create failed');
    SupabaseService.debugGroupDatabaseGateway = gateway;

    await tester.pumpWidget(_wrap());

    await tester.tap(find.text('그룹 만들기'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '우리 가족');
    await tester.tap(find.text('만들기'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(GroupStore.instance.value.errorMessage, isNotNull);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(GroupStore.instance.value.errorMessage!),
      ),
      findsOneWidget,
    );
  });

  testWidgets('saved group state renders group summary and member names', (
    WidgetTester tester,
  ) async {
    GroupStore.instance.value = GroupState(
      group: _group(),
      selectedScope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
    );

    await tester.pumpWidget(_wrap());

    expect(find.text('우리 가족'), findsAtLeastNWidgets(1));
    expect(find.text('초대 코드: BUY-ABC123'), findsOneWidget);
    expect(find.text('멤버 2명'), findsOneWidget);
    expect(find.text('소유자'), findsOneWidget);
    expect(find.text('멤버'), findsNWidgets(2));
    expect(find.text('관리자'), findsOneWidget);
  });

  testWidgets('renders scope tabs and switches selected group tab', (
    WidgetTester tester,
  ) async {
    GroupStore.instance.value = GroupState(
      groups: <BuylogGroup>[
        _group(id: 'group-1', name: '우리 가족'),
        _group(id: 'group-2', name: '사무실'),
      ],
    );

    await tester.pumpWidget(_wrap());

    expect(find.text('내 물품'), findsNothing);
    expect(find.text('우리 가족'), findsAtLeastNWidgets(1));
    expect(find.text('사무실'), findsOneWidget);

    await tester.tap(find.text('사무실'));
    await tester.pump();

    expect(
      GroupStore.instance.value.selectedScope,
      const ItemScope.group(id: 'group-2', label: '사무실'),
    );
  });

  testWidgets('group page renders group tabs only and loads the first group', (
    WidgetTester tester,
  ) async {
    final itemGateway = _RecordingItemDatabaseGateway()
      ..loadItemsResult = <Map<String, dynamic>>[
        _itemRow(id: 'group-item-1', groupId: 'group-1'),
      ];
    SupabaseService.debugItemDatabaseGateway = itemGateway;
    GroupStore.instance.value = GroupState(
      groups: <BuylogGroup>[
        _group(id: 'group-1', name: '우리 가족'),
        _group(id: 'group-2', name: '사무실'),
      ],
      selectedScope: const ItemScope.personal(),
    );

    await tester.pumpWidget(_wrap());
    await tester.pump();

    expect(find.text('내 물품'), findsNothing);
    expect(find.text('우리 가족'), findsAtLeastNWidgets(1));
    expect(find.text('사무실'), findsOneWidget);
    expect(itemGateway.lastUserId, isNull);
    expect(itemGateway.lastGroupId, 'group-1');
    expect(
      GroupStore.instance.value.selectedScope,
      const ItemScope.group(id: 'group-1', label: '우리 가족'),
    );
  });

  testWidgets('empty group page does not render a personal item list', (
    WidgetTester tester,
  ) async {
    SupabaseService.debugItemDatabaseGateway = _RecordingItemDatabaseGateway();
    GroupStore.instance.value = const GroupState();

    await tester.pumpWidget(_wrap());
    await tester.pump();

    expect(find.text('내 물품'), findsNothing);
    expect(find.text('내 물품 목록'), findsNothing);
    expect(find.text('그룹에 제품 추가'), findsNothing);
    expect(find.text('그룹 만들기'), findsOneWidget);
  });

  testWidgets('member refresh button reloads and renders latest members', (
    WidgetTester tester,
  ) async {
    final gateway = _FakeGroupDatabaseGateway()
      ..loadGroupMembersResult = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'member-2',
          'user_id': 'user-2',
          'role': 'member',
          'joined_at': '2026-05-26T00:01:00.000Z',
          'users': <String, dynamic>{
            'display_name': '새 멤버',
            'email': 'new@example.com',
          },
        },
      ];
    SupabaseService.debugGroupDatabaseGateway = gateway;
    GroupStore.instance.value = GroupState(
      group: _group(),
      selectedScope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
    );

    await tester.pumpWidget(_wrap());
    await tester.tap(find.byTooltip('멤버 새로고침'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(gateway.loadGroupMembersCalls, 1);
    expect(find.text('새 멤버'), findsOneWidget);
    expect(find.text('멤버 1명'), findsOneWidget);
  });

  testWidgets('member can confirm leaving a group', (tester) async {
    final gateway = _FakeGroupDatabaseGateway();
    SupabaseService.debugGroupDatabaseGateway = gateway;
    GroupStore.instance.value = GroupState(
      groups: <BuylogGroup>[
        _group().copyWith(
          members: [
            BuylogGroupMember(
              id: 'member-current',
              userId: SupabaseService.currentUserId,
              displayName: '나',
              role: GroupRole.member,
              joinedAt: DateTime.parse('2026-05-26T00:00:00.000Z'),
            ),
          ],
        ),
      ],
      selectedScope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
    );

    await tester.pumpWidget(_wrap());
    await tester.tap(find.text('그룹 탈퇴'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('탈퇴')),
    );
    await tester.pumpAndSettle();

    expect(gateway.leaveGroupCalls, 1);
    expect(gateway.leaveGroupGroupId, 'group-1');
    expect(gateway.leaveGroupNewOwnerUserId, isNull);
  });

  testWidgets('owner selects a new owner before leaving', (tester) async {
    final gateway = _FakeGroupDatabaseGateway();
    SupabaseService.debugGroupDatabaseGateway = gateway;
    GroupStore.instance.value = GroupState(
      groups: <BuylogGroup>[_group()],
      selectedScope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
    );

    await tester.pumpWidget(_wrap());
    await tester.tap(find.text('그룹 탈퇴'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('멤버').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('위임 후 탈퇴'),
      ),
    );
    await tester.pumpAndSettle();

    expect(gateway.leaveGroupCalls, 1);
    expect(gateway.leaveGroupNewOwnerUserId, 'user-2');
  });

  testWidgets('single owner can leave without another member', (tester) async {
    final gateway = _FakeGroupDatabaseGateway();
    SupabaseService.debugGroupDatabaseGateway = gateway;
    GroupStore.instance.value = GroupState(
      groups: <BuylogGroup>[_singleOwnerGroup()],
      selectedScope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
    );

    await tester.pumpWidget(_wrap());
    await tester.tap(find.text('그룹 탈퇴'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('탈퇴')),
    );
    await tester.pumpAndSettle();

    expect(gateway.leaveGroupCalls, 1);
    expect(gateway.leaveGroupGroupId, 'group-1');
    expect(gateway.leaveGroupNewOwnerUserId, isNull);
  });

  testWidgets('reloads selected group items after a scoped save event', (
    WidgetTester tester,
  ) async {
    final itemGateway = _RecordingItemDatabaseGateway()
      ..loadItemsResult = <Map<String, dynamic>>[
        _itemRow(id: 'group-item-1', groupId: 'group-1'),
      ];
    SupabaseService.debugItemDatabaseGateway = itemGateway;

    GroupStore.instance.value = GroupState(
      groups: <BuylogGroup>[_group(id: 'group-1', name: '우리 가족')],
      selectedScope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
    );

    await tester.pumpWidget(_wrap());
    await tester.pump();

    await ItemStore.instance.add(
      _seedItem('new-group-item'),
      scope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
    );
    await tester.pump();

    expect(itemGateway.loadItemsCalls, greaterThanOrEqualTo(2));
  });

  testWidgets('renders dashboard counts for selected group items', (
    WidgetTester tester,
  ) async {
    final itemGateway = _RecordingItemDatabaseGateway()
      ..loadItemsResult = <Map<String, dynamic>>[
        _itemRow(id: 'urgent', groupId: 'group-1', daysAgo: 29),
        _itemRow(id: 'fresh', groupId: 'group-1', daysAgo: 1),
      ];
    SupabaseService.debugItemDatabaseGateway = itemGateway;
    GroupStore.instance.value = GroupState(
      groups: <BuylogGroup>[_group()],
      selectedScope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
    );

    await tester.pumpWidget(_wrap());
    await tester.pump();

    expect(find.text('전체'), findsOneWidget);
    expect(find.text('긴급'), findsOneWidget);
    expect(find.text('곧'), findsOneWidget);
    expect(find.text('여유'), findsOneWidget);
    expect(find.text('전체 2'), findsOneWidget);
    expect(find.text('긴급 1'), findsOneWidget);
  });

  testWidgets('copies group invite code from group card', (tester) async {
    String? copiedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<dynamic, dynamic>;
            copiedText = args['text'] as String?;
          }
          return null;
        });
    GroupStore.instance.value = GroupState(
      groups: <BuylogGroup>[_group()],
      selectedScope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
    );

    await tester.pumpWidget(_wrap());
    await tester.tap(find.byTooltip('초대 코드 복사'));
    await tester.pumpAndSettle();

    expect(copiedText, 'BUY-ABC123');
    expect(find.text('초대 코드가 복사되었습니다.'), findsOneWidget);
  });

  testWidgets('filter chip narrows visible group items without reloading', (
    tester,
  ) async {
    final itemGateway = _RecordingItemDatabaseGateway()
      ..loadItemsResult = <Map<String, dynamic>>[
        _itemRow(id: 'urgent', groupId: 'group-1', daysAgo: 29),
        _itemRow(id: 'soon', groupId: 'group-1', daysAgo: 1),
      ];
    SupabaseService.debugItemDatabaseGateway = itemGateway;
    GroupStore.instance.value = GroupState(
      groups: <BuylogGroup>[_group()],
      selectedScope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
    );

    await tester.pumpWidget(_wrap());
    await tester.pump();
    await tester.ensureVisible(find.text('긴급 1'));
    await tester.pump();
    await tester.tap(find.text('긴급 1'));
    await tester.pump();

    expect(find.text('urgent'), findsOneWidget);
    expect(find.text('soon'), findsNothing);
    expect(itemGateway.loadItemsCalls, 1);
  });

  testWidgets('existing group page exposes in-page add actions', (
    tester,
  ) async {
    GroupStore.instance.value = GroupState(
      groups: <BuylogGroup>[_group()],
      selectedScope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
    );

    await tester.pumpWidget(_wrap());
    await tester.pump();

    expect(find.text('물품 추가'), findsOneWidget);
    expect(find.text('영수증 스캔'), findsOneWidget);
    expect(find.text('그룹 추가'), findsOneWidget);
  });

  testWidgets('manual group page add saves with the selected group id', (
    tester,
  ) async {
    final itemGateway = _RecordingItemDatabaseGateway();
    SupabaseService.debugItemDatabaseGateway = itemGateway;
    GroupStore.instance.value = GroupState(
      groups: <BuylogGroup>[_group()],
      selectedScope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
    );

    await tester.pumpWidget(_wrap());
    await tester.pump();
    await tester.tap(find.text('물품 추가'));
    await tester.pumpAndSettle();

    expect(find.byType(AddItemScreen), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), '세제');
    await tester.enterText(find.byType(TextFormField).at(1), '브랜드');
    await tester.enterText(find.byType(TextFormField).at(2), '30');
    await tester.enterText(find.byType(TextFormField).at(3), '8900');
    await tester.enterText(find.byType(TextFormField).at(4), '마트');
    await tester.tap(find.text('등록 완료'));
    await tester.pumpAndSettle();

    expect(itemGateway.upsertedItemPayload?['group_id'], 'group-1');
    expect(itemGateway.upsertedItemPayload?['user_id'], isNull);
  });

  testWidgets('scan group page action opens ScanScreen', (tester) async {
    GroupStore.instance.value = GroupState(
      groups: <BuylogGroup>[_group()],
      selectedScope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
    );

    await tester.pumpWidget(_wrap());
    await tester.pump();
    await tester.tap(find.text('영수증 스캔'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ScanScreen), findsOneWidget);
  });

  testWidgets('group add action creates another group from non-empty state', (
    tester,
  ) async {
    final gateway = _FakeGroupDatabaseGateway()..nextCreatedGroupId = 'group-2';
    SupabaseService.debugGroupDatabaseGateway = gateway;
    GroupStore.instance.value = GroupState(
      groups: <BuylogGroup>[_group(id: 'group-1', name: '우리 가족')],
      selectedScope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
    );

    await tester.pumpWidget(_wrap());
    await tester.pump();
    await tester.tap(find.text('그룹 추가'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '사무실');
    await tester.tap(find.text('만들기'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(gateway.createGroupWithOwnerCalls, 1);
    expect(gateway.createdGroupValues?['name'], '사무실');
    expect(GroupStore.instance.value.groups.map((group) => group.name), [
      '우리 가족',
      '사무실',
    ]);
    expect(
      GroupStore.instance.value.selectedScope,
      const ItemScope.group(id: 'group-2', label: '사무실'),
    );
  });

  testWidgets('empty group item list shows add CTA', (tester) async {
    SupabaseService.debugItemDatabaseGateway = _RecordingItemDatabaseGateway();
    GroupStore.instance.value = GroupState(
      groups: <BuylogGroup>[_group()],
      selectedScope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
    );

    await tester.pumpWidget(_wrap());
    await tester.pump();

    expect(find.text('아직 이 그룹에 등록된 물품이 없습니다.'), findsOneWidget);
    expect(find.text('그룹에 제품 추가'), findsOneWidget);
  });
}

Widget _wrap() {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: const Scaffold(body: GroupScreen()),
  );
}

BuylogGroup _group({String id = 'group-1', String name = '우리 가족'}) {
  return BuylogGroup(
    id: id,
    name: name,
    inviteCode: 'BUY-ABC123',
    createdBy: 'user-1',
    createdAt: DateTime.parse('2026-05-26T00:00:00.000Z'),
    members: [
      BuylogGroupMember(
        id: 'member-1',
        userId: SupabaseService.currentUserId,
        displayName: '소유자',
        role: GroupRole.owner,
        joinedAt: DateTime.parse('2026-05-26T00:00:00.000Z'),
      ),
      BuylogGroupMember(
        id: 'member-2',
        userId: 'user-2',
        displayName: '멤버',
        role: GroupRole.member,
        joinedAt: DateTime.parse('2026-05-26T00:01:00.000Z'),
      ),
    ],
  );
}

BuylogGroup _singleOwnerGroup() {
  return BuylogGroup(
    id: 'group-1',
    name: '우리 가족',
    inviteCode: 'BUY-ABC123',
    createdBy: SupabaseService.currentUserId,
    createdAt: DateTime.parse('2026-05-26T00:00:00.000Z'),
    members: [
      BuylogGroupMember(
        id: 'member-1',
        userId: SupabaseService.currentUserId,
        displayName: '소유자',
        role: GroupRole.owner,
        joinedAt: DateTime.parse('2026-05-26T00:00:00.000Z'),
      ),
    ],
  );
}

class _FakeGroupDatabaseGateway implements GroupDatabaseGateway {
  int loadDefaultGroupCalls = 0;
  int createGroupWithOwnerCalls = 0;
  int loadGroupMembersCalls = 0;
  int leaveGroupCalls = 0;
  Map<String, dynamic>? createdGroupValues;
  Object? createGroupWithOwnerError;
  List<Map<String, dynamic>> loadGroupMembersResult = const [];
  String? leaveGroupGroupId;
  String? leaveGroupNewOwnerUserId;
  Map<String, dynamic>? _currentGroup;
  String nextCreatedGroupId = 'group-1';

  @override
  Future<Map<String, dynamic>?> loadDefaultGroup(String userId) async {
    loadDefaultGroupCalls += 1;
    return _currentGroup == null
        ? null
        : Map<String, dynamic>.from(_currentGroup!);
  }

  @override
  Future<List<Map<String, dynamic>>> loadGroupsForUser(String userId) async {
    return _currentGroup == null
        ? const <Map<String, dynamic>>[]
        : <Map<String, dynamic>>[Map<String, dynamic>.from(_currentGroup!)];
  }

  @override
  Future<Map<String, dynamic>> createGroupWithOwner({
    required String name,
    required String inviteCode,
  }) async {
    createGroupWithOwnerCalls += 1;
    if (createGroupWithOwnerError != null) {
      throw createGroupWithOwnerError!;
    }

    createdGroupValues = <String, dynamic>{
      'name': name,
      'invite_code': inviteCode,
    };
    final group = _groupRow(
      id: nextCreatedGroupId,
      name: name,
      inviteCode: inviteCode,
    );
    _currentGroup = group;
    return group;
  }

  @override
  Future<List<Map<String, dynamic>>> loadGroupMembers({
    required String groupId,
  }) async {
    loadGroupMembersCalls += 1;
    return loadGroupMembersResult;
  }

  @override
  Future<void> leaveGroup({
    required String groupId,
    required String? newOwnerUserId,
  }) async {
    leaveGroupCalls += 1;
    leaveGroupGroupId = groupId;
    leaveGroupNewOwnerUserId = newOwnerUserId;
    _currentGroup = null;
  }

  Future<void> insertGroupMember(Map<String, dynamic> values) async {}

  Future<void> updateDefaultGroup({
    required String userId,
    required String groupId,
  }) async {}
}

Map<String, dynamic> _groupRow({
  String id = 'group-1',
  required String name,
  String inviteCode = 'BUY-ABC123',
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'invite_code': inviteCode,
    'created_by': SupabaseService.currentUserId,
    'created_at': '2026-05-26T00:00:00.000Z',
    'group_members': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'member-1',
        'user_id': SupabaseService.currentUserId,
        'role': 'owner',
        'joined_at': '2026-05-26T00:00:00.000Z',
        'users': <String, dynamic>{
          'display_name': '사용자',
          'email': 'user@example.com',
        },
      },
    ],
  };
}

ConsumableItem _seedItem(String id) {
  return ConsumableItem(
    id: id,
    name: '세제',
    brand: '브랜드',
    category: '주방/세제',
    icon: ConsumableItem.iconForCategory('주방/세제'),
    daysRemaining: 30,
    cycleDays: 30,
    progress: 0,
  );
}

Map<String, dynamic> _itemRow({
  required String id,
  String? groupId,
  int daysAgo = 0,
}) {
  final purchaseDate = DateTime.now()
      .subtract(Duration(days: daysAgo))
      .toIso8601String()
      .substring(0, 10);

  return <String, dynamic>{
    'id': id,
    'user_id': null,
    'group_id': groupId,
    'registered_by': SupabaseService.currentUserId,
    'name': id,
    'brand': '브랜드',
    'image_url': null,
    'replacement_cycle_days': 30,
    'created_at': '2026-05-27T00:00:00.000Z',
    'categories': <String, dynamic>{'id': 'category-1', 'name': '주방/세제'},
    'purchases': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'purchase-$id',
        'purchase_date': purchaseDate,
        'price': 1000,
        'store_name': '마트',
      },
    ],
    'ai_predictions': <Map<String, dynamic>>[],
  };
}

class _RecordingItemDatabaseGateway implements ItemDatabaseGateway {
  int loadItemsCalls = 0;
  String? lastUserId;
  String? lastGroupId;
  List<Map<String, dynamic>> loadItemsResult = const [];
  Map<String, dynamic>? upsertedItemPayload;

  @override
  Future<List<Map<String, dynamic>>> loadItems({
    required String? userId,
    required String? groupId,
  }) async {
    loadItemsCalls += 1;
    lastUserId = userId;
    lastGroupId = groupId;
    return loadItemsResult;
  }

  @override
  Future<String> ensureCategory({
    required String name,
    required String? userId,
    required String? groupId,
  }) async {
    return 'category-1';
  }

  @override
  Future<void> upsertItem(Map<String, dynamic> payload) async {
    upsertedItemPayload = Map<String, dynamic>.from(payload);
  }

  @override
  Future<void> insertPurchase(Map<String, dynamic> payload) async {}
}
