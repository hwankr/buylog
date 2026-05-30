import 'package:buylog/models/group.dart';
import 'package:buylog/models/item_scope.dart';
import 'package:buylog/services/group_store.dart';
import 'package:buylog/services/supabase_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GroupRole database value', () {
    test('serializes owner and member roles', () {
      expect(GroupRole.owner.databaseValue, 'owner');
      expect(GroupRole.member.databaseValue, 'member');
    });

    test('round-trips known database values', () {
      expect(GroupRole.fromDatabase('owner').databaseValue, 'owner');
      expect(GroupRole.fromDatabase('member').databaseValue, 'member');
    });

    test('exposes Korean display labels for member role badges', () {
      expect(GroupRole.owner.displayLabel, '관리자');
      expect(GroupRole.member.displayLabel, '멤버');
    });
  });

  group('BuylogGroup Supabase parsing', () {
    test('parses group fields and nested members', () {
      final group = BuylogGroup.fromSupabase({
        'id': 'group-1',
        'name': '우리 가족',
        'invite_code': 'ABC123',
        'created_by': 'user-1',
        'created_at': '2026-05-26T10:20:30.000Z',
        'group_members': [
          {
            'id': 'member-1',
            'user_id': 'user-1',
            'role': 'owner',
            'joined_at': '2026-05-26T10:21:30.000Z',
            'users': {'display_name': '사용자', 'email': 'user@example.com'},
          },
        ],
      });

      expect(group.id, 'group-1');
      expect(group.name, '우리 가족');
      expect(group.inviteCode, 'ABC123');
      expect(group.createdBy, 'user-1');
      expect(group.createdAt, DateTime.parse('2026-05-26T10:20:30.000Z'));
      expect(group.members, hasLength(1));
      expect(group.members.first.id, 'member-1');
      expect(group.members.first.userId, 'user-1');
      expect(group.members.first.displayName, '사용자');
      expect(group.members.first.role, GroupRole.owner);
      expect(
        group.members.first.joinedAt,
        DateTime.parse('2026-05-26T10:21:30.000Z'),
      );
    });

    test('uses an empty unmodifiable member list when members are missing', () {
      final group = BuylogGroup.fromSupabase({
        'id': 'group-1',
        'name': '우리 가족',
        'invite_code': 'ABC123',
        'created_by': 'user-1',
        'created_at': '2026-05-26T10:20:30.000Z',
      });

      expect(group.members, isEmpty);
      expect(() => group.members.add(_member()), throwsUnsupportedError);
    });

    test('copyWith replaces members without mutating the original group', () {
      final original = BuylogGroup.fromSupabase({
        'id': 'group-1',
        'name': '우리 가족',
        'invite_code': 'ABC123',
        'created_by': 'user-1',
        'created_at': '2026-05-26T10:20:30.000Z',
        'group_members': [
          {
            'id': 'member-1',
            'user_id': 'user-1',
            'role': 'owner',
            'joined_at': '2026-05-26T10:21:30.000Z',
            'users': {'display_name': '소유자', 'email': 'owner@example.com'},
          },
        ],
      });
      final nextMember = BuylogGroupMember.fromSupabase({
        'id': 'member-2',
        'user_id': 'user-2',
        'role': 'member',
        'joined_at': '2026-05-26T10:22:30.000Z',
        'users': {'display_name': '멤버', 'email': 'member@example.com'},
      });

      final updated = original.copyWith(members: [nextMember]);

      expect(original.members.single.userId, 'user-1');
      expect(updated.members.single.userId, 'user-2');
      expect(() => updated.members.add(nextMember), throwsUnsupportedError);
    });
  });

  group('BuylogGroup membership helpers', () {
    test('finds the current user member and owner status', () {
      final group = _groupWithMembers();

      expect(group.memberForUser('owner-user')?.role, GroupRole.owner);
      expect(group.memberForUser('member-user')?.role, GroupRole.member);
      expect(group.memberForUser('missing-user'), isNull);
      expect(group.isOwner('owner-user'), isTrue);
      expect(group.isOwner('member-user'), isFalse);
    });

    test('returns delegation candidates excluding current user', () {
      final group = _groupWithMembers();

      final candidates = group.delegationCandidates('owner-user');

      expect(candidates.map((member) => member.userId), ['member-user']);
      expect(candidates.single.displayName, '멤버');
    });
  });

  group('BuylogGroupMember Supabase parsing', () {
    test('falls back to email when display name is missing', () {
      final member = BuylogGroupMember.fromSupabase({
        'id': 'member-1',
        'user_id': 'user-1',
        'role': 'member',
        'joined_at': '2026-05-26T10:21:30.000Z',
        'users': {'email': 'user@example.com'},
      });

      expect(member.displayName, 'user@example.com');
      expect(member.role, GroupRole.member);
    });

    test('falls back to 사용자 when display name and email are empty', () {
      final member = BuylogGroupMember.fromSupabase({
        'id': 'member-1',
        'user_id': 'user-1',
        'role': 'unknown',
        'joined_at': '2026-05-26T10:21:30.000Z',
        'users': {'display_name': '  ', 'email': ''},
      });

      expect(member.displayName, '사용자');
      expect(member.role, GroupRole.member);
    });
  });

  group('ItemScope', () {
    test('builds the personal scope label', () {
      const scope = ItemScope.personal();

      expect(scope.type, ItemScopeType.personal);
      expect(scope.id, isNull);
      expect(scope.label, '내 물품');
      expect(scope.storageKey, 'personal');
    });

    test('builds a group scope label and stable key', () {
      const scope = ItemScope.group(id: 'group-1', label: '우리 가족');

      expect(scope.type, ItemScopeType.group);
      expect(scope.id, 'group-1');
      expect(scope.label, '우리 가족');
      expect(scope.storageKey, 'group:group-1');
    });
  });

  group('GroupStore', () {
    late _RecordingGroupDatabaseGateway gateway;

    setUp(() {
      gateway = _RecordingGroupDatabaseGateway();
      SupabaseService.debugGroupDatabaseGateway = gateway;
      GroupStore.instance.resetForTesting();
    });

    tearDown(() {
      GroupStore.instance.resetForTesting();
      SupabaseService.debugGroupDatabaseGateway = null;
    });

    test('loads empty state when no default group exists', () async {
      await GroupStore.instance.initialize();

      expect(GroupStore.instance.value.group, isNull);
      expect(GroupStore.instance.value.isLoading, isFalse);
      expect(GroupStore.instance.value.isSaving, isFalse);
      expect(GroupStore.instance.value.errorMessage, isNull);
      expect(gateway.loadGroupsForUserCalls, 1);
    });

    test('sets Korean error state and rethrows when preload fails', () async {
      gateway.loadGroupsForUserError = StateError('load failed');

      await expectLater(
        GroupStore.instance.initialize(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'load failed',
          ),
        ),
      );

      expect(GroupStore.instance.value.group, isNull);
      expect(GroupStore.instance.value.isLoading, isFalse);
      expect(GroupStore.instance.value.isSaving, isFalse);
      expect(GroupStore.instance.value.errorMessage, '그룹 정보를 불러오지 못했습니다.');
      expect(gateway.loadGroupsForUserCalls, 1);
    });

    test('creates a group and exposes it through state', () async {
      gateway.loadDefaultGroupResult = _groupRow(name: 'My Group');

      await GroupStore.instance.createGroup('  My Group  ');

      expect(GroupStore.instance.value.group?.id, 'group-1');
      expect(GroupStore.instance.value.group?.name, 'My Group');
      expect(GroupStore.instance.value.isLoading, isFalse);
      expect(GroupStore.instance.value.isSaving, isFalse);
      expect(GroupStore.instance.value.errorMessage, isNull);
      expect(gateway.createdGroupValues?['name'], 'My Group');
      expect(gateway.loadDefaultGroupCalls, 0);
    });

    test(
      'createGroup appends a new group and selects it when groups already exist',
      () async {
        GroupStore.instance.value = GroupState(
          groups: <BuylogGroup>[_groupWithMembers()],
          selectedScope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
        );
        gateway.nextCreatedGroupId = 'group-2';

        await GroupStore.instance.createGroup('사무실');

        expect(GroupStore.instance.value.groups.map((group) => group.name), [
          '우리 가족',
          '사무실',
        ]);
        expect(
          GroupStore.instance.value.selectedScope,
          const ItemScope.group(id: 'group-2', label: '사무실'),
        );
        expect(
          GroupStore.instance.value.selectedGroupScope,
          const ItemScope.group(id: 'group-2', label: '사무실'),
        );
      },
    );

    test('builds personal and joined group scopes after initialize', () async {
      gateway.loadGroupsForUserResult = <Map<String, dynamic>>[
        _groupRow(id: 'group-1', name: '우리 가족'),
        _groupRow(id: 'group-2', name: '사무실'),
      ];

      await GroupStore.instance.initialize();

      final scopes = GroupStore.instance.value.availableScopes;
      expect(scopes.map((scope) => scope.label), ['내 물품', '우리 가족', '사무실']);
      expect(
        GroupStore.instance.value.selectedScope,
        const ItemScope.group(id: 'group-1', label: '우리 가족'),
      );
    });

    test('exposes joined groups as group-only scopes', () async {
      gateway.loadGroupsForUserResult = <Map<String, dynamic>>[
        _groupRow(id: 'group-1', name: '우리 가족'),
        _groupRow(id: 'group-2', name: '사무실'),
      ];

      await GroupStore.instance.initialize();

      final groupScopes = GroupStore.instance.value.groupScopes;
      expect(groupScopes.map((scope) => scope.label), ['우리 가족', '사무실']);
      expect(groupScopes.every((scope) => scope.isGroup), isTrue);
      expect(groupScopes.any((scope) => scope.label == '내 물품'), isFalse);
    });

    test(
      'initialize selects the first joined group for the group page',
      () async {
        gateway.loadGroupsForUserResult = <Map<String, dynamic>>[
          _groupRow(id: 'group-1', name: '우리 가족'),
          _groupRow(id: 'group-2', name: '사무실'),
        ];

        await GroupStore.instance.initialize();

        expect(
          GroupStore.instance.value.selectedScope,
          const ItemScope.group(id: 'group-1', label: '우리 가족'),
        );
        expect(
          GroupStore.instance.value.selectedGroupScope,
          const ItemScope.group(id: 'group-1', label: '우리 가족'),
        );
      },
    );

    test(
      'selectedGroupScope falls back to the first group when selected scope is personal',
      () {
        GroupStore.instance.value = GroupState(
          groups: <BuylogGroup>[
            _groupWithMembers(),
            BuylogGroup(
              id: 'group-2',
              name: '사무실',
              inviteCode: 'BUY-OFFICE',
              createdBy: 'owner-user',
              createdAt: DateTime.parse('2026-05-27T00:00:00.000Z'),
            ),
          ],
          selectedScope: const ItemScope.personal(),
        );

        expect(
          GroupStore.instance.value.selectedGroupScope,
          const ItemScope.group(id: 'group-1', label: '우리 가족'),
        );
      },
    );

    test('selectScope switches to a joined group scope', () async {
      gateway.loadGroupsForUserResult = <Map<String, dynamic>>[
        _groupRow(id: 'group-1', name: '우리 가족'),
      ];
      await GroupStore.instance.initialize();

      GroupStore.instance.selectScope(
        const ItemScope.group(id: 'group-1', label: '우리 가족'),
      );

      expect(GroupStore.instance.value.selectedScope.label, '우리 가족');
    });

    test('exposes group-only scopes without the personal scope', () async {
      gateway.loadGroupsForUserResult = <Map<String, dynamic>>[
        _groupRow(id: 'group-1', name: '우리 가족'),
        _groupRow(id: 'group-2', name: '사무실'),
      ];

      await GroupStore.instance.initialize();

      final scopes = GroupStore.instance.value.availableGroupScopes;
      expect(scopes.map((scope) => scope.label), ['우리 가족', '사무실']);
      expect(scopes.every((scope) => scope.isGroup), isTrue);
    });

    test(
      'uses the first joined group as selectedGroupScope fallback',
      () async {
        gateway.loadGroupsForUserResult = <Map<String, dynamic>>[
          _groupRow(id: 'group-1', name: '우리 가족'),
          _groupRow(id: 'group-2', name: '사무실'),
        ];

        await GroupStore.instance.initialize();

        expect(
          GroupStore.instance.value.selectedScope,
          const ItemScope.group(id: 'group-1', label: '우리 가족'),
        );
        expect(
          GroupStore.instance.value.selectedGroupScope,
          const ItemScope.group(id: 'group-1', label: '우리 가족'),
        );
        expect(GroupStore.instance.value.selectedGroup?.id, 'group-1');
      },
    );

    test('keeps the selected joined group as selectedGroupScope', () async {
      gateway.loadGroupsForUserResult = <Map<String, dynamic>>[
        _groupRow(id: 'group-1', name: '우리 가족'),
        _groupRow(id: 'group-2', name: '사무실'),
      ];
      await GroupStore.instance.initialize();

      GroupStore.instance.selectScope(
        const ItemScope.group(id: 'group-2', label: '사무실'),
      );

      expect(
        GroupStore.instance.value.selectedGroupScope,
        const ItemScope.group(id: 'group-2', label: '사무실'),
      );
      expect(GroupStore.instance.value.selectedGroup?.id, 'group-2');
    });

    test('renames selected group and updates selected scope label', () async {
      gateway.loadGroupsForUserResult = <Map<String, dynamic>>[
        _groupRow(id: 'group-1', name: '우리 가족'),
        _groupRow(id: 'group-2', name: '사무실'),
      ];
      await GroupStore.instance.initialize();
      GroupStore.instance.selectScope(
        const ItemScope.group(id: 'group-1', label: '우리 가족'),
      );

      await GroupStore.instance.renameGroup(
        groupId: ' group-1 ',
        name: '  새 가족  ',
      );

      expect(gateway.renameGroupCalls, 1);
      expect(gateway.renameGroupGroupId, 'group-1');
      expect(gateway.renameGroupName, '새 가족');
      expect(GroupStore.instance.value.groups.first.name, '새 가족');
      expect(
        GroupStore.instance.value.selectedScope,
        const ItemScope.group(id: 'group-1', label: '새 가족'),
      );
      expect(GroupStore.instance.value.isUpdatingGroup, isFalse);
      expect(GroupStore.instance.value.errorMessage, isNull);
    });

    test('keeps previous group state when rename fails', () async {
      gateway.loadGroupsForUserResult = <Map<String, dynamic>>[
        _groupRow(id: 'group-1', name: '우리 가족'),
      ];
      await GroupStore.instance.initialize();
      gateway.renameGroupError = StateError('rename failed');

      await expectLater(
        GroupStore.instance.renameGroup(groupId: 'group-1', name: '새 가족'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'rename failed',
          ),
        ),
      );

      expect(GroupStore.instance.value.groups.single.name, '우리 가족');
      expect(GroupStore.instance.value.isUpdatingGroup, isFalse);
      expect(
        GroupStore.instance.value.errorMessage,
        '그룹 이름을 변경하지 못했습니다. 잠시 후 다시 시도해 주세요.',
      );
    });

    test('rejects blank rename values before gateway call', () async {
      gateway.loadGroupsForUserResult = <Map<String, dynamic>>[
        _groupRow(id: 'group-1', name: '우리 가족'),
      ];
      await GroupStore.instance.initialize();

      await expectLater(
        GroupStore.instance.renameGroup(groupId: 'group-1', name: '   '),
        throwsA(isA<ArgumentError>()),
      );

      expect(gateway.renameGroupCalls, 0);
      expect(GroupStore.instance.value.groups.single.name, '우리 가족');
    });

    test(
      'restores previous state and sets Korean error message when creation fails',
      () async {
        gateway.loadDefaultGroupResult = _groupRow(name: 'Existing Group');
        await GroupStore.instance.initialize();
        gateway.createGroupWithOwnerError = StateError('create failed');

        await expectLater(
          GroupStore.instance.createGroup('Next Group'),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'create failed',
            ),
          ),
        );

        expect(GroupStore.instance.value.group?.id, 'group-1');
        expect(GroupStore.instance.value.group?.name, 'Existing Group');
        expect(GroupStore.instance.value.isLoading, isFalse);
        expect(GroupStore.instance.value.isSaving, isFalse);
        expect(
          GroupStore.instance.value.errorMessage,
          '그룹을 만들지 못했습니다. 잠시 후 다시 시도해 주세요.',
        );
      },
    );

    test('refreshes members for the current group', () async {
      gateway.loadDefaultGroupResult = _groupRow(name: 'Existing Group');
      await GroupStore.instance.initialize();
      gateway.loadGroupMembersResult = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'member-2',
          'user_id': 'user-2',
          'role': 'member',
          'joined_at': '2026-05-26T10:22:30.000Z',
          'users': <String, dynamic>{
            'display_name': '새 멤버',
            'email': 'member@example.com',
          },
        },
      ];

      await GroupStore.instance.refreshMembers();

      expect(gateway.loadGroupMembersCalls, 1);
      expect(gateway.loadGroupMembersGroupId, 'group-1');
      expect(GroupStore.instance.value.group?.members, hasLength(1));
      expect(
        GroupStore.instance.value.group?.members.single.displayName,
        '새 멤버',
      );
      expect(
        GroupStore.instance.value.group?.members.single.role,
        GroupRole.member,
      );
      expect(GroupStore.instance.value.isRefreshingMembers, isFalse);
      expect(GroupStore.instance.value.errorMessage, isNull);
    });

    test(
      'sets an error and keeps previous members when refresh fails',
      () async {
        gateway.loadDefaultGroupResult = _groupRow(name: 'Existing Group');
        await GroupStore.instance.initialize();
        gateway.loadGroupMembersError = StateError('refresh failed');

        await expectLater(
          GroupStore.instance.refreshMembers(),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'refresh failed',
            ),
          ),
        );

        expect(gateway.loadGroupMembersCalls, 1);
        expect(
          GroupStore.instance.value.group?.members.single.displayName,
          'Owner',
        );
        expect(GroupStore.instance.value.isRefreshingMembers, isFalse);
        expect(
          GroupStore.instance.value.errorMessage,
          '멤버 목록을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.',
        );
      },
    );

    test('leaves the selected group and reloads joined groups', () async {
      gateway.loadGroupsForUserResult = <Map<String, dynamic>>[
        _groupRow(id: 'group-1', name: '우리 가족'),
        _groupRow(id: 'group-2', name: '사무실'),
      ];
      await GroupStore.instance.initialize();
      GroupStore.instance.selectScope(
        const ItemScope.group(id: 'group-1', label: '우리 가족'),
      );
      gateway.loadGroupsForUserResult = <Map<String, dynamic>>[
        _groupRow(id: 'group-2', name: '사무실'),
      ];

      await GroupStore.instance.leaveGroup(groupId: 'group-1');

      expect(gateway.leaveGroupCalls, 1);
      expect(gateway.leaveGroupGroupId, 'group-1');
      expect(gateway.leaveGroupNewOwnerUserId, isNull);
      expect(GroupStore.instance.value.groups.map((group) => group.id), [
        'group-2',
      ]);
      expect(
        GroupStore.instance.value.selectedScope,
        const ItemScope.group(id: 'group-2', label: '사무실'),
      );
      expect(GroupStore.instance.value.isLeavingGroup, isFalse);
      expect(GroupStore.instance.value.errorMessage, isNull);
    });

    test('leaves selected group and selects next remaining group', () async {
      gateway.loadGroupsForUserResult = <Map<String, dynamic>>[
        _groupRow(id: 'group-1', name: '우리 가족'),
        _groupRow(id: 'group-2', name: '사무실'),
      ];
      await GroupStore.instance.initialize();
      GroupStore.instance.selectScope(
        const ItemScope.group(id: 'group-1', label: '우리 가족'),
      );
      gateway.loadGroupsForUserResult = <Map<String, dynamic>>[
        _groupRow(id: 'group-2', name: '사무실'),
      ];

      await GroupStore.instance.leaveGroup(groupId: 'group-1');

      expect(
        GroupStore.instance.value.selectedScope,
        const ItemScope.group(id: 'group-2', label: '사무실'),
      );
      expect(
        GroupStore.instance.value.selectedGroupScope,
        const ItemScope.group(id: 'group-2', label: '사무실'),
      );
    });

    test('passes owner delegation user id when leaving as owner', () async {
      gateway.loadGroupsForUserResult = <Map<String, dynamic>>[
        _groupRow(id: 'group-1', name: '우리 가족'),
      ];
      await GroupStore.instance.initialize();

      await GroupStore.instance.leaveGroup(
        groupId: 'group-1',
        newOwnerUserId: 'member-user',
      );

      expect(gateway.leaveGroupCalls, 1);
      expect(gateway.leaveGroupNewOwnerUserId, 'member-user');
    });

    test('restores previous state when leave fails', () async {
      gateway.loadGroupsForUserResult = <Map<String, dynamic>>[
        _groupRow(id: 'group-1', name: '우리 가족'),
      ];
      await GroupStore.instance.initialize();
      gateway.leaveGroupError = StateError('leave failed');

      await expectLater(
        GroupStore.instance.leaveGroup(groupId: 'group-1'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'leave failed',
          ),
        ),
      );

      expect(GroupStore.instance.value.groups.single.id, 'group-1');
      expect(GroupStore.instance.value.isLeavingGroup, isFalse);
      expect(
        GroupStore.instance.value.errorMessage,
        '그룹을 탈퇴하지 못했습니다. 잠시 후 다시 시도해 주세요.',
      );
    });
  });
}

BuylogGroupMember _member() {
  return BuylogGroupMember(
    id: 'member-2',
    userId: 'user-2',
    displayName: '사용자',
    role: GroupRole.member,
    joinedAt: DateTime.parse('2026-05-26T10:21:30.000Z'),
  );
}

BuylogGroup _groupWithMembers() {
  return BuylogGroup(
    id: 'group-1',
    name: '우리 가족',
    inviteCode: 'BUY-ABC123',
    createdBy: 'owner-user',
    createdAt: DateTime.parse('2026-05-27T00:00:00.000Z'),
    members: [
      BuylogGroupMember(
        id: 'member-1',
        userId: 'owner-user',
        displayName: '소유자',
        role: GroupRole.owner,
        joinedAt: DateTime.parse('2026-05-27T00:00:00.000Z'),
      ),
      BuylogGroupMember(
        id: 'member-2',
        userId: 'member-user',
        displayName: '멤버',
        role: GroupRole.member,
        joinedAt: DateTime.parse('2026-05-27T00:01:00.000Z'),
      ),
    ],
  );
}

Map<String, dynamic> _groupRow({String id = 'group-1', required String name}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'invite_code': 'BUY-ABC123',
    'created_by': SupabaseService.currentUserId,
    'created_at': '2026-05-26T00:00:00.000Z',
    'group_members': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'member-1',
        'user_id': SupabaseService.currentUserId,
        'role': 'owner',
        'joined_at': '2026-05-26T00:00:00.000Z',
        'users': <String, dynamic>{
          'display_name': 'Owner',
          'email': 'owner@example.com',
        },
      },
    ],
  };
}

