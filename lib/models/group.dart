enum GroupRole {
  owner,
  member;

  static GroupRole fromDatabase(String? value) {
    return value == 'owner' ? GroupRole.owner : GroupRole.member;
  }

  String get databaseValue {
    return switch (this) {
      GroupRole.owner => 'owner',
      GroupRole.member => 'member',
    };
  }
}

class BuylogGroup {
  final String id;
  final String name;
  final String inviteCode;
  final String createdBy;
  final DateTime createdAt;
  final List<BuylogGroupMember> members;

  const BuylogGroup({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.createdBy,
    required this.createdAt,
    this.members = const [],
  });

  factory BuylogGroup.fromSupabase(Map<String, dynamic> row) {
    final members = row['group_members'] as List<dynamic>?;

    return BuylogGroup(
      id: row['id'] as String,
      name: row['name'] as String,
      inviteCode: row['invite_code'] as String,
      createdBy: row['created_by'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      members: List.unmodifiable(
        members?.whereType<Map<String, dynamic>>().map(
              BuylogGroupMember.fromSupabase,
            ) ??
            const <BuylogGroupMember>[],
      ),
    );
  }
}

class BuylogGroupMember {
  final String id;
  final String userId;
  final String displayName;
  final GroupRole role;
  final DateTime joinedAt;

  const BuylogGroupMember({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.role,
    required this.joinedAt,
  });

  factory BuylogGroupMember.fromSupabase(Map<String, dynamic> row) {
    final user = row['users'] as Map<String, dynamic>?;
    final displayName = (user?['display_name'] as String?)?.trim();
    final email = (user?['email'] as String?)?.trim();

    return BuylogGroupMember(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      displayName: displayName?.isNotEmpty == true
          ? displayName!
          : (email?.isNotEmpty == true ? email! : '사용자'),
      role: GroupRole.fromDatabase(row['role'] as String?),
      joinedAt: DateTime.parse(row['joined_at'] as String),
    );
  }
}
