// AUTO-GENERATED COEFFICIENTS — scripts/generate_model_coefficients.py
// 재생성: python scripts/generate_model_coefficients.py  (seed=42, n=300/category)
//
// 소모품 교체 주기 다중회귀 β 계수 (Phase 4 사전학습 모델)
//
// 대분류 → UI 카테고리 매핑
//   filter     : 가전/필터
//   liquid     : 주방/세제, 세탁/청소, 헤어/바디
//   consumable : 욕실/위생
//   average    : 미분류 아이템 fallback
//
// 예측 공식:
//   predicted = β_intercept
//     + β_daily_usage       × dailyUsage
//     + β_base_cycle        × baseCycle
//     + β_correction_factor × (baseUsageRef / dailyUsage)
//     + β_prev_interval     × prevInterval
//     + β_season            × (isSummer ? 1.0 : 0.0)
//
// ignore_for_file: constant_identifier_names

/// Phase 1 다중회귀 예측 — β 계수 + predict 메서드
class ConsumableCycleCoefficients {
  ConsumableCycleCoefficients._();

  // ─────────────────────────────────────────────────────────────────
  // 카테고리 매핑
  // ─────────────────────────────────────────────────────────────────

  /// UI 카테고리명 → 회귀 대분류 그룹
  /// 목록에 없는 카테고리는 [predictFromCategory]에서 'average'로 fallback
  static const Map<String, String> categoryToGroup = {
    '가전/필터': 'filter',
    '욕실/위생': 'consumable',
    '주방/세제': 'liquid',
    '세탁/청소': 'liquid',
    '헤어/바디': 'liquid',
  };

  // ─────────────────────────────────────────────────────────────────
  // 기준값
  // ─────────────────────────────────────────────────────────────────

  /// 대분류별 기준 사용량 (correction_factor = baseUsageRef / dailyUsage)
  ///
  /// filter     : 3.0  L/일
  /// liquid     : 5/7  회/일 (5회/주)
  /// consumable : 2.0  회/일
  /// average    : 1.0  (정규화 기준 — average 모델은 base_cycle 피처로 스케일 처리)
  static const Map<String, double> baseUsageRef = {
    'filter':     3.0,
    'liquid':     0.714286,
    'consumable': 2.0,
    'average':    1.0,
  };

  /// 대분류별 기준 교체 주기 (일)
  /// · daily_usage 미입력 시 prev_interval 기본값으로도 사용
  static const Map<String, int> baseCycleDays = {
    'filter':     180,
    'liquid':     30,
    'consumable': 90,
    'average':    60,
  };

  // ─────────────────────────────────────────────────────────────────
  // β 계수 (LinearRegression, sklearn, seed=42, n=300/category)
  // ─────────────────────────────────────────────────────────────────

  static const Map<String, Map<String, double>> data = {
    // ── 필터류 (R²=0.9636, MAE=9.57일) ──────────────────────────
    'filter': {
      'intercept':         29.834096,
      'daily_usage':       -5.192643,
      'base_cycle':         0.0,
      'correction_factor': 157.727935,
      'prev_interval':      0.060512,
      'season':            -20.761488,
    },
    // ── 액체류 (R²=0.9513, MAE=2.02일) ──────────────────────────
    'liquid': {
      'intercept':         25.753586,
      'daily_usage':       -18.359899,
      'base_cycle':          0.0,
      'correction_factor':  16.818363,
      'prev_interval':       0.048988,
      'season':             -1.550331,
    },
    // ── 소모품류 (R²=0.9597, MAE=5.12일) ────────────────────────
    'consumable': {
      'intercept':         48.193089,
      'daily_usage':       -12.410406,
      'base_cycle':          0.0,
      'correction_factor':  64.806454,
      'prev_interval':       0.046727,
      'season':             -4.731752,
    },
    // ── 전체 평균 fallback (R²=0.9364, MAE=13.29일) ──────────────
    'average': {
      'intercept':         -7.845368,
      'daily_usage':       -42.245094,
      'base_cycle':          1.546601,
      'correction_factor':  30.173558,
      'prev_interval':       0.104154,
      'season':            -10.388267,
    },
  };

  // ─────────────────────────────────────────────────────────────────
  // 헬퍼
  // ─────────────────────────────────────────────────────────────────

  /// 현재 달이 여름(6~8월)이면 true
  static bool get isCurrentSummer {
    final month = DateTime.now().month;
    return month >= 6 && month <= 8;
  }

  // ─────────────────────────────────────────────────────────────────
  // 예측 메서드
  // ─────────────────────────────────────────────────────────────────

  /// 대분류 그룹 + 수치 입력으로 교체 주기 예측 (일, double 반환)
  ///
  /// [group]        : 'filter' | 'liquid' | 'consumable' | 기타 → 'average'
  /// [dailyUsage]   : 하루 사용량. null → [baseUsageRef]\[group] 사용
  /// [baseCycle]    : 기준 교체 주기 (일)
  /// [prevInterval] : 직전 교체 간격 (일). null → baseCycle 사용
  /// [isSummer]     : null → [isCurrentSummer]로 자동 결정
  static double predict({
    required String group,
    double? dailyUsage,
    required double baseCycle,
    double? prevInterval,
    bool? isSummer,
  }) {
    final coef  = data[group] ?? data['average']!;
    final ref   = baseUsageRef[group] ?? 1.0;
    final du    = dailyUsage  ?? ref;           // 미입력 → base_usage 사용
    final pi    = prevInterval ?? baseCycle;    // 미입력 → base_cycle 사용
    final cf    = ref / du;
    final summer = isSummer ?? isCurrentSummer;

    final raw = coef['intercept']!
              + coef['daily_usage']!       * du
              + coef['base_cycle']!        * baseCycle
              + coef['correction_factor']! * cf
              + coef['prev_interval']!     * pi
              + coef['season']!            * (summer ? 1.0 : 0.0);

    return raw.clamp(baseCycle * 0.25, baseCycle * 3.0);
  }

  /// UI 카테고리명으로 교체 주기 예측 (일, int 반환) — Phase 1 진입점
  ///
  /// [categoryName] : UI 카테고리명 (categoryToGroup 에 없으면 average 사용)
  /// [dailyUsage]   : 하루 사용량. null → 대분류 기준값 사용
  /// [prevInterval] : 직전 교체 간격. null → 대분류 기준 주기 사용
  /// [isSummer]     : null → 현재 월로 자동 결정
  static int predictFromCategory({
    required String categoryName,
    double? dailyUsage,
    double? prevInterval,
    bool? isSummer,
  }) {
    final group   = categoryToGroup[categoryName] ?? 'average';
    final baseCyc = baseCycleDays[group]!.toDouble();

    return predict(
      group:        group,
      dailyUsage:   dailyUsage,
      baseCycle:    baseCyc,
      prevInterval: prevInterval,
      isSummer:     isSummer,
    ).round();
  }
}