class _RecordingGroupDatabaseGateway implements GroupDatabaseGateway {
  int loadDefaultGroupCalls = 0;
  int loadGroupsForUserCalls = 0;
  int loadGroupMembersCalls = 0;
  int leaveGroupCalls = 0;
  int renameGroupCalls = 0;
  Object? loadDefaultGroupError;
  Object? loadGroupsForUserError;
  Object? loadGroupMembersError;
  Object? leaveGroupError;
  Object? renameGroupError;
  String? loadGroupMembersGroupId;
  String? leaveGroupGroupId;
  String? leaveGroupNewOwnerUserId;
  String? renameGroupGroupId;
  String? renameGroupName;
  Map<String, dynamic>? loadDefaultGroupResult;
  List<Map<String, dynamic>> loadGroupsForUserResult = const [];
  Map<String, dynamic>? createdGroupValues;
  Object? createGroupWithOwnerError;
  List<Map<String, dynamic>> loadGroupMembersResult = const [];
  String nextCreatedGroupId = 'group-1';

  @override
  Future<Map<String, dynamic>?> loadDefaultGroup(String userId) async {
    loadDefaultGroupCalls += 1;
    if (loadDefaultGroupError != null) {
      throw loadDefaultGroupError!;
    }
    return loadDefaultGroupResult;
  }

  @override
  Future<List<Map<String, dynamic>>> loadGroupsForUser(String userId) async {
    loadGroupsForUserCalls += 1;
    if (loadGroupsForUserError != null) {
      throw loadGroupsForUserError!;
    }
    if (loadGroupsForUserResult.isNotEmpty) {
      return loadGroupsForUserResult;
    }
    return loadDefaultGroupResult == null
        ? const <Map<String, dynamic>>[]
        : <Map<String, dynamic>>[loadDefaultGroupResult!];
  }

  @override
  Future<Map<String, dynamic>> createGroupWithOwner({
    required String name,
    required String inviteCode,
  }) async {
    if (createGroupWithOwnerError != null) {
      throw createGroupWithOwnerError!;
    }

    createdGroupValues = <String, dynamic>{
      'name': name,
      'invite_code': inviteCode,
    };
    return <String, dynamic>{
      'id': nextCreatedGroupId,
      'name': name,
      'invite_code': inviteCode,
      'created_by': SupabaseService.currentUserId,
      'created_at': '2026-05-26T00:00:00.000Z',
      'group_members': <Map<String, dynamic>>[],
    };
  }

  @override
  Future<Map<String, dynamic>> renameGroup({
    required String groupId,
    required String name,
  }) async {
    renameGroupCalls += 1;
    renameGroupGroupId = groupId;
    renameGroupName = name;
    if (renameGroupError != null) {
      throw renameGroupError!;
    }
    return _groupRow(id: groupId, name: name);
  }

  @override
  Future<List<Map<String, dynamic>>> loadGroupMembers({
    required String groupId,
  }) async {
    loadGroupMembersCalls += 1;
    loadGroupMembersGroupId = groupId;
    if (loadGroupMembersError != null) {
      throw loadGroupMembersError!;
    }
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
    if (leaveGroupError != null) {
      throw leaveGroupError!;
    }
  }
}
