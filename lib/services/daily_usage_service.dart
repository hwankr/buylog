import 'package:shared_preferences/shared_preferences.dart';

/// 카테고리별 일일 사용량을 SharedPreferences에 임시 저장하는 서비스.
///
/// 저장 단위 (UI 입력 → 내부 변환):
///   filter (가전/필터)     : L/일   → 그대로 사용
///   liquid (주방·세탁·헤어): 회/주  → ÷7 → 회/일
///   consumable (욕실/위생) : 회/일  → 그대로 사용
class DailyUsageService {
  static final DailyUsageService instance = DailyUsageService._();
  DailyUsageService._();

  static const _prefix = 'daily_usage_';

  static const Map<String, String> categoryToGroup = {
    '가전/필터': 'filter',
    '욕실/위생': 'consumable',
    '주방/세제': 'liquid',
    '세탁/청소': 'liquid',
    '헤어/바디': 'liquid',
  };

  /// 대분류별 UI 표시 단위 문자열
  static const Map<String, String> groupUnit = {
    'filter': 'L/일',
    'liquid': '회/주',
    'consumable': '회/일',
  };

  /// 대분류별 기본 UI 입력값 (baseUsageRef 기준)
  static const Map<String, double> groupDefaultUi = {
    'filter': 3.0, // 3.0 L/일
    'liquid': 5.0, // 5.0 회/주 (내부: 5/7 ≈ 0.714)
    'consumable': 2.0, // 2.0 회/일
  };

  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// 카테고리에 해당하는 대분류 그룹 ('filter' | 'liquid' | 'consumable')
  String groupOf(String category) => categoryToGroup[category] ?? 'consumable';

  /// 카테고리의 UI 단위 문자열
  String unitOf(String category) => groupUnit[groupOf(category)] ?? '회/일';

  /// 카테고리의 기본 UI 입력값 (입력이 없을 때 플레이스홀더로 표시)
  double defaultUiValue(String category) =>
      groupDefaultUi[groupOf(category)] ?? 1.0;

  /// UI에서 저장된 값 (회/주 or L/일 그대로) — 없으면 null
  double? getUiValue(String category) => _prefs?.getDouble(_prefix + category);

  /// predictCycle()의 dailyUsage 파라미터로 전달할 내부값 (회/일 or L/일).
  /// 저장값 없으면 null → predictCycle 내부에서 baseUsageRef 사용.
  double? getInternalValue(String category) {
    final raw = _prefs?.getDouble(_prefix + category);
    if (raw == null) return null;
    final group = groupOf(category);
    return group == 'liquid' ? raw / 7.0 : raw;
  }

  /// UI 입력값을 저장 (회/주 or L/일 그대로)
  Future<void> setUiValue(String category, double value) async {
    await _prefs?.setDouble(_prefix + category, value);
  }

  /// 해당 카테고리 값 초기화 (기본값으로 되돌리기)
  Future<void> clear(String category) async {
    await _prefs?.remove(_prefix + category);
  }
}
