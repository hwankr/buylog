import 'regression_coefficients.dart';

// UI 드롭다운 목록 및 Phase 3 Bayesian prior 용도
// Phase 1 기본값은 getDefaultDays → ConsumableCycleCoefficients.predictFromCategory 로 위임
const Map<String, int> categoryDefaultDays = {
  '욕실/위생': 90, // consumable  기준 주기
  '주방/세제': 30, // liquid      기준 주기
  '세탁/청소': 30, // liquid      기준 주기
  '헤어/바디': 30, // liquid      기준 주기
  '가전/필터': 180, // filter     기준 주기
};

/// UI 기본 교체 주기 반환 — Phase 1 및 add_item 화면 텍스트필드 초기값
///
/// 회귀 모델 [ConsumableCycleCoefficients.predictFromCategory]로 예측하며,
/// [dailyUsage]가 null이면 대분류 기준 사용량을 기본값으로 사용합니다.
/// 알 수 없는 카테고리는 average β 계수로 fallback됩니다.
int getDefaultDays(String categoryName, {double? dailyUsage}) {
  return ConsumableCycleCoefficients.predictFromCategory(
    categoryName: categoryName,
    dailyUsage:   dailyUsage,
  );
}
