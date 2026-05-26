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
      expect(
        GroupStore.instance.value.errorMessage,
        '그룹 정보를 불러오지 못했습니다.',
      );
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
      expect(gateway.insertedGroupValues?['name'], 'My Group');
      expect(gateway.loadDefaultGroupCalls, 1);
    });

    test(
      'restores previous state and sets Korean error message when creation fails',
      () async {
        gateway.loadDefaultGroupResult = _groupRow(name: 'Existing Group');
        await GroupStore.instance.initialize();
        gateway.updateDefaultGroupError = StateError('create failed');

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

Map<String, dynamic> _groupRow({
  String id = 'group-1',
  required String name,
}) {
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
  Object? loadDefaultGroupError;
  Map<String, dynamic>? loadDefaultGroupResult;
  Map<String, dynamic>? insertedGroupValues;
  Object? updateDefaultGroupError;

  @override
  Future<Map<String, dynamic>?> loadDefaultGroup(String userId) async {
    loadDefaultGroupCalls += 1;
    if (loadDefaultGroupError != null) {
      throw loadDefaultGroupError!;
    }
    return loadDefaultGroupResult;
  }

  @override
  Future<Map<String, dynamic>> insertGroup(Map<String, dynamic> values) async {
    insertedGroupValues = Map<String, dynamic>.from(values);
    return <String, dynamic>{
      'id': 'group-1',
      'name': values['name'],
      'invite_code': values['invite_code'],
      'created_by': values['created_by'],
      'created_at': '2026-05-26T00:00:00.000Z',
      'group_members': <Map<String, dynamic>>[],
    };
  }

  @override
  Future<void> insertGroupMember(Map<String, dynamic> values) async {}

  @override
  Future<void> updateDefaultGroup({
    required String userId,
    required String groupId,
  }) async {
    if (updateDefaultGroupError != null) {
      throw updateDefaultGroupError!;
    }
  }
}
