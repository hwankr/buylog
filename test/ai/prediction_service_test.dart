import 'package:test/test.dart';
import 'package:buylog/services/ai/prediction_service.dart';
import 'package:buylog/services/ai/regression_coefficients.dart';

void main() {
  group('Prediction Logic Tests', () {
    // ── Phase 1 하위 호환 경로 (categoryName 없음) ────────────────
    test('Phase 1 - categoryName 없음 → categoryDefaultDays 반환 (하위 호환)', () {
      final result = predictCycle(purchaseDates: [], categoryDefaultDays: 30);
      expect(result.predictedCycleDays, 30);
      expect(result.phase, PredictionPhase.phase1);
      expect(result.confidence, kConfidenceBase);
    });

    // ── Phase 1 회귀 예측 경로 (categoryName 있음) ────────────────
    test('Phase 1 - categoryName 제공 → 회귀 예측 사용 (categoryDefaultDays 무시)', () {
      // categoryDefaultDays=9999 를 의도적으로 전달해 회귀 경로를 통과했는지 검증
      final result = predictCycle(
        purchaseDates: [],
        categoryDefaultDays: 9999,
        categoryName: '가전/필터',
      );
      expect(result.phase, PredictionPhase.phase1);
      expect(result.confidence, kConfidenceBase);
      // 회귀 예측값은 [45, 540] (filter baseCycle=180 의 clamp 범위) 이내
      expect(result.predictedCycleDays, inInclusiveRange(45, 540));
      // categoryDefaultDays=9999 가 그대로 반환되지 않았으면 회귀 경로 확인됨
      expect(result.predictedCycleDays, isNot(9999));
    });

    test('Phase 1 - 욕실/위생 → 90일 안팎 예측 (consumable 그룹, clamp [22, 270])', () {
      final result = predictCycle(
        purchaseDates: [],
        categoryDefaultDays: 30, // 구 룰 기반값(30)과 달라야 함
        categoryName: '욕실/위생',
      );
      expect(result.phase, PredictionPhase.phase1);
      // consumable baseCycle=90 → clamp [22, 270], 기준 사용량 기준 ≈ 88~92일
      expect(result.predictedCycleDays, inInclusiveRange(22, 270));
      expect(result.predictedCycleDays, isNot(30)); // 구 룰 기반값과 달라야 함
    });

    test('Phase 1 - unknown 카테고리 → average 계수 fallback', () {
      // ConsumableCycleCoefficients.predictFromCategory 와 동일한 값을 반환해야 함
      final expected = ConsumableCycleCoefficients.predictFromCategory(
        categoryName: '없는카테고리',
      );
      final result = predictCycle(
        purchaseDates: [],
        categoryDefaultDays: 30,
        categoryName: '없는카테고리',
      );
      expect(result.predictedCycleDays, expected);
      expect(result.phase, PredictionPhase.phase1);
    });

    test('Phase 1 - dailyUsage 제공 시 사용량 보정 적용', () {
      // 과사용(dailyUsage 높음) → 주기 짧아짐
      final normal = predictCycle(
        purchaseDates: [],
        categoryDefaultDays: 180,
        categoryName: '가전/필터',
      );
      final heavy = predictCycle(
        purchaseDates: [],
        categoryDefaultDays: 180,
        categoryName: '가전/필터',
        dailyUsage: 6.0,
      );
      expect(heavy.predictedCycleDays, lessThan(normal.predictedCycleDays));
    });

    // ── Phase 2/3 — categoryName 이 있어도 영향 없음 ──────────────
    test('Phase 2 - categoryName 있어도 WMA 로직 그대로', () {
      final withCat = predictCycle(
        purchaseDates: [
          DateTime(2024, 1, 1),
          DateTime(2024, 2, 5), // 간격 35일
          DateTime(2024, 3, 10), // 간격 34일 (윤년)
        ],
        categoryDefaultDays: 30,
        categoryName: '가전/필터',
      );
      final withoutCat = predictCycle(
        purchaseDates: [
          DateTime(2024, 1, 1),
          DateTime(2024, 2, 5),
          DateTime(2024, 3, 10),
        ],
        categoryDefaultDays: 30,
      );
      // categoryName 유무에 관계없이 Phase 2 결과 동일
      expect(withCat.predictedCycleDays, withoutCat.predictedCycleDays);
      expect(withCat.phase, PredictionPhase.phase2);
    });

    test('Phase 2 - 구매 3회 시 WMA 확인', () {
      final result = predictCycle(
        purchaseDates: [
          DateTime(2024, 1, 1),
          DateTime(2024, 2, 5), // 간격 35일
          DateTime(2024, 3, 10), // 간격 34일 (윤년)
        ],
        categoryDefaultDays: 30,
      );
      // ((1*35) + (2*34)) / 3 = 34.33 -> 34
      expect(result.predictedCycleDays, 34);
      expect(result.phase, PredictionPhase.phase2);
    });
  });

  group('calcDday Tests', () {
    test('구매 기록이 없을 때 - 등록일 기준 D-day 계산', () {
      final now = DateTime.now();
      // 등록일이 10일 전이고 주기가 30일이면, 남은 D-day는 20일
      final registeredAt = now.subtract(Duration(days: 10));

      final dDay = calcDday(
        purchaseDates: [],
        predictedCycleDays: 30,
        registeredAt: registeredAt,
      );

      expect(dDay, 20);
    });

    test('구매 기록이 있을 때 - 최근 구매일 기준 D-day 계산', () {
      final now = DateTime.now();
      // 마지막 구매가 5일 전이고 주기가 14일이면, 남은 D-day는 9일
      final lastPurchase = now.subtract(Duration(days: 5));

      final dDay = calcDday(
        purchaseDates: [now.subtract(Duration(days: 20)), lastPurchase],
        predictedCycleDays: 14,
        registeredAt: now.subtract(Duration(days: 30)),
      );

      expect(dDay, 9);
    });

    test('교체 주기가 지났을 때 - 음수 값 반환 확인', () {
      final now = DateTime.now();
      // 마지막 구매가 20일 전인데 주기가 15일이면, D-5일
      final lastPurchase = now.subtract(Duration(days: 20));

      final dDay = calcDday(
        purchaseDates: [lastPurchase],
        predictedCycleDays: 15,
        registeredAt: now.subtract(Duration(days: 40)),
      );

      expect(dDay, -5);
    });
  });

  // calcRemainingPercent
  test('calcRemainingPercent - 오늘 구매', () {
    final result = calcRemainingPercent(
      purchaseDates: [DateTime.now()],
      predictedCycleDays: 30,
      registeredAt: DateTime.now(),
    );
    expect(result, 0.0); // 기대값: 0.0
  });

  test('calcRemainingPercent - 절반 경과', () {
    final result = calcRemainingPercent(
      purchaseDates: [DateTime.now().subtract(Duration(days: 15))],
      predictedCycleDays: 30,
      registeredAt: DateTime.now(),
    );
    expect(result, 0.5); // 기대값: 0.5
  });
}
