import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:buylog/services/supabase_service.dart';

class _RecordingGroupDatabaseGateway implements GroupDatabaseGateway {
  int loadDefaultGroupCalls = 0;
  Map<String, dynamic>? insertedGroupValues;
  Map<String, dynamic>? insertedGroupMemberValues;
  String? updatedDefaultGroupUserId;
  String? updatedDefaultGroupId;
  Map<String, dynamic>? loadDefaultGroupResult;
  Map<String, dynamic>? insertedGroupResult;
  Object? updateDefaultGroupError;

  @override
  Future<Map<String, dynamic>?> loadDefaultGroup(String userId) async {
    loadDefaultGroupCalls += 1;
    return loadDefaultGroupResult;
  }

  @override
  Future<Map<String, dynamic>> insertGroup(Map<String, dynamic> values) async {
    insertedGroupValues = Map<String, dynamic>.from(values);
    return insertedGroupResult ??
        <String, dynamic>{
          'id': 'group-1',
          'name': values['name'],
          'invite_code': values['invite_code'],
          'created_by': values['created_by'],
          'created_at': '2026-05-26T00:00:00.000Z',
          'group_members': <Map<String, dynamic>>[],
        };
  }

  @override
  Future<void> insertGroupMember(Map<String, dynamic> values) async {
    insertedGroupMemberValues = Map<String, dynamic>.from(values);
  }

  @override
  Future<void> updateDefaultGroup({
    required String userId,
    required String groupId,
  }) async {
    if (updateDefaultGroupError != null) {
      throw updateDefaultGroupError!;
    }
    updatedDefaultGroupUserId = userId;
    updatedDefaultGroupId = groupId;
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

    test(
      'creates a trimmed group, inserts owner membership, and updates default group',
      () async {
        final gateway = _RecordingGroupDatabaseGateway()
          ..loadDefaultGroupResult = <String, dynamic>{
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

        expect(gateway.insertedGroupValues?['name'], 'My Group');
        expect(
          gateway.insertedGroupValues?['created_by'],
          SupabaseService.currentUserId,
        );
        expect(
          gateway.insertedGroupValues?['invite_code'] as String,
          startsWith('BUY-'),
        );
        expect(
          (gateway.insertedGroupValues?['invite_code'] as String).length,
          10,
        );
        expect(gateway.insertedGroupMemberValues, <String, dynamic>{
          'group_id': 'group-1',
          'user_id': SupabaseService.currentUserId,
          'role': 'owner',
        });
        expect(
          gateway.updatedDefaultGroupUserId,
          SupabaseService.currentUserId,
        );
        expect(gateway.updatedDefaultGroupId, 'group-1');
        expect(gateway.loadDefaultGroupCalls, 1);
        expect(group.id, 'group-1');
        expect(group.name, 'My Group');
        expect(group.members.single.role.databaseValue, 'owner');
      },
    );

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

      expect(gateway.insertedGroupValues, isNull);
      expect(gateway.insertedGroupMemberValues, isNull);
      expect(gateway.updatedDefaultGroupUserId, isNull);
      expect(gateway.loadDefaultGroupCalls, 0);
    });

    test('propagates default-group update failures', () async {
      final gateway = _RecordingGroupDatabaseGateway()
        ..updateDefaultGroupError = StateError('default group update failed');
      SupabaseService.debugGroupDatabaseGateway = gateway;

      await expectLater(
        SupabaseService.createGroup(name: 'Group Name'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'default group update failed',
          ),
        ),
      );

      expect(gateway.insertedGroupValues?['name'], 'Group Name');
      expect(gateway.insertedGroupMemberValues, <String, dynamic>{
        'group_id': 'group-1',
        'user_id': SupabaseService.currentUserId,
        'role': 'owner',
      });
      expect(
        gateway.updatedDefaultGroupUserId,
        isNull,
        reason: 'failed update should not be reported as successful',
      );
      expect(
        gateway.updatedDefaultGroupId,
        isNull,
        reason: 'failed update should not be reported as successful',
      );
      expect(gateway.loadDefaultGroupCalls, 0);
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
