import 'package:test/test.dart';
import 'package:buylog/services/ai/regression_coefficients.dart';

void main() {
  // ─────────────────────────────────────────────────────────────────
  // categoryToGroup 매핑
  // ─────────────────────────────────────────────────────────────────
  group('categoryToGroup 매핑', () {
    test('가전/필터 → filter', () {
      expect(ConsumableCycleCoefficients.categoryToGroup['가전/필터'], 'filter');
    });

    test('욕실/위생 → consumable', () {
      expect(
        ConsumableCycleCoefficients.categoryToGroup['욕실/위생'],
        'consumable',
      );
    });

    test('주방/세제, 세탁/청소, 헤어/바디 → liquid', () {
      for (final cat in ['주방/세제', '세탁/청소', '헤어/바디']) {
        expect(
          ConsumableCycleCoefficients.categoryToGroup[cat],
          'liquid',
          reason: '$cat 은 liquid 그룹이어야 합니다',
        );
      }
    });

    test('미등록 카테고리 → null (predictFromCategory 에서 average fallback)', () {
      expect(ConsumableCycleCoefficients.categoryToGroup['기타'], isNull);
      expect(ConsumableCycleCoefficients.categoryToGroup['없는카테고리'], isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // 대분류별 기준 예측값 (isSummer 고정 → 결정론적)
  // ─────────────────────────────────────────────────────────────────
  group('predictFromCategory — 대분류별 기준 예측값', () {
    // filter: base_usage=3.0 L/일, base_cycle=180일
    // 비여름 기준 사용량 → raw ≈ 182.88 → 183
    test('가전/필터  비여름 기준 사용량 → 183일', () {
      final days = ConsumableCycleCoefficients.predictFromCategory(
        categoryName: '가전/필터',
        isSummer: false,
      );
      expect(days, 183);
    });

    // consumable: base_usage=2.0 회/일, base_cycle=90일
    // 비여름 기준 사용량 → raw ≈ 92.38 → 92
    test('욕실/위생  비여름 기준 사용량 → 92일', () {
      final days = ConsumableCycleCoefficients.predictFromCategory(
        categoryName: '욕실/위생',
        isSummer: false,
      );
      expect(days, 92);
    });

    // liquid: base_usage=5/7 회/일, base_cycle=30일
    // 비여름 기준 사용량 → raw ≈ 30.93 → 31
    test('세탁/청소  비여름 기준 사용량 → 31일', () {
      final days = ConsumableCycleCoefficients.predictFromCategory(
        categoryName: '세탁/청소',
        isSummer: false,
      );
      expect(days, 31);
    });

    test('주방/세제  비여름 기준 사용량 → 31일  (세탁/청소 와 동일 그룹)', () {
      final days = ConsumableCycleCoefficients.predictFromCategory(
        categoryName: '주방/세제',
        isSummer: false,
      );
      expect(days, 31);
    });

    test('헤어/바디  비여름 기준 사용량 → 31일  (liquid 그룹)', () {
      final days = ConsumableCycleCoefficients.predictFromCategory(
        categoryName: '헤어/바디',
        isSummer: false,
      );
      expect(days, 31);
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // unknown category → average fallback
  // ─────────────────────────────────────────────────────────────────
  group('미분류 아이템 average fallback', () {
    // average: base_usage=1.0, base_cycle=60일
    // 비여름 기준 사용량 → raw ≈ 79.13 → 79
    test('등록 안 된 카테고리 → average 계수로 79일 예측', () {
      final days = ConsumableCycleCoefficients.predictFromCategory(
        categoryName: '없는카테고리',
        isSummer: false,
      );
      expect(days, 79);
    });

    test('빈 문자열 카테고리도 average fallback', () {
      final days = ConsumableCycleCoefficients.predictFromCategory(
        categoryName: '',
        isSummer: false,
      );
      expect(days, 79);
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // 계절 효과 — 여름이 비여름보다 주기 짧음
  // ─────────────────────────────────────────────────────────────────
  group('계절 효과  (β_season < 0 → 여름 단축)', () {
    test('가전/필터  여름(162일) < 비여름(183일)', () {
      final summer = ConsumableCycleCoefficients.predictFromCategory(
        categoryName: '가전/필터',
        isSummer: true,
      );
      final winter = ConsumableCycleCoefficients.predictFromCategory(
        categoryName: '가전/필터',
        isSummer: false,
      );
      expect(summer, 162);
      expect(winter, 183);
      expect(summer, lessThan(winter));
    });

    test('욕실/위생  여름(88일) < 비여름(92일)', () {
      final summer = ConsumableCycleCoefficients.predictFromCategory(
        categoryName: '욕실/위생',
        isSummer: true,
      );
      final winter = ConsumableCycleCoefficients.predictFromCategory(
        categoryName: '욕실/위생',
        isSummer: false,
      );
      expect(summer, 88);
      expect(winter, 92);
      expect(summer, lessThan(winter));
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // dailyUsage 방향성 — 많이 쓸수록 주기 단축 (β_daily_usage < 0)
  // ─────────────────────────────────────────────────────────────────
  group('dailyUsage 방향성  (사용량 ↑ → 주기 ↓)', () {
    test('가전/필터  절약(1.5L) > 기준(3.0L) > 과사용(5.0L)', () {
      final light = ConsumableCycleCoefficients.predictFromCategory(
        categoryName: '가전/필터',
        dailyUsage: 1.5,
        isSummer: false,
      );
      final base = ConsumableCycleCoefficients.predictFromCategory(
        categoryName: '가전/필터',
        isSummer: false,
      );
      final heavy = ConsumableCycleCoefficients.predictFromCategory(
        categoryName: '가전/필터',
        dailyUsage: 5.0,
        isSummer: false,
      );
      expect(light, 348);
      expect(base, 183);
      expect(heavy, 109);
      expect(light, greaterThan(base));
      expect(base, greaterThan(heavy));
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // dailyUsage null → base_usage 기본값 사용
  // ─────────────────────────────────────────────────────────────────
  group('dailyUsage null → 기준값 사용', () {
    test('가전/필터 dailyUsage=null 은 dailyUsage=3.0 과 동일', () {
      final withNull = ConsumableCycleCoefficients.predictFromCategory(
        categoryName: '가전/필터',
        dailyUsage: null,
        isSummer: false,
      );
      final withBase = ConsumableCycleCoefficients.predictFromCategory(
        categoryName: '가전/필터',
        dailyUsage: 3.0,
        isSummer: false,
      );
      expect(withNull, withBase);
    });

    test('세탁/청소 dailyUsage=null 은 dailyUsage=0.714286 과 동일', () {
      final withNull = ConsumableCycleCoefficients.predictFromCategory(
        categoryName: '세탁/청소',
        dailyUsage: null,
        isSummer: false,
      );
      final withBase = ConsumableCycleCoefficients.predictFromCategory(
        categoryName: '세탁/청소',
        dailyUsage: 0.714286,
        isSummer: false,
      );
      expect(withNull, withBase);
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // Clamp — [baseCycle×0.25, baseCycle×3.0] 범위 보장
  // ─────────────────────────────────────────────────────────────────
  group('출력 clamp  [baseCycle×0.25, baseCycle×3.0]', () {
    // filter baseCycle=180 → [45, 540]
    test('가전/필터 극고 사용량(50L) → 하한 clamp = 45일', () {
      final clamped = ConsumableCycleCoefficients.predict(
        group: 'filter',
        baseCycle: 180,
        dailyUsage: 50.0,
        isSummer: false,
      );
      expect(clamped, 45.0);
    });

    test('가전/필터 극저 사용량(0.1L) → 상한 clamp = 540일', () {
      final clamped = ConsumableCycleCoefficients.predict(
        group: 'filter',
        baseCycle: 180,
        dailyUsage: 0.1,
        isSummer: false,
      );
      expect(clamped, 540.0);
    });

    test('predictFromCategory 도 clamp 적용 (extremes → int 경계값)', () {
      final lo = ConsumableCycleCoefficients.predictFromCategory(
        categoryName: '가전/필터',
        dailyUsage: 50.0,
        isSummer: false,
      );
      final hi = ConsumableCycleCoefficients.predictFromCategory(
        categoryName: '가전/필터',
        dailyUsage: 0.1,
        isSummer: false,
      );
      expect(lo, 45);
      expect(hi, 540);
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // β 계수 부호 sanity check
  // ─────────────────────────────────────────────────────────────────
  group('β 계수 부호  (도메인 직관 확인)', () {
    for (final group in ['filter', 'liquid', 'consumable']) {
      test(
        '$group: β_daily_usage < 0, β_correction_factor > 0, β_season < 0',
        () {
          final c = ConsumableCycleCoefficients.data[group]!;
          expect(c['daily_usage']!, lessThan(0), reason: '많이 쓸수록 단축');
          expect(c['correction_factor']!, greaterThan(0), reason: '절약할수록 연장');
          expect(c['prev_interval']!, greaterThan(0), reason: '이전 주기 정비례');
          expect(c['season']!, lessThan(0), reason: '여름 단축');
        },
      );
    }
  });
}
