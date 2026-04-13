import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/item.dart';

/// Supabase 연동 서비스
///
/// 프로젝트: fervijwxdgkwjtcpzskx
/// 테이블 구조:
///   product_items  ← 제품 (ConsumableItem)
///   purchases      ← 구매 이력 (PurchaseRecord)
///   categories     ← 카테고리 (이름 → UUID 캐시)
///   ai_predictions ← AI 예측 (aiPredictedDays, aiConfidence)
///
/// 인증: 익명 로그인(signInAnonymously) 사용
/// RLS: user_id = auth.uid() 정책이 각 테이블에 설정되어 있어야 합니다.
class SupabaseService {
  static const _supabaseUrl = 'https://fervijwxdgkwjtcpzskx.supabase.co';
  static const _anonKey =
      'sb_publishable_FO7WmA_Pu4RsGgsfRJzssQ_f0orCu7w';

  static SupabaseClient get _db => Supabase.instance.client;

  /// 카테고리 이름 → UUID 로컬 캐시 (앱 세션 동안 유지)
  static final Map<String, String> _categoryCache = {};

  // ────────────────────────────────────────────────────────────────────────────
  // 초기화 & 인증
  // ────────────────────────────────────────────────────────────────────────────

  /// 개발용 임시 사용자 ID (RLS 비활성 환경에서 사용)
  ///
  /// 실제 인증 연동 시 _db.auth.currentUser!.id 로 교체합니다.
  static const _devUserId = '08cccfe3-766f-43bd-b06c-8d909e0f9fe8';

  /// Supabase 초기화 (인증 불필요 — RLS 비활성 환경)
  static Future<void> initialize() async {
    await Supabase.initialize(url: _supabaseUrl, anonKey: _anonKey);
    debugPrint('[Supabase] 초기화 완료 (인증 없음, RLS 비활성 모드)');
  }

  /// 현재 사용자 ID
  static String get currentUserId => _devUserId;

  // ────────────────────────────────────────────────────────────────────────────
  // 제품 목록 로드
  // ────────────────────────────────────────────────────────────────────────────

  /// 현재 사용자의 모든 제품을 Supabase에서 불러옵니다.
  static Future<List<ConsumableItem>> loadItems() async {
    final uid = currentUserId;
    try {
      final rows = await _db.from('product_items').select('''
          id,
          name,
          brand,
          image_url,
          replacement_cycle_days,
          created_at,
          categories ( id, name ),
          purchases ( id, purchase_date, price, store_name ),
          ai_predictions ( predicted_cycle_days, confidence )
        ''').eq('user_id', uid).order('created_at', ascending: false);

      return rows.map<ConsumableItem>((row) {
        final categoryName =
            (row['categories'] as Map<String, dynamic>?)?['name']
                    as String? ??
                '기타';

        final purchases =
            (row['purchases'] as List<dynamic>?)
                    ?.cast<Map<String, dynamic>>() ??
                [];

        final aiList =
            (row['ai_predictions'] as List<dynamic>?)
                    ?.cast<Map<String, dynamic>>() ??
                [];
        // 가장 최근 AI 예측 1건 사용
        final ai = aiList.isNotEmpty ? aiList.last : null;

        return ConsumableItem.fromSupabase(
          data: row,
          categoryName: categoryName,
          purchases: purchases,
          aiPrediction: ai,
        );
      }).toList();
    } catch (e) {
      debugPrint('[Supabase] loadItems 오류: $e');
      return [];
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // 제품 저장 (신규 등록 & 수정)
  // ────────────────────────────────────────────────────────────────────────────

  /// ConsumableItem을 Supabase에 upsert합니다.
  ///
  /// - product_items 테이블에 upsert (id 기준)
  /// - id가 없는 신규 PurchaseRecord만 purchases 테이블에 insert
  static Future<void> saveItem(ConsumableItem item) async {
    final uid = currentUserId;
    try {
      final categoryId = await _ensureCategory(item.category);

      await _db.from('product_items').upsert({
        'id': item.id,
        'user_id': uid,
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
          await _db.from('purchases').insert({
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
  // 카테고리 조회 또는 생성
  // ────────────────────────────────────────────────────────────────────────────

  /// 카테고리 이름으로 UUID를 반환합니다. 없으면 새로 생성합니다.
  static Future<String> _ensureCategory(String name) async {
    if (_categoryCache.containsKey(name)) return _categoryCache[name]!;

    final uid = currentUserId;

    // 기존 카테고리 조회
    final existing = await _db
        .from('categories')
        .select('id')
        .eq('user_id', uid)
        .eq('name', name)
        .maybeSingle();

    if (existing != null) {
      _categoryCache[name] = existing['id'] as String;
      return existing['id'] as String;
    }

    // 없으면 생성
    final created = await _db
        .from('categories')
        .insert({
          'user_id': uid,
          'name': name,
          'icon': _iconNameForCategory(name),
          'color': '#4F7FFF',
          'sort_order': 0,
        })
        .select('id')
        .single();

    _categoryCache[name] = created['id'] as String;
    return created['id'] as String;
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
    final hex =
        bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
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
