import 'package:shared_preferences/shared_preferences.dart';
import 'regression_coefficients.dart';

const int kPhase4Threshold = 15;
const String _prefPrefix = 'personal_beta_';
const List<String> _coefKeys = [
  'intercept',
  'daily_usage',
  'base_cycle',
  'correction_factor',
  'prev_interval',
  'season',
];

/// Phase 4 개인화 다중회귀 서비스.
///
/// 구매 이력 15회 이상 누적 시 개인 데이터로 OLS β 계수를 피팅하고
/// SharedPreferences에 저장한다.
/// 사전학습 계수([ConsumableCycleCoefficients.data])를 초기 fallback으로 사용한다.
class PersonalRegressionService {
  static final PersonalRegressionService instance =
      PersonalRegressionService._();
  PersonalRegressionService._();

  SharedPreferences? _prefs;
  final Map<String, Map<String, double>> _cache = {};

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    for (final group in ['filter', 'liquid', 'consumable', 'average']) {
      final coefs = _loadFromPrefs(group);
      if (coefs != null) _cache[group] = coefs;
    }
  }

  /// 그룹의 개인화 β 계수 (없으면 null → 사전학습 계수 fallback)
  Map<String, double>? getBeta(String group) => _cache[group];

  /// 개인화 β 계수로 주기 예측 (일, double). 개인 모델 없으면 null.
  double? predict({
    required String group,
    required double dailyUsage,
    required double baseCycle,
    required double prevInterval,
    required bool isSummer,
  }) {
    final coef = _cache[group];
    if (coef == null) return null;

    final ref = ConsumableCycleCoefficients.baseUsageRef[group] ?? 1.0;
    final cf = dailyUsage > 0 ? ref / dailyUsage : 1.0;

    final raw =
        coef['intercept']! +
        coef['daily_usage']! * dailyUsage +
        coef['base_cycle']! * baseCycle +
        coef['correction_factor']! * cf +
        coef['prev_interval']! * prevInterval +
        coef['season']! * (isSummer ? 1.0 : 0.0);

    return raw.clamp(baseCycle * 0.25, baseCycle * 3.0);
  }

  /// 구매 이력 15회 이상이면 OLS로 β 피팅 후 저장. 성공 시 true 반환.
  Future<bool> updateIfNeeded({
    required String group,
    required List<DateTime> purchaseDates,
    required double dailyUsage,
  }) async {
    if (purchaseDates.length < kPhase4Threshold) return false;

    final coefs = _fitOLS(
      group: group,
      purchaseDates: purchaseDates,
      dailyUsage: dailyUsage,
    );
    if (coefs == null) return false;

    _cache[group] = coefs;
    await _saveToPrefs(group, coefs);
    return true;
  }

  /// OLS 피팅: X'Xβ = X'y (정규방정식, 가우스 소거법)
  ///
  /// 피처: [intercept, daily_usage, base_cycle, correction_factor, prev_interval, season]
  /// 타겟: 구매 간격 (일)
  Map<String, double>? _fitOLS({
    required String group,
    required List<DateTime> purchaseDates,
    required double dailyUsage,
  }) {
    final sorted = [...purchaseDates]..sort((a, b) => a.compareTo(b));
    final intervals = <int>[];
    for (int i = 1; i < sorted.length; i++) {
      intervals.add(sorted[i].difference(sorted[i - 1]).inDays);
    }
    if (intervals.isEmpty) return null;

    final baseCycle = ConsumableCycleCoefficients.baseCycleDays[group]!
        .toDouble();
    final ref = ConsumableCycleCoefficients.baseUsageRef[group] ?? 1.0;
    final cf = dailyUsage > 0 ? ref / dailyUsage : 1.0;

    final matX = <List<double>>[];
    final vecY = <double>[];

    for (int i = 0; i < intervals.length; i++) {
      final prevIntervalVal = i == 0 ? baseCycle : intervals[i - 1].toDouble();
      final purchaseMonth = sorted[i].month;
      final isSummer = purchaseMonth >= 6 && purchaseMonth <= 8;

      matX.add([
        1.0,
        dailyUsage,
        baseCycle,
        cf,
        prevIntervalVal,
        isSummer ? 1.0 : 0.0,
      ]);
      vecY.add(intervals[i].toDouble());
    }

    const p = 6;
    final n = matX.length;
    final xtx = List.generate(p, (_) => List<double>.filled(p, 0.0));
    final xty = List<double>.filled(p, 0.0);

    for (int i = 0; i < n; i++) {
      for (int j = 0; j < p; j++) {
        xty[j] += matX[i][j] * vecY[i];
        for (int k = 0; k < p; k++) {
          xtx[j][k] += matX[i][j] * matX[i][k];
        }
      }
    }

    final beta = _gaussianElimination(xtx, xty);
    if (beta == null) return null;

    return {
      'intercept': beta[0],
      'daily_usage': beta[1],
      'base_cycle': beta[2],
      'correction_factor': beta[3],
      'prev_interval': beta[4],
      'season': beta[5],
    };
  }

  /// 부분 피버팅 가우스 소거법으로 Ax = b 풀기
  List<double>? _gaussianElimination(List<List<double>> a, List<double> b) {
    final n = b.length;
    final aug = List.generate(n, (i) => [...a[i], b[i]]);

    for (int col = 0; col < n; col++) {
      int maxRow = col;
      double maxVal = aug[col][col].abs();
      for (int row = col + 1; row < n; row++) {
        if (aug[row][col].abs() > maxVal) {
          maxVal = aug[row][col].abs();
          maxRow = row;
        }
      }
      if (maxVal < 1e-10) return null; // 특이행렬

      final tmp = aug[col];
      aug[col] = aug[maxRow];
      aug[maxRow] = tmp;

      for (int row = col + 1; row < n; row++) {
        final factor = aug[row][col] / aug[col][col];
        for (int k = col; k <= n; k++) {
          aug[row][k] -= factor * aug[col][k];
        }
      }
    }

    final x = List<double>.filled(n, 0.0);
    for (int i = n - 1; i >= 0; i--) {
      x[i] = aug[i][n];
      for (int j = i + 1; j < n; j++) {
        x[i] -= aug[i][j] * x[j];
      }
      x[i] /= aug[i][i];
    }
    return x;
  }

  Map<String, double>? _loadFromPrefs(String group) {
    final prefs = _prefs;
    if (prefs == null) return null;
    final coefs = <String, double>{};
    for (final key in _coefKeys) {
      final val = prefs.getDouble('$_prefPrefix${group}_$key');
      if (val == null) return null;
      coefs[key] = val;
    }
    return coefs;
  }

  Future<void> _saveToPrefs(String group, Map<String, double> coefs) async {
    final prefs = _prefs;
    if (prefs == null) return;
    for (final entry in coefs.entries) {
      await prefs.setDouble('$_prefPrefix${group}_${entry.key}', entry.value);
    }
  }
}
