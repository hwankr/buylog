import 'package:buylog/models/group.dart';
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
      expect(gateway.loadDefaultGroupCalls, 1);
    });

    test('sets Korean error state and rethrows when preload fails', () async {
      gateway.loadDefaultGroupError = StateError('load failed');

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
      expect(gateway.loadDefaultGroupCalls, 1);
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
  int loadGroupMembersCalls = 0;
  Object? loadDefaultGroupError;
  Object? loadGroupMembersError;
  String? loadGroupMembersGroupId;
  Map<String, dynamic>? loadDefaultGroupResult;
  Map<String, dynamic>? createdGroupValues;
  Object? createGroupWithOwnerError;
  List<Map<String, dynamic>> loadGroupMembersResult = const [];

  @override
  Future<Map<String, dynamic>?> loadDefaultGroup(String userId) async {
    loadDefaultGroupCalls += 1;
    if (loadDefaultGroupError != null) {
      throw loadDefaultGroupError!;
    }
    return loadDefaultGroupResult;
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
      'id': 'group-1',
      'name': name,
      'invite_code': inviteCode,
      'created_by': SupabaseService.currentUserId,
      'created_at': '2026-05-26T00:00:00.000Z',
      'group_members': <Map<String, dynamic>>[],
    };
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
}
