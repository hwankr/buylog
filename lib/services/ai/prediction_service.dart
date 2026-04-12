enum PredictionPhase { phase1, phase2, phase3 }

const double kPriorWeight = 3.0;
const int kPhase3Threshold = 6;        // 이 값 이상이면 Phase3
const double kConfidenceBase = 0.1;    // 신뢰도 시작값
const double kConfidenceStep = 0.1;    // Phase2 신뢰도 증가량
const double kConfidencePhase3Base = 0.5;  // Phase3 신뢰도 시작값
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

PredictionResult predictCycle({
  required List<DateTime> purchaseDates,
  required int categoryDefaultDays,
}) {
  final intervals = calcIntervals(purchaseDates);
  final count = intervals.length;

  // Phase 1
  if (count == 0) {
    return PredictionResult(
      predictedCycleDays: categoryDefaultDays,
      confidence: kConfidenceBase,
      phase: PredictionPhase.phase1,
    );
  }
  // Phase 2
  if (count < kPhase3Threshold) {
    final wma = calcWMA(intervals);
    return PredictionResult(
      predictedCycleDays: wma.round(),
      confidence: kConfidenceBase + count * kConfidenceStep,
      phase: PredictionPhase.phase2,
    );
  }
  // Phase 3
  final observedAvg = intervals.reduce((a, b) => a + b) / intervals.length;
  final newEstimate =
        (kPriorWeight * categoryDefaultDays + count * observedAvg) /
        (kPriorWeight + count);
  final confidence = (kConfidencePhase3Base + (count - kConfidencePhase3Offset) * kConfidencePhase3Step).clamp(0.0, 1.0);

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
	final baseDate = purchaseDates.isEmpty ? registeredAt : purchaseDates.reduce((a, b) => a.isAfter(b) ? a : b);
	final difference = now.difference(baseDate).inDays;

	return predictedCycleDays - difference;
}

double calcRemainingPercent({
	required List<DateTime> purchaseDates,
	required int predictedCycleDays,
	required DateTime registeredAt,
}) {
	if (predictedCycleDays <= 0 ) return 0.0;

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

	final baseDate = purchaseDates.isEmpty ? registeredAt : purchaseDates.reduce((a, b) => a.isAfter(b) ? a : b);

	return baseDate.add(Duration(days: predictedCycleDays));
}