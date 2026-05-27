import 'package:flutter/material.dart';

import '../data/sample_data.dart';
import '../services/report_service.dart';
import '../theme/app_theme.dart';
import '../widgets/reports/category_pie_chart.dart';
import '../widgets/reports/enhanced_category_breakdown_list.dart';
import '../widgets/reports/month_filter_list_view.dart';
import '../widgets/reports/monthly_bar_chart.dart';
import '../widgets/reports/price_movement_list.dart';
import '../widgets/reports/refill_forecast_card.dart';
import '../widgets/reports/report_hero_card.dart';
import '../widgets/reports/report_insight_strip.dart';
import '../widgets/reports/share_action_button.dart';

enum _ReportPeriod { monthly, yearly }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  // _selectedMonth 만 state 로 보유한다. ReportService/집계는 build 마다
  // 재계산한다.
  //
  // 이유: ReportsScreen 은 main.dart 의 IndexedStack 에 상주해 앱 수명 동안
  // 마운트 유지된다. initState + late final 캐싱을 쓰면 월 경계 교차 시 구 월
  // 윈도우가, 향후 Supabase write 시 stale 데이터가 화면에 박혀 ReportsScreen 이
  // destroy 되기 전에는 갱신되지 않는 회귀가 발생한다.
  DateTime? _selectedMonth;
  _ReportPeriod _period = _ReportPeriod.monthly;
  int _selectedYear = DateTime.now().year;

  void _onMonthTap(DateTime m) {
    setState(() {
      _selectedMonth = _selectedMonth == m ? null : m;
    });
  }

  void _onPeriodChanged(Set<_ReportPeriod> selected) {
    if (selected.isEmpty) return;
    setState(() {
      _period = selected.first;
      _selectedMonth = null;
    });
  }

  void _changeYear(int delta) {
    setState(() {
      _selectedYear += delta;
      _selectedMonth = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = ReportService.fromItems(SampleData.items);
    final now = DateTime.now();
    final months = service.aggregateRecentMonths();
    final yearly = service.aggregateYear(_selectedYear);
    final isYearly = _period == _ReportPeriod.yearly;

    // 요약/파이/상세는 지출이 있는 최신 월을 우선 사용해 "빈 현재 월 → 0원"
    // UX 회귀를 피한다. 전부 0원이면 현재 월로 fallback.
    final latest =
        service.latestMonthlyWithSpending() ??
        (months.isEmpty ? null : months.last);
    final activeMonth = latest?.month ?? DateTime(now.year, now.month, 1);

    final monthlyBreakdown = latest == null
        ? const <CategoryBreakdown>[]
        : service.categoryBreakdownFor(activeMonth);
    final yearlyBreakdown = service.categoryBreakdownForYear(_selectedYear);
    final chartData = isYearly ? yearly.months : months;
    final breakdown = isYearly ? yearlyBreakdown : monthlyBreakdown;
    final summary = isYearly
        ? service.yearlySummary(_selectedYear)
        : service.monthlySummary(activeMonth);
    final insights = service.smartInsights(month: activeMonth);
    final forecast = service.refillForecast();
    final priceMovements = service.priceMovements(limit: 4);
    final categoryRows = isYearly
        ? service.categoryComparisonForYear(_selectedYear)
        : service.categoryComparisonForMonth(activeMonth);

    // `_selectedMonth`는 순수 widget state 로 보관되므로 IndexedStack 하에서
    // 앱 수명만큼 유지된다. 월 경계 교차 또는 데이터 동기화로 aggregateRecentMonths
    // 결과가 바뀌면 선택 월이 현재 window 밖으로 밀려 "헤더만 떠 있고 바 차트에는
    // 해당 월이 없는" 모순 상태가 발생할 수 있다. 매 build 에서 months 와 교차
    // 검증하여 유효 월만 하위 위젯으로 내려보낸다.
    final effectiveSelectedMonth =
        _selectedMonth != null &&
            chartData.any((m) => m.month == _selectedMonth)
        ? _selectedMonth
        : null;

    final heroTitle = isYearly ? '연간 지출 현황' : '${activeMonth.month}월 리포트';
    final chartTitle = isYearly ? '연간 월별 지출' : '월별 지출 추이';
    final detailTitle = isYearly ? '연간 카테고리 상세' : '카테고리별 상세';
    final pieTitle = isYearly ? '연간 카테고리 구성' : '${activeMonth.month}월 카테고리 구성';

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '리포트',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  ShareActionButton(service: service),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: SegmentedButton<_ReportPeriod>(
                      segments: const [
                        ButtonSegment(
                          value: _ReportPeriod.monthly,
                          label: Text('월간'),
                          icon: Icon(Icons.calendar_view_month_outlined),
                        ),
                        ButtonSegment(
                          value: _ReportPeriod.yearly,
                          label: Text('연간'),
                          icon: Icon(Icons.calendar_today_outlined),
                        ),
                      ],
                      selected: {_period},
                      showSelectedIcon: false,
                      onSelectionChanged: _onPeriodChanged,
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: WidgetStateProperty.resolveWith<Color>(
                          (states) => states.contains(WidgetState.selected)
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                        backgroundColor: WidgetStateProperty.resolveWith<Color>(
                          (states) => states.contains(WidgetState.selected)
                              ? AppColors.primary
                              : AppColors.surface,
                        ),
                      ),
                    ),
                  ),
                  if (isYearly) ...[
                    const SizedBox(width: 10),
                    _YearControl(
                      year: _selectedYear,
                      onPrevious: () => _changeYear(-1),
                      onNext: () => _changeYear(1),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: ReportHeroCard(title: heroTitle, summary: summary),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: ReportInsightStrip(insights: insights),
            ),
          ),
          if (!isYearly)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: RefillForecastCard(forecast: forecast),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: _ReportSectionCard(
                title: pieTitle,
                child: CategoryPieChart(data: breakdown),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: _ReportSectionCard(
                title: chartTitle,
                child: MonthlyBarChart(
                  data: chartData,
                  selectedMonth: effectiveSelectedMonth,
                  onMonthTap: _onMonthTap,
                  highlightLatest: !isYearly,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: PriceMovementList(movements: priceMovements),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: EnhancedCategoryBreakdownList(
                title: detailTitle,
                rows: categoryRows,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: MonthFilterListView(
              selectedMonth: effectiveSelectedMonth,
              service: service,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _ReportSectionCard extends StatelessWidget {
  const _ReportSectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _YearControl extends StatelessWidget {
  const _YearControl({
    required this.year,
    required this.onPrevious,
    required this.onNext,
  });

  final int year;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '이전 연도',
            constraints: const BoxConstraints.tightFor(width: 36, height: 40),
            padding: EdgeInsets.zero,
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left, size: 20),
            color: AppColors.textSecondary,
          ),
          Text(
            '$year년',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          IconButton(
            tooltip: '다음 연도',
            constraints: const BoxConstraints.tightFor(width: 36, height: 40),
            padding: EdgeInsets.zero,
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right, size: 20),
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}
