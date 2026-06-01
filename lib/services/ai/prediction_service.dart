import 'personal_regression_service.dart';
import 'regression_coefficients.dart';

enum PredictionPhase { phase1, phase2, phase3, phase4 }

const double kPriorWeight = 3.0;
const int kPhase3Threshold = 6; // 이 값 이상이면 Phase3
const double kConfidenceBase = 0.1; // 신뢰도 시작값
const double kConfidenceStep = 0.1; // Phase2 신뢰도 증가량
const double kConfidencePhase3Base = 0.5; // Phase3 신뢰도 시작값
const double kConfidencePhase3Step = 0.05; // Phase3 신뢰도 증가량
const int kConfidencePhase3Offset = 5; // Phase3 신뢰도 계산 기준점

class PredictionResult {
  final int predictedCycleDays;
  final double confidence;
  final PredictionPhase phase;

  PredictionResult({
    required this.predictedCycleDays,
    required this.confidence,
    required this.phase,
  });
}

List<int> calcIntervals(List<DateTime> purchaseDates) {
  if (purchaseDates.length < 2) return [];

  final sorted = [...purchaseDates]..sort((a, b) => a.compareTo(b));

  List<int> intervals = [];
  for (int i = 1; i < sorted.length; i++) {
    final diff = sorted[i].difference(sorted[i - 1]).inDays;
    intervals.add(diff);
  }
  return intervals;
}

double calcWMA(List<int> intervals) {
  if (intervals.isEmpty) return 0;

  double weightSum = 0;
  double valueSum = 0;

  for (int i = 0; i < intervals.length; i++) {
    final weight = (i + 1).toDouble();
    valueSum += weight * intervals[i];
    weightSum += weight;
  }
  return valueSum / weightSum;
}

/// 소모품 교체 주기 예측
///
/// **Phase 1** (구매 이력 없음)
///   회귀 모델 [ConsumableCycleCoefficients]로 예측.
///   [categoryName]이 제공되면 대분류 β 계수 사용, 없으면 [categoryDefaultDays]로 fallback.
///
/// **Phase 2** (구매 이력 1~5회)
///   가중이동평균(WMA) — 최근 구매일수록 높은 가중치.
///
/// **Phase 3** (구매 이력 6회 이상)
///   Bayesian 혼합: prior=[categoryDefaultDays], likelihood=관측 평균.
///
/// [categoryDefaultDays]  : Phase 3 Bayesian prior + Phase 1 fallback (categoryName 없을 때)
/// [categoryName]         : UI 카테고리명 → Phase 1 회귀 예측에 사용 (optional)
/// [dailyUsage]           : 하루 사용량 → Phase 1 회귀 보정 (optional, null이면 기준값 사용)
/// [personalService]      : Phase 4 개인화 서비스 (optional). 구매 15회 이상 시 개인 β 사용.
PredictionResult predictCycle({
  required List<DateTime> purchaseDates,
  required int categoryDefaultDays,
  String? categoryName,
  double? dailyUsage,
  PersonalRegressionService? personalService,
}) {
  final intervals = calcIntervals(purchaseDates);
  final count = intervals.length;

  // ── Phase 1: 구매 이력 없음 → 회귀 예측 ─────────────────────────
  if (count == 0) {
    final int predicted;

    if (categoryName != null) {
      // 대분류 β 계수 또는 average fallback으로 회귀 예측
      predicted = ConsumableCycleCoefficients.predictFromCategory(
        categoryName: categoryName,
        dailyUsage: dailyUsage,
        // prevInterval 미제공 → 대분류 기준 주기 사용 (내부 default)
      );
    } else {
      // categoryName 없음 → 기존 룰 기반값 유지 (하위 호환)
      predicted = categoryDefaultDays;
    }

    return PredictionResult(
      predictedCycleDays: predicted,
      confidence: kConfidenceBase,
      phase: PredictionPhase.phase1,
    );
  }

  // ── Phase 2: 구매 이력 1~5회 → WMA ──────────────────────────────
  if (count < kPhase3Threshold) {
    final wma = calcWMA(intervals);
    return PredictionResult(
      predictedCycleDays: wma.round(),
      confidence: kConfidenceBase + count * kConfidenceStep,
      phase: PredictionPhase.phase2,
    );
  }

  // ── Phase 4: 구매 이력 15회 이상 → 개인화 다중회귀 ──────────────
  if (purchaseDates.length >= kPhase4Threshold && personalService != null) {
    final group =
        ConsumableCycleCoefficients.categoryToGroup[categoryName] ?? 'average';
    final baseCyc = ConsumableCycleCoefficients.baseCycleDays[group]!
        .toDouble();
    final du =
        dailyUsage ?? (ConsumableCycleCoefficients.baseUsageRef[group] ?? 1.0);
    final prevIntervalVal = intervals.isEmpty
        ? baseCyc
        : intervals.last.toDouble();
    final isSummer = ConsumableCycleCoefficients.isCurrentSummer;

    final personal = personalService.predict(
      group: group,
      dailyUsage: du,
      baseCycle: baseCyc,
      prevInterval: prevIntervalVal,
      isSummer: isSummer,
    );
    if (personal != null) {
      final confidence =
          (kConfidencePhase3Base +
                  (count - kConfidencePhase3Offset) * kConfidencePhase3Step)
              .clamp(0.0, 1.0);
      return PredictionResult(
        predictedCycleDays: personal.round(),
        confidence: confidence,
        phase: PredictionPhase.phase4,
      );
    }
  }

  // ── Phase 3: 구매 이력 6회 이상 → Bayesian 혼합 ─────────────────
  final observedAvg = intervals.reduce((a, b) => a + b) / intervals.length;
  final newEstimate =
      (kPriorWeight * categoryDefaultDays + count * observedAvg) /
      (kPriorWeight + count);
  final confidence =
      (kConfidencePhase3Base +
              (count - kConfidencePhase3Offset) * kConfidencePhase3Step)
          .clamp(0.0, 1.0);

  return PredictionResult(
    predictedCycleDays: newEstimate.round(),
    confidence: confidence,
    phase: PredictionPhase.phase3,
  );
}

int calcDday({
  required List<DateTime> purchaseDates,
  required int predictedCycleDays,
  required DateTime registeredAt,
}) {
  final now = DateTime.now();
  final baseDate = purchaseDates.isEmpty
      ? registeredAt
      : purchaseDates.reduce((a, b) => a.isAfter(b) ? a : b);
  final difference = now.difference(baseDate).inDays;

  return predictedCycleDays - difference;
}

double calcRemainingPercent({
  required List<DateTime> purchaseDates,
  required int predictedCycleDays,
  required DateTime registeredAt,
}) {
  if (predictedCycleDays <= 0) return 0.0;

  final dDay = calcDday(
    purchaseDates: purchaseDates,
    predictedCycleDays: predictedCycleDays,
    registeredAt: registeredAt,
  );
  final elapsed = predictedCycleDays - dDay;

  if (elapsed <= 0) return 0.0;
  if (elapsed >= predictedCycleDays) return 1.0;

  return elapsed / predictedCycleDays;
}

DateTime calculateReplacementDate({
  required List<DateTime> purchaseDates,
  required int predictedCycleDays,
  required DateTime registeredAt,
}) {
  if (purchaseDates.isEmpty) {
    return registeredAt.add(Duration(days: predictedCycleDays));
  }

  final baseDate = purchaseDates.isEmpty
      ? registeredAt
      : purchaseDates.reduce((a, b) => a.isAfter(b) ? a : b);

  return baseDate.add(Duration(days: predictedCycleDays));
}
