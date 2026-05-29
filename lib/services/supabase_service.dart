import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/group.dart';
import '../models/item.dart';
import '../models/item_scope.dart';
import '../services/ai/category_defaults.dart';
import '../services/ai/personal_regression_service.dart';
import '../services/ai/prediction_service.dart';
import '../services/daily_usage_service.dart';

/// Supabase 연동 서비스
///
/// 프로젝트: fervijwxdgkwjtcpzskx
/// 테이블: product_items / purchases / categories / ai_predictions
/// Storage: product-images 버킷 (공개)
class SupabaseService {
  static const _supabaseUrlFromEnvironment = String.fromEnvironment(
    'SUPABASE_URL',
  );
  static const _anonKeyFromEnvironment = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );
  static const _storageBucket = 'product-images';
  static const _groupInviteCodeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static SupabaseClient get _db => Supabase.instance.client;

  @visibleForTesting
  static ProductImageStorageGateway? debugImageStorageGateway;

  @visibleForTesting
  static GroupDatabaseGateway? debugGroupDatabaseGateway;

  @visibleForTesting
  static ItemDatabaseGateway? debugItemDatabaseGateway;

  static GroupDatabaseGateway get _groupDatabaseGateway =>
      debugGroupDatabaseGateway ?? SupabaseGroupDatabaseGateway(_db);

  static ItemDatabaseGateway get _itemDatabaseGateway =>
      debugItemDatabaseGateway ?? SupabaseItemDatabaseGateway(_db);

  // ────────────────────────────────────────────────────────────────────────────
  // 초기화 & 인증
  // ────────────────────────────────────────────────────────────────────────────

  /// 개발용 임시 사용자 ID (RLS 비활성 환경에서 사용)
  static const _devUserId = '08cccfe3-766f-43bd-b06c-8d909e0f9fe8';

  /// Supabase 초기화
  static Future<void> initialize() async {
    await dotenv.load(fileName: '.env', isOptional: true);
    final supabaseUrl = _resolveConfigValue(
      compileTimeValue: _supabaseUrlFromEnvironment,
      dotenvKey: 'SUPABASE_URL',
    );
    final anonKey = _resolveConfigValue(
      compileTimeValue: _anonKeyFromEnvironment,
      dotenvKey: 'SUPABASE_ANON_KEY',
    );

    if (supabaseUrl == null || anonKey == null) {
      throw StateError(
        'Missing Supabase configuration. Set SUPABASE_URL and SUPABASE_ANON_KEY.',
      );
    }

    await Supabase.initialize(url: supabaseUrl, anonKey: anonKey);
    debugPrint('[Supabase] 초기화 완료');
  }

  static String? _resolveConfigValue({
    required String compileTimeValue,
    required String dotenvKey,
  }) {
    final value = compileTimeValue.isNotEmpty
        ? compileTimeValue
        : dotenv.env[dotenvKey];
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value.trim();
  }

  @visibleForTesting
  static List<Map<String, dynamic>> normalizePostgrestRows(Object? rows) {
    if (rows is! Iterable) {
      return const <Map<String, dynamic>>[];
    }
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  /// 현재 사용자 ID
  static String get currentUserId => _devUserId;

  static Future<BuylogGroup?> loadDefaultGroup() async {
    final row = await _groupDatabaseGateway.loadDefaultGroup(currentUserId);
    if (row == null) {
      return null;
    }

    return BuylogGroup.fromSupabase(row);
  }

  static Future<List<BuylogGroup>> loadGroupsForUser() async {
    final rows = await _groupDatabaseGateway.loadGroupsForUser(currentUserId);
    return rows.map(BuylogGroup.fromSupabase).toList(growable: false);
  }

  static Future<BuylogGroup> createGroup({required String name}) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Group name is required.');
    }

    final createdGroup = await _groupDatabaseGateway.createGroupWithOwner(
      name: trimmedName,
      inviteCode: _generateInviteCode(),
    );
    return BuylogGroup.fromSupabase(createdGroup);
  }

  static Future<BuylogGroup> renameGroup({
    required String groupId,
    required String name,
  }) async {
    final trimmedGroupId = groupId.trim();
    if (trimmedGroupId.isEmpty) {
      throw ArgumentError.value(groupId, 'groupId', 'Group id is required.');
    }

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Group name is required.');
    }

    final updatedGroup = await _groupDatabaseGateway.renameGroup(
      groupId: trimmedGroupId,
      name: trimmedName,
    );
    return BuylogGroup.fromSupabase(updatedGroup);
  }

  static Future<List<BuylogGroupMember>> loadGroupMembers({
    required String groupId,
  }) async {
    final trimmedGroupId = groupId.trim();
    if (trimmedGroupId.isEmpty) {
      throw ArgumentError.value(groupId, 'groupId', 'Group id is required.');
    }

    final rows = await _groupDatabaseGateway.loadGroupMembers(
      groupId: trimmedGroupId,
    );
    return List<BuylogGroupMember>.unmodifiable(
      rows.map(BuylogGroupMember.fromSupabase),
    );
  }

  static Future<void> leaveGroup({
    required String groupId,
    String? newOwnerUserId,
  }) async {
    final trimmedGroupId = groupId.trim();
    if (trimmedGroupId.isEmpty) {
      throw ArgumentError.value(groupId, 'groupId', 'Group id is required.');
    }

    final trimmedOwnerUserId = newOwnerUserId?.trim();
    await _groupDatabaseGateway.leaveGroup(
      groupId: trimmedGroupId,
      newOwnerUserId: trimmedOwnerUserId?.isEmpty == true
          ? null
          : trimmedOwnerUserId,
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // 이미지 업로드
  // ────────────────────────────────────────────────────────────────────────────

  /// 제품 이미지를 Storage에 업로드하고 공개 URL을 반환합니다.
  ///
  /// [imageBytes] 업로드할 이미지 바이트 (image_picker로 획득)
  /// [itemId]     제품 UUID (파일 경로에 사용)
  static Future<String> uploadItemImage({
    required Uint8List imageBytes,
    required String itemId,
  }) async {
    try {
      final path = 'items/$itemId.jpg';
      final storage =
          debugImageStorageGateway ??
          ProductImageStorageGateway.fromClient(_db, _storageBucket);
      await storage.uploadBinary(
        path,
        imageBytes,
        const FileOptions(contentType: 'image/jpeg', upsert: true),
      );
      final url = storage.getPublicUrl(path);
      debugPrint('[Supabase] 이미지 업로드 완료: $url');
      return url;
    } catch (e) {
      debugPrint('[Supabase] 이미지 업로드 오류: $e');
      rethrow;
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // 제품 목록 로드
  // ────────────────────────────────────────────────────────────────────────────

  /// 현재 사용자의 모든 제품을 Supabase에서 불러옵니다.
  static Future<List<ConsumableItem>> loadItems() async {
    try {
      return await loadItemsForScope(const ItemScope.personal());
    } catch (e) {
      debugPrint('[Supabase] loadItems 오류: $e');
      return [];
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // 제품 저장 (신규 등록 & 수정)
  // ────────────────────────────────────────────────────────────────────────────

  static Future<List<ConsumableItem>> loadItemsForScope(ItemScope scope) async {
    final rows = await _itemDatabaseGateway.loadItems(
      userId: scope.isPersonal ? currentUserId : null,
      groupId: scope.isGroup ? scope.id : null,
    );
    return rows.map(_itemFromJoinedRow).toList(growable: false);
  }

  static ConsumableItem _itemFromJoinedRow(Map<String, dynamic> row) {
    final categoryName =
        (row['categories'] as Map<String, dynamic>?)?['name'] as String? ??
        '기타';
    final purchases =
        (row['purchases'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
        <Map<String, dynamic>>[];
    final aiList =
        (row['ai_predictions'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        <Map<String, dynamic>>[];
    final ai = aiList.isNotEmpty ? aiList.last : null;

    // Phase 1 회귀 예측: 구매 이력이 없을 때 daily_usage 반영
    final purchaseDates = purchases
        .map((p) => DateTime.tryParse(p['purchase_date'] as String? ?? ''))
        .whereType<DateTime>()
        .toList();

    final dailyUsage = DailyUsageService.instance.getInternalValue(
      categoryName,
    );
    final defaultDays = categoryDefaultDays[categoryName] ?? 30;

    final localPrediction = predictCycle(
      purchaseDates: purchaseDates,
      categoryDefaultDays: defaultDays,
      categoryName: categoryName,
      dailyUsage: dailyUsage,
      personalService: PersonalRegressionService.instance,
    );

    // Supabase AI 예측이 없거나 Phase 1인 경우 로컬 예측으로 대체
    final Map<String, dynamic> effectiveAi =
        ai ??
        {
          'predicted_cycle_days': localPrediction.predictedCycleDays,
          'confidence': localPrediction.confidence,
        };

    return ConsumableItem.fromSupabase(
      data: row,
      categoryName: categoryName,
      purchases: purchases,
      aiPrediction: effectiveAi,
    );
  }

  /// ConsumableItem을 Supabase에 upsert합니다.
  ///
  /// - product_items 테이블에 upsert (id 기준)
  /// - id가 없는 신규 PurchaseRecord만 purchases 테이블에 insert
  static Future<void> saveItem(
    ConsumableItem item, {
    ItemScope scope = const ItemScope.personal(),
  }) async {
    final uid = currentUserId;
    final userId = scope.isPersonal ? uid : null;
    final groupId = scope.isGroup ? scope.id : null;

    try {
      final categoryId = await _itemDatabaseGateway.ensureCategory(
        name: item.category,
        userId: userId,
        groupId: groupId,
      );

      await _itemDatabaseGateway.upsertItem({
        'id': item.id,
        'user_id': userId,
        'group_id': groupId,
        'registered_by': uid,
        'category_id': categoryId,
        'name': item.name,
        'brand': item.brand,
        'image_url': item.imageUrl,
        'replacement_cycle_days': item.cycleDays,
      });

      // id가 null인 신규 구매 이력만 삽입
      for (final record in item.purchaseHistory) {
        if (record.id == null) {
          await _itemDatabaseGateway.insertPurchase({
            'product_item_id': item.id,
            'purchased_by': uid,
            'purchase_date': record.date.toIso8601String().substring(0, 10),
            'price': record.price,
            'store_name': record.store,
            'quantity': 1,
          });
        }
      }

      debugPrint('[Supabase] saveItem 완료: ${item.name} (${item.id})');
    } catch (e) {
      debugPrint('[Supabase] saveItem 오류: $e');
      rethrow;
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // 제품 삭제
  // ────────────────────────────────────────────────────────────────────────────

  /// product_items에서 삭제합니다.
  /// purchases는 DB의 ON DELETE CASCADE 설정에 따라 자동 삭제됩니다.
  static Future<void> deleteItem(String itemId) async {
    try {
      // purchases는 FK CASCADE로 자동 삭제. 없다면 아래 줄 먼저 실행:
      // await _db.from('purchases').delete().eq('product_item_id', itemId);
      await _db.from('product_items').delete().eq('id', itemId);
      debugPrint('[Supabase] deleteItem 완료: $itemId');
    } catch (e) {
      debugPrint('[Supabase] deleteItem 오류: $e');
      rethrow;
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // 구매 이력 삭제
  // ────────────────────────────────────────────────────────────────────────────

  /// 지정한 purchases.id 목록을 DB에서 삭제합니다.
  static Future<void> deletePurchases(Set<String> ids) async {
    if (ids.isEmpty) return;
    try {
      await _db.from('purchases').delete().inFilter('id', ids.toList());
      debugPrint('[Supabase] deletePurchases 완료: ${ids.length}건');
    } catch (e) {
      debugPrint('[Supabase] deletePurchases 오류: $e');
      rethrow;
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // UUID 생성 (외부 패키지 없이 dart:math 사용)
  // ────────────────────────────────────────────────────────────────────────────

  /// RFC 4122 UUID v4를 생성합니다.
  static String generateUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant bits
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  static String _generateInviteCode() {
    final random = Random.secure();
    final buffer = StringBuffer('BUY-');
    for (var i = 0; i < 6; i++) {
      buffer.write(
        _groupInviteCodeAlphabet[random.nextInt(
          _groupInviteCodeAlphabet.length,
        )],
      );
    }
    return buffer.toString();
  }

  static String _iconNameForCategory(String name) {
    return switch (name) {
      '욕실/위생' => 'bathroom',
      '주방/세제' => 'kitchen',
      '세탁/청소' => 'laundry',
      '헤어/바디' => 'shower',
      '가전/필터' => 'air',
      _ => 'category',
    };
  }
}

abstract class GroupDatabaseGateway {
  Future<Map<String, dynamic>?> loadDefaultGroup(String userId);

  Future<List<Map<String, dynamic>>> loadGroupsForUser(String userId);

  Future<Map<String, dynamic>> createGroupWithOwner({
    required String name,
    required String inviteCode,
  });

  Future<Map<String, dynamic>> renameGroup({
    required String groupId,
    required String name,
  });

  Future<List<Map<String, dynamic>>> loadGroupMembers({
    required String groupId,
  });

  Future<void> leaveGroup({
    required String groupId,
    required String? newOwnerUserId,
  });
}

class SupabaseGroupDatabaseGateway implements GroupDatabaseGateway {
  SupabaseGroupDatabaseGateway(this._client);

  static const _memberProjection = '''
          id,
          user_id,
          role,
          joined_at,
          users (
            display_name,
            email
          )
      ''';

  static const _groupProjection =
      '''
        id,
        name,
        invite_code,
        created_by,
        created_at,
        group_members (
          $_memberProjection
        )
      ''';

  final SupabaseClient _client;

  @override
  Future<Map<String, dynamic>?> loadDefaultGroup(String userId) async {
    final userRow = await _client
        .from('users')
        .select('default_group_id')
        .eq('id', userId)
        .maybeSingle();

    final groupId = userRow?['default_group_id'] as String?;
    if (groupId == null || groupId.isEmpty) {
      return null;
    }

    final groupRow = await _client
        .from('groups')
        .select(_groupProjection)
        .eq('id', groupId)
        .single();
    return Map<String, dynamic>.from(groupRow);
  }

  @override
  Future<List<Map<String, dynamic>>> loadGroupsForUser(String userId) async {
    final rows = await _client
        .from('group_members')
        .select('groups ($_groupProjection)')
        .eq('user_id', userId)
        .order('joined_at', ascending: true);
    return SupabaseService.normalizePostgrestRows(rows)
        .map((row) => row['groups'])
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList(growable: false);
  }

  @override
  Future<Map<String, dynamic>> createGroupWithOwner({
    required String name,
    required String inviteCode,
  }) async {
    final row = await _client
        .rpc(
          'create_group_with_owner',
          params: {'group_name': name, 'group_invite_code': inviteCode},
        )
        .select(_groupProjection)
        .single();
    return Map<String, dynamic>.from(row);
  }

  @override
  Future<Map<String, dynamic>> renameGroup({
    required String groupId,
    required String name,
  }) async {
    final row = await _client
        .from('groups')
        .update({'name': name})
        .eq('id', groupId)
        .select(_groupProjection)
        .single();
    return Map<String, dynamic>.from(row);
  }

  @override
  Future<List<Map<String, dynamic>>> loadGroupMembers({
    required String groupId,
  }) async {
    final rows = await _client
        .from('group_members')
        .select(_memberProjection)
        .eq('group_id', groupId)
        .order('joined_at', ascending: true);
    return SupabaseService.normalizePostgrestRows(rows);
  }

  @override
  Future<void> leaveGroup({
    required String groupId,
    required String? newOwnerUserId,
  }) async {
    await _client.rpc(
      'leave_group',
      params: {'target_group_id': groupId, 'new_owner_user_id': newOwnerUserId},
    );
  }
}

abstract class ItemDatabaseGateway {
  Future<List<Map<String, dynamic>>> loadItems({
    required String? userId,
    required String? groupId,
  });

  Future<String> ensureCategory({
    required String name,
    required String? userId,
    required String? groupId,
  });

  Future<void> upsertItem(Map<String, dynamic> payload);

  Future<void> insertPurchase(Map<String, dynamic> payload);
}

class SupabaseItemDatabaseGateway implements ItemDatabaseGateway {
  const SupabaseItemDatabaseGateway(this._client);

  final SupabaseClient _client;

  static const _itemProjection = '''
          id,
          user_id,
          group_id,
          registered_by,
          registered_by_user:users!product_items_registered_by_fkey (
            id,
            display_name,
            email
          ),
          name,
          brand,
          image_url,
          replacement_cycle_days,
          created_at,
          categories ( id, name ),
          purchases ( id, purchase_date, price, store_name ),
          ai_predictions ( predicted_cycle_days, confidence )
        ''';

  @override
  Future<List<Map<String, dynamic>>> loadItems({
    required String? userId,
    required String? groupId,
  }) async {
    dynamic query = _client.from('product_items').select(_itemProjection);
    if (groupId != null) {
      query = query.eq('group_id', groupId);
    } else {
      query = query.eq('user_id', userId!);
    }
    final rows = await query.order('created_at', ascending: false);
    return SupabaseService.normalizePostgrestRows(rows);
  }

  @override
  Future<String> ensureCategory({
    required String name,
    required String? userId,
    required String? groupId,
  }) async {
    dynamic query = _client.from('categories').select('id').eq('name', name);
    if (groupId != null) {
      query = query.eq('group_id', groupId);
    } else {
      query = query.eq('user_id', userId!);
    }

    final existing = await query.maybeSingle();
    if (existing != null) {
      return existing['id'] as String;
    }

    final created = await _client
        .from('categories')
        .insert({
          'user_id': userId,
          'group_id': groupId,
          'name': name,
          'icon': SupabaseService._iconNameForCategory(name),
          'color': '#4F7FFF',
          'sort_order': 0,
        })
        .select('id')
        .single();

    return created['id'] as String;
  }

  @override
  Future<void> upsertItem(Map<String, dynamic> payload) async {
    await _client.from('product_items').upsert(payload);
  }

  @override
  Future<void> insertPurchase(Map<String, dynamic> payload) async {
    await _client.from('purchases').insert(payload);
  }
}

abstract class ProductImageStorageGateway {
  factory ProductImageStorageGateway.fromClient(
    SupabaseClient client,
    String bucket,
  ) = _SupabaseProductImageStorageGateway;

  Future<void> uploadBinary(
    String path,
    Uint8List imageBytes,
    FileOptions fileOptions,
  );

  String getPublicUrl(String path);
}

class _SupabaseProductImageStorageGateway
    implements ProductImageStorageGateway {
  _SupabaseProductImageStorageGateway(this._client, this._bucket);

  final SupabaseClient _client;
  final String _bucket;

  @override
  Future<void> uploadBinary(
    String path,
    Uint8List imageBytes,
    FileOptions fileOptions,
  ) async {
    await _client.storage
        .from(_bucket)
        .uploadBinary(path, imageBytes, fileOptions: fileOptions);
  }

  @override
  String getPublicUrl(String path) =>
      _client.storage.from(_bucket).getPublicUrl(path);
}
