import 'package:flutter/foundation.dart';
import '../models/item.dart';

/// Firebase 연동 준비 서비스 (Stub)
///
/// 실제 연동을 위해 필요한 pubspec.yaml 패키지:
///   firebase_core: ^3.x.x
///   firebase_storage: ^12.x.x   ← uploadItemImage 사용 시
///   cloud_firestore: ^5.x.x     ← saveItem / addPurchaseRecord 사용 시
///
/// 연동 절차:
///   1. 위 패키지를 pubspec.yaml에 추가 후 `flutter pub get`
///   2. FlutterFire CLI로 google-services.json / GoogleService-Info.plist 설치
///   3. main()에서 `await Firebase.initializeApp()` 호출
///   4. 각 메서드의 TODO 블록을 언주석 처리하고 stub 코드 삭제
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  // ---------------------------------------------------------------------------
  // Firebase Storage: 제품 이미지 업로드
  // ---------------------------------------------------------------------------

  /// 제품 이미지를 Firebase Storage에 업로드하고 다운로드 URL을 반환합니다.
  ///
  /// [imageBytes] 업로드할 이미지의 바이트 데이터 (image_picker로 획득)
  /// [itemId]     이미지를 연결할 제품의 고유 ID
  /// 반환값: 업로드 성공 시 다운로드 URL, 실패 시 null
  Future<String?> uploadItemImage({
    required Uint8List imageBytes,
    required String itemId,
  }) async {
    // TODO: Firebase Storage 연결 시 아래 코드 활성화
    //
    // import 'package:firebase_storage/firebase_storage.dart';
    //
    // try {
    //   final ref = FirebaseStorage.instance
    //       .ref()
    //       .child('item_images')
    //       .child('$itemId.jpg');
    //   final metadata = SettableMetadata(contentType: 'image/jpeg');
    //   final snapshot = await ref.putData(imageBytes, metadata);
    //   return await snapshot.ref.getDownloadURL();
    // } catch (e) {
    //   debugPrint('[FirebaseService] uploadItemImage error: $e');
    //   return null;
    // }

    // Stub: 업로드 시뮬레이션 (500ms 지연 후 플레이스홀더 URL 반환)
    await Future.delayed(const Duration(milliseconds: 500));
    debugPrint('[FirebaseService][stub] uploadItemImage: itemId=$itemId');
    return 'https://placeholder.local/item_images/$itemId.jpg';
  }

  // ---------------------------------------------------------------------------
  // Firestore: 제품 저장
  // ---------------------------------------------------------------------------

  /// ConsumableItem을 Firestore에 저장합니다.
  ///
  /// 신규 등록과 정보 수정 모두 이 메서드를 사용합니다 (upsert).
  Future<void> saveItem(ConsumableItem item) async {
    // TODO: Firestore 연결 시 아래 코드 활성화
    //
    // import 'package:cloud_firestore/cloud_firestore.dart';
    //
    // try {
    //   await FirebaseFirestore.instance
    //       .collection('items')
    //       .doc(item.id)
    //       .set({
    //     'id': item.id,
    //     'name': item.name,
    //     'brand': item.brand,
    //     'category': item.category,
    //     'cycleDays': item.cycleDays,
    //     'imageUrl': item.imageUrl,
    //     'purchaseHistory': item.purchaseHistory
    //         .map((r) => {
    //               'date': r.date.toIso8601String(),
    //               'price': r.price,
    //               'store': r.store,
    //             })
    //         .toList(),
    //     'createdAt': FieldValue.serverTimestamp(),
    //   });
    // } catch (e) {
    //   debugPrint('[FirebaseService] saveItem error: $e');
    //   rethrow;
    // }

    // Stub: 저장 시뮬레이션 (800ms 지연)
    await Future.delayed(const Duration(milliseconds: 800));
    debugPrint('[FirebaseService][stub] saveItem: ${item.name} (id: ${item.id})');
  }

  // ---------------------------------------------------------------------------
  // Firestore: 구매 이력 추가
  // ---------------------------------------------------------------------------

  /// 기존 제품에 구매 이력 1건을 추가합니다.
  Future<void> addPurchaseRecord({
    required String itemId,
    required PurchaseRecord record,
  }) async {
    // TODO: Firestore 연결 시 아래 코드 활성화
    //
    // import 'package:cloud_firestore/cloud_firestore.dart';
    //
    // try {
    //   await FirebaseFirestore.instance
    //       .collection('items')
    //       .doc(itemId)
    //       .collection('purchaseHistory')
    //       .add({
    //     'date': record.date.toIso8601String(),
    //     'price': record.price,
    //     'store': record.store,
    //   });
    // } catch (e) {
    //   debugPrint('[FirebaseService] addPurchaseRecord error: $e');
    //   rethrow;
    // }

    // Stub: 저장 시뮬레이션 (300ms 지연)
    await Future.delayed(const Duration(milliseconds: 300));
    debugPrint(
      '[FirebaseService][stub] addPurchaseRecord: '
      'itemId=$itemId, date=${record.date}, price=${record.price}',
    );
  }
}
