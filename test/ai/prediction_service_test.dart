import 'package:test/test.dart';
import 'package:buylog/services/ai/prediction_service.dart';

void main() {
  group('Prediction Logic Tests', () {
    test('Phase 1 - 데이터 없을 때 기본값 확인', () {
      final result = predictCycle(
        purchaseDates: [],
        categoryDefaultDays: 30,
      );
      expect(result.predictedCycleDays, 30);
      expect(result.phase, PredictionPhase.phase1);
    });

    test('Phase 2 - 구매 3회 시 WMA 확인', () {
      final result = predictCycle(
        purchaseDates: [
          DateTime(2024, 1, 1),
          DateTime(2024, 2, 5),   // 간격 35일
          DateTime(2024, 3, 10),  // 간격 34일 (윤년)
        ],
        categoryDefaultDays: 30,
      );
      // ((1*35) + (2*34)) / 3 = 34.33 -> 34
      expect(result.predictedCycleDays, 34);
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
        purchaseDates: [
          now.subtract(Duration(days: 20)),
          lastPurchase,
        ],
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
}