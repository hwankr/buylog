import 'package:test/test.dart';
import 'package:buylog/services/ai/prediction_service.dart';

void main() {
  // Phase 1: 데이터가 부족한 경우 (구매 0회 또는 1회)
  test('Phase 1 - 구매 기록이 없을 때 기본값 반환 확인', () {
    final result = predictCycle(
      purchaseDates: [],
      categoryDefaultDays: 30,
    );

    expect(result.predictedCycleDays, 30);
    expect(result.confidence, 0.1); // kConfidenceBase
    expect(result.phase, PredictionPhase.phase1);
  });

  // Phase 2: 구매 기록이 3회인 경우 (간격 2개)
  test('Phase 2 - 구매 3회 시 WMA 및 신뢰도 확인', () {
    final result = predictCycle(
      purchaseDates: [
        DateTime(2024, 1, 1),
        DateTime(2024, 2, 5),   // 간격 1: 35일
        DateTime(2024, 3, 10),  // 간격 2: 34일 (2024년 윤년 영향)
      ],
      categoryDefaultDays: 30,
    );

    // 계산 근거: ((1 * 35) + (2 * 34)) / 3 = 34.33 -> round() 하면 34
    expect(result.predictedCycleDays, 34);
    
    // 계산 근거: kConfidenceBase(0.1) + (간격 수 2 * kConfidenceStep 0.1) = 0.3
    expect(result.confidence, closeTo(0.3, 0.001)); 
    expect(result.phase, PredictionPhase.phase2);
  });

  // Phase 2: 구매 기록이 5회인 경우 (경계값 테스트)
  test('Phase 2 - 구매 5회 시 신뢰도 점진적 상승 확인', () {
    final result = predictCycle(
      purchaseDates: [
        DateTime(2024, 1, 1),
        DateTime(2024, 1, 11), // 10일
        DateTime(2024, 1, 21), // 10일
        DateTime(2024, 1, 31), // 10일
        DateTime(2024, 2, 10), // 10일
      ],
      categoryDefaultDays: 30,
    );

    expect(result.predictedCycleDays, 10);
    // 간격이 4개이므로: 0.1 + (4 * 0.1) = 0.5
    expect(result.confidence, closeTo(0.5, 0.001));
    expect(result.phase, PredictionPhase.phase2);
  });
}