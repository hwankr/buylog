import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:buylog/models/group.dart';
import 'package:buylog/models/item.dart';
import 'package:buylog/models/item_scope.dart';
import 'package:buylog/services/supabase_service.dart';

class _RecordingGroupDatabaseGateway implements GroupDatabaseGateway {
  int loadDefaultGroupCalls = 0;
  int loadGroupsForUserCalls = 0;
  int createGroupWithOwnerCalls = 0;
  int loadGroupMembersCalls = 0;
  int leaveGroupCalls = 0;
  int renameGroupCalls = 0;
  String? createGroupWithOwnerName;
  String? createGroupWithOwnerInviteCode;
  String? loadGroupMembersGroupId;
  String? leaveGroupGroupId;
  String? leaveGroupNewOwnerUserId;
  String? renameGroupGroupId;
  String? renameGroupName;
  Map<String, dynamic>? loadDefaultGroupResult;
  List<Map<String, dynamic>> loadGroupsForUserResult = const [];
  Map<String, dynamic>? createGroupWithOwnerResult;
  Object? createGroupWithOwnerError;
  List<Map<String, dynamic>> loadGroupMembersResult = const [];

  @override
  Future<Map<String, dynamic>?> loadDefaultGroup(String userId) async {
    loadDefaultGroupCalls += 1;
    return loadDefaultGroupResult;
  }

  @override
  Future<List<Map<String, dynamic>>> loadGroupsForUser(String userId) async {
    loadGroupsForUserCalls += 1;
    return loadGroupsForUserResult;
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
  Future<Map<String, dynamic>> renameGroup({
    required String groupId,
    required String name,
  }) async {
    renameGroupCalls += 1;
    renameGroupGroupId = groupId;
    renameGroupName = name;
    return <String, dynamic>{
      'id': groupId,
      'name': name,
      'invite_code': 'BUY-ABC123',
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
  }
}

class _RecordingItemDatabaseGateway implements ItemDatabaseGateway {
  String? lastUserId;
  String? lastGroupId;
  List<Map<String, dynamic>> loadItemsResult = const [];
  String? ensureCategoryName;
  String? ensureCategoryUserId;
  String? ensureCategoryGroupId;
  Map<String, dynamic>? upsertedItemPayload;
  final List<Map<String, dynamic>> insertedPurchasePayloads = [];
  String ensuredCategoryId = 'category-1';

  @override
  Future<List<Map<String, dynamic>>> loadItems({
    required String? userId,
    required String? groupId,
  }) async {
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
    ensureCategoryName = name;
    ensureCategoryUserId = userId;
    ensureCategoryGroupId = groupId;
    return ensuredCategoryId;
  }

  @override
  Future<void> upsertItem(Map<String, dynamic> payload) async {
    upsertedItemPayload = Map<String, dynamic>.from(payload);
  }

  @override
  Future<void> insertPurchase(Map<String, dynamic> payload) async {
    insertedPurchasePayloads.add(Map<String, dynamic>.from(payload));
  }
}

Map<String, dynamic> _itemRow({
  required String id,
  String? userId,
  String? groupId,
}) {
  return <String, dynamic>{
    'id': id,
    'user_id': userId,
    'group_id': groupId,
    'registered_by': userId ?? SupabaseService.currentUserId,
    'name': '세제',
    'brand': '브랜드',
    'image_url': null,
    'replacement_cycle_days': 30,
    'created_at': '2026-05-26T00:00:00.000Z',
    'categories': <String, dynamic>{'id': 'category-1', 'name': '주방/세제'},
    'purchases': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'purchase-1',
        'purchase_date': '2026-05-20',
        'price': 8900,
        'store_name': '마트',
      },
    ],
    'ai_predictions': <Map<String, dynamic>>[],
    'product_inventory_snapshots': <Map<String, dynamic>>[],
  };
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
  test('normalizePostgrestRows returns typed map copies from dynamic rows', () {
    final rawRows = <dynamic>[
      <String, dynamic>{'id': 'row-1'},
      <String, dynamic>{'id': 'row-2'},
    ];

    final rows = SupabaseService.normalizePostgrestRows(rawRows);

    expect(rows, isA<List<Map<String, dynamic>>>());
    expect(rows, hasLength(2));
    rawRows.first['id'] = 'changed';
    expect(rows.first['id'], 'row-1');
  });

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

  group('SupabaseService.renameGroup', () {
    tearDown(() {
      SupabaseService.debugGroupDatabaseGateway = null;
    });

    test('trims group id and name before gateway update', () async {
      final gateway = _RecordingGroupDatabaseGateway();
      SupabaseService.debugGroupDatabaseGateway = gateway;

      final group = await SupabaseService.renameGroup(
        groupId: ' group-1 ',
        name: '  새 가족  ',
      );

      expect(gateway.renameGroupCalls, 1);
      expect(gateway.renameGroupGroupId, 'group-1');
      expect(gateway.renameGroupName, '새 가족');
      expect(group.id, 'group-1');
      expect(group.name, '새 가족');
    });

    test('rejects blank group ids without calling gateway', () async {
      final gateway = _RecordingGroupDatabaseGateway();
      SupabaseService.debugGroupDatabaseGateway = gateway;

      await expectLater(
        SupabaseService.renameGroup(groupId: '   ', name: '새 가족'),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'Group id is required.',
          ),
        ),
      );

      expect(gateway.renameGroupCalls, 0);
    });

    test('rejects blank names without calling gateway', () async {
      final gateway = _RecordingGroupDatabaseGateway();
      SupabaseService.debugGroupDatabaseGateway = gateway;

      await expectLater(
        SupabaseService.renameGroup(groupId: 'group-1', name: '   '),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'Group name is required.',
          ),
        ),
      );

      expect(gateway.renameGroupCalls, 0);
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

  group('SupabaseService.leaveGroup', () {
    tearDown(() {
      SupabaseService.debugGroupDatabaseGateway = null;
    });

    test('trims ids and delegates to the group gateway', () async {
      final gateway = _RecordingGroupDatabaseGateway();
      SupabaseService.debugGroupDatabaseGateway = gateway;

      await SupabaseService.leaveGroup(
        groupId: ' group-1 ',
        newOwnerUserId: ' member-user ',
      );

      expect(gateway.leaveGroupCalls, 1);
      expect(gateway.leaveGroupGroupId, 'group-1');
      expect(gateway.leaveGroupNewOwnerUserId, 'member-user');
    });

    test('passes null owner delegation for non-owner leave', () async {
      final gateway = _RecordingGroupDatabaseGateway();
      SupabaseService.debugGroupDatabaseGateway = gateway;

      await SupabaseService.leaveGroup(groupId: 'group-1');

      expect(gateway.leaveGroupCalls, 1);
      expect(gateway.leaveGroupGroupId, 'group-1');
      expect(gateway.leaveGroupNewOwnerUserId, isNull);
    });

    test('rejects blank group ids without calling the gateway', () async {
      final gateway = _RecordingGroupDatabaseGateway();
      SupabaseService.debugGroupDatabaseGateway = gateway;

      await expectLater(
        SupabaseService.leaveGroup(groupId: '   '),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'Group id is required.',
          ),
        ),
      );

      expect(gateway.leaveGroupCalls, 0);
    });
  });

  group('SupabaseService.loadItemsForScope', () {
    tearDown(() {
      SupabaseService.debugItemDatabaseGateway = null;
    });

    test('loads personal items through user id', () async {
      final gateway = _RecordingItemDatabaseGateway()
        ..loadItemsResult = <Map<String, dynamic>>[
          _itemRow(id: 'personal-1', userId: SupabaseService.currentUserId),
        ];
      SupabaseService.debugItemDatabaseGateway = gateway;

      final items = await SupabaseService.loadItemsForScope(
        const ItemScope.personal(),
      );

      expect(items.single.id, 'personal-1');
      expect(gateway.lastUserId, SupabaseService.currentUserId);
      expect(gateway.lastGroupId, isNull);
    });

    test('loads group items through group id', () async {
      final gateway = _RecordingItemDatabaseGateway()
        ..loadItemsResult = <Map<String, dynamic>>[
          _itemRow(id: 'group-item-1', groupId: 'group-1'),
        ];
      SupabaseService.debugItemDatabaseGateway = gateway;

      final items = await SupabaseService.loadItemsForScope(
        const ItemScope.group(id: 'group-1', label: '우리 가족'),
      );

      expect(items.single.id, 'group-item-1');
      expect(items.single.groupId, 'group-1');
      expect(gateway.lastUserId, isNull);
      expect(gateway.lastGroupId, 'group-1');
    });

    test('maps registered user display data for group items', () async {
      final gateway = _RecordingItemDatabaseGateway()
        ..loadItemsResult = <Map<String, dynamic>>[
          _itemRow(id: 'group-item-1', groupId: 'group-1')
            ..['registered_by_user'] = <String, dynamic>{
              'id': SupabaseService.currentUserId,
              'display_name': 'Minseo',
              'email': 'minseo@example.com',
            },
        ];
      SupabaseService.debugItemDatabaseGateway = gateway;

      final items = await SupabaseService.loadItemsForScope(
        const ItemScope.group(id: 'group-1', label: 'Family'),
      );

      expect(items.single.registeredBy, SupabaseService.currentUserId);
      expect(items.single.registeredByDisplayName, 'Minseo');
      expect(items.single.registeredByEmail, 'minseo@example.com');
      expect(items.single.registeredByLabel, 'Minseo');
    });

    test(
      'uses registered user email as label when display name is blank',
      () async {
        final gateway = _RecordingItemDatabaseGateway()
          ..loadItemsResult = <Map<String, dynamic>>[
            _itemRow(id: 'group-item-1', groupId: 'group-1')
              ..['registered_by_user'] = <String, dynamic>{
                'id': SupabaseService.currentUserId,
                'display_name': '   ',
                'email': 'minseo@example.com',
              },
          ];
        SupabaseService.debugItemDatabaseGateway = gateway;

        final items = await SupabaseService.loadItemsForScope(
          const ItemScope.group(id: 'group-1', label: 'Family'),
        );

        expect(items.single.registeredByLabel, 'minseo@example.com');
      },
    );

    test('maps latest inventory snapshot for personal items', () async {
      final gateway = _RecordingItemDatabaseGateway()
        ..loadItemsResult = <Map<String, dynamic>>[
          _itemRow(id: 'personal-1', userId: SupabaseService.currentUserId)
            ..['product_inventory_snapshots'] = <Map<String, dynamic>>[
              <String, dynamic>{
                'remaining_quantity': 3,
                'confidence': 0.91,
                'source_detected_name': 'Milk',
                'observed_at': '2026-05-29T06:12:00.000Z',
              },
            ],
        ];
      SupabaseService.debugItemDatabaseGateway = gateway;

      final items = await SupabaseService.loadItemsForScope(
        const ItemScope.personal(),
      );

      expect(items.single.remainingQuantity, 3);
      expect(items.single.inventoryConfidence, 0.91);
      expect(items.single.inventorySourceName, 'Milk');
      expect(
        items.single.inventoryObservedAt,
        DateTime.parse('2026-05-29T06:12:00.000Z'),
      );
      expect(items.single.remainingQuantityLabel, '현재 3개');
    });

    test('leaves inventory fields null when no snapshot exists', () async {
      final gateway = _RecordingItemDatabaseGateway()
        ..loadItemsResult = <Map<String, dynamic>>[
          _itemRow(id: 'personal-1', userId: SupabaseService.currentUserId),
        ];
      SupabaseService.debugItemDatabaseGateway = gateway;

      final items = await SupabaseService.loadItemsForScope(
        const ItemScope.personal(),
      );

      expect(items.single.remainingQuantity, isNull);
      expect(items.single.inventoryObservedAt, isNull);
      expect(items.single.inventoryConfidence, isNull);
      expect(items.single.inventorySourceName, isNull);
      expect(items.single.remainingQuantityLabel, isNull);
    });
  });

  group('SupabaseService.saveItem scoped ownership', () {
    tearDown(() {
      SupabaseService.debugItemDatabaseGateway = null;
    });

    test('saves group items with group_id and null user_id', () async {
      final gateway = _RecordingItemDatabaseGateway();
      SupabaseService.debugItemDatabaseGateway = gateway;

      await SupabaseService.saveItem(
        ConsumableItem(
          id: 'item-1',
          name: '세제',
          brand: '브랜드',
          category: '주방/세제',
          icon: ConsumableItem.iconForCategory('주방/세제'),
          daysRemaining: 30,
          cycleDays: 30,
          progress: 0,
          purchaseHistory: [
            PurchaseRecord(
              date: DateTime(2026, 5, 27),
              price: 8900,
              store: '마트',
            ),
          ],
        ),
        scope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
      );

      expect(gateway.ensureCategoryName, '주방/세제');
      expect(gateway.ensureCategoryUserId, isNull);
      expect(gateway.ensureCategoryGroupId, 'group-1');
      expect(gateway.upsertedItemPayload?['id'], 'item-1');
      expect(gateway.upsertedItemPayload?['user_id'], isNull);
      expect(gateway.upsertedItemPayload?['group_id'], 'group-1');
      expect(
        gateway.upsertedItemPayload?['registered_by'],
        SupabaseService.currentUserId,
      );
      expect(
        gateway.insertedPurchasePayloads.single['product_item_id'],
        'item-1',
      );
    });

    test('saves personal items with user_id and null group_id', () async {
      final gateway = _RecordingItemDatabaseGateway();
      SupabaseService.debugItemDatabaseGateway = gateway;

      await SupabaseService.saveItem(
        ConsumableItem(
          id: 'item-1',
          name: '샴푸',
          brand: '브랜드',
          category: '헤어/바디',
          icon: ConsumableItem.iconForCategory('헤어/바디'),
          daysRemaining: 30,
          cycleDays: 30,
          progress: 0,
        ),
      );

      expect(gateway.ensureCategoryUserId, SupabaseService.currentUserId);
      expect(gateway.ensureCategoryGroupId, isNull);
      expect(
        gateway.upsertedItemPayload?['user_id'],
        SupabaseService.currentUserId,
      );
      expect(gateway.upsertedItemPayload?['group_id'], isNull);
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
