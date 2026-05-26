import 'package:buylog/models/group.dart';
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
