import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:buylog/models/group.dart';
import 'package:buylog/services/supabase_service.dart';

class _RecordingGroupDatabaseGateway implements GroupDatabaseGateway {
  int loadDefaultGroupCalls = 0;
  int createGroupWithOwnerCalls = 0;
  int loadGroupMembersCalls = 0;
  String? createGroupWithOwnerName;
  String? createGroupWithOwnerInviteCode;
  String? loadGroupMembersGroupId;
  Map<String, dynamic>? loadDefaultGroupResult;
  Map<String, dynamic>? createGroupWithOwnerResult;
  Object? createGroupWithOwnerError;
  List<Map<String, dynamic>> loadGroupMembersResult = const [];

  @override
  Future<Map<String, dynamic>?> loadDefaultGroup(String userId) async {
    loadDefaultGroupCalls += 1;
    return loadDefaultGroupResult;
  }

  @override
  Future<Map<String, dynamic>> createGroupWithOwner({
    required String name,
    required String inviteCode,
  }) async {
    createGroupWithOwnerCalls += 1;
    createGroupWithOwnerName = name;
    createGroupWithOwnerInviteCode = inviteCode;

    if (createGroupWithOwnerError != null) {
      throw createGroupWithOwnerError!;
    }

    return createGroupWithOwnerResult ??
        <String, dynamic>{
          'id': 'group-1',
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
                'display_name': 'Owner',
                'email': 'owner@example.com',
              },
            },
          ],
        };
  }

  @override
  Future<List<Map<String, dynamic>>> loadGroupMembers({
    required String groupId,
  }) async {
    loadGroupMembersCalls += 1;
    loadGroupMembersGroupId = groupId;
    return loadGroupMembersResult;
  }
}

class _FailingImageStorageGateway implements ProductImageStorageGateway {
  @override
  Future<void> uploadBinary(
    String path,
    Uint8List imageBytes,
    FileOptions fileOptions,
  ) {
    throw StateError('upload failed');
  }

  @override
  String getPublicUrl(String path) => 'https://example.com/$path';
}

class _RecordingImageStorageGateway implements ProductImageStorageGateway {
  String? uploadedPath;
  Uint8List? uploadedBytes;
  FileOptions? uploadedOptions;

  @override
  Future<void> uploadBinary(
    String path,
    Uint8List imageBytes,
    FileOptions fileOptions,
  ) async {
    uploadedPath = path;
    uploadedBytes = imageBytes;
    uploadedOptions = fileOptions;
  }

  @override
  String getPublicUrl(String path) => 'https://cdn.example.com/$path';
}

void main() {
  group('SupabaseService.createGroup', () {
    tearDown(() {
      SupabaseService.debugGroupDatabaseGateway = null;
    });

    test('creates a trimmed group through one atomic gateway call', () async {
      final gateway = _RecordingGroupDatabaseGateway()
        ..createGroupWithOwnerResult = <String, dynamic>{
          'id': 'group-1',
          'name': 'My Group',
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
      SupabaseService.debugGroupDatabaseGateway = gateway;

      final group = await SupabaseService.createGroup(name: '  My Group  ');

      expect(gateway.createGroupWithOwnerCalls, 1);
      expect(gateway.createGroupWithOwnerName, 'My Group');
      expect(gateway.createGroupWithOwnerInviteCode, startsWith('BUY-'));
      expect(gateway.createGroupWithOwnerInviteCode?.length, 10);
      expect(gateway.loadDefaultGroupCalls, 0);
      expect(group.id, 'group-1');
      expect(group.name, 'My Group');
      expect(group.members.single.role.databaseValue, 'owner');
    });

    test('rejects blank names without calling gateway', () async {
      final gateway = _RecordingGroupDatabaseGateway();
      SupabaseService.debugGroupDatabaseGateway = gateway;

      await expectLater(
        SupabaseService.createGroup(name: '   '),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'Group name is required.',
          ),
        ),
      );

      expect(gateway.createGroupWithOwnerCalls, 0);
      expect(gateway.loadDefaultGroupCalls, 0);
    });

    test('propagates atomic group creation failures', () async {
      final gateway = _RecordingGroupDatabaseGateway()
        ..createGroupWithOwnerError = StateError('atomic create failed');
      SupabaseService.debugGroupDatabaseGateway = gateway;

      await expectLater(
        SupabaseService.createGroup(name: 'Group Name'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'atomic create failed',
          ),
        ),
      );

      expect(gateway.createGroupWithOwnerCalls, 1);
      expect(gateway.createGroupWithOwnerName, 'Group Name');
      expect(gateway.loadDefaultGroupCalls, 0);
    });
  });

  group('SupabaseService.loadGroupMembers', () {
    tearDown(() {
      SupabaseService.debugGroupDatabaseGateway = null;
    });

    test('loads group members through the gateway and maps roles', () async {
      final gateway = _RecordingGroupDatabaseGateway()
        ..loadGroupMembersResult = <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'member-1',
            'user_id': 'user-1',
            'role': 'owner',
            'joined_at': '2026-05-26T10:00:00.000Z',
            'users': <String, dynamic>{
              'display_name': '소유자',
              'email': 'owner@example.com',
            },
          },
          <String, dynamic>{
            'id': 'member-2',
            'user_id': 'user-2',
            'role': 'member',
            'joined_at': '2026-05-26T10:01:00.000Z',
            'users': <String, dynamic>{
              'display_name': '멤버',
              'email': 'member@example.com',
            },
          },
        ];
      SupabaseService.debugGroupDatabaseGateway = gateway;

      final members = await SupabaseService.loadGroupMembers(
        groupId: ' group-1 ',
      );

      expect(gateway.loadGroupMembersCalls, 1);
      expect(gateway.loadGroupMembersGroupId, 'group-1');
      expect(members, hasLength(2));
      expect(members.first.displayName, '소유자');
      expect(members.first.role, GroupRole.owner);
      expect(members.last.displayName, '멤버');
      expect(members.last.role, GroupRole.member);
    });

    test('rejects blank group ids without calling the gateway', () async {
      final gateway = _RecordingGroupDatabaseGateway();
      SupabaseService.debugGroupDatabaseGateway = gateway;

      await expectLater(
        SupabaseService.loadGroupMembers(groupId: '   '),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'Group id is required.',
          ),
        ),
      );

      expect(gateway.loadGroupMembersCalls, 0);
    });
  });

  group('SupabaseService.uploadItemImage', () {
    tearDown(() {
      SupabaseService.debugImageStorageGateway = null;
    });

    test('propagates upload failures instead of returning null', () async {
      SupabaseService.debugImageStorageGateway = _FailingImageStorageGateway();

      await expectLater(
        SupabaseService.uploadItemImage(
          imageBytes: Uint8List.fromList([1, 2, 3]),
          itemId: 'item-1',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'uploads item images under the stable items path and returns public URL',
      () async {
        final gateway = _RecordingImageStorageGateway();
        SupabaseService.debugImageStorageGateway = gateway;
        final bytes = Uint8List.fromList([255, 216, 255, 217]);

        final url = await SupabaseService.uploadItemImage(
          imageBytes: bytes,
          itemId: 'item-1',
        );

        expect(gateway.uploadedPath, 'items/item-1.jpg');
        expect(gateway.uploadedBytes, bytes);
        expect(gateway.uploadedOptions?.upsert, isTrue);
        expect(gateway.uploadedOptions?.contentType, 'image/jpeg');
        expect(url, 'https://cdn.example.com/items/item-1.jpg');
      },
    );
  });
}
