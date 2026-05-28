import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/item.dart';
import '../models/item_scope.dart';
import '../services/group_store.dart';
import '../services/item_store.dart';
import '../services/report_items_store.dart';
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
import '../widgets/reports/report_scope_tabs.dart';
import '../widgets/reports/share_action_button.dart';

enum _ReportPeriod { monthly, yearly }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({
    super.key,
    this.groupListenable,
    this.personalItemsListenable,
    this.saveEventListenable,
    this.createReportItemsStore,
  });

  final ValueListenable<GroupState>? groupListenable;
  final ValueListenable<List<ConsumableItem>>? personalItemsListenable;
  final ValueListenable<ItemSaveEvent?>? saveEventListenable;
  final ReportItemsStore Function()? createReportItemsStore;

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

  late final ValueListenable<GroupState> _groupListenable;
  late final ValueListenable<List<ConsumableItem>> _personalItemsListenable;
  late final ValueListenable<ItemSaveEvent?> _saveEventListenable;
  late final ReportItemsStore _reportItemsStore;
  ItemScope _selectedScope = const ItemScope.personal();

  @override
  void initState() {
    super.initState();
    _groupListenable = widget.groupListenable ?? GroupStore.instance;
    _personalItemsListenable =
        widget.personalItemsListenable ?? ItemStore.instance;
    _saveEventListenable =
        widget.saveEventListenable ?? ItemStore.instance.lastSaveEvent;
    _reportItemsStore =
        widget.createReportItemsStore?.call() ?? ReportItemsStore();
    _selectedScope = _normalizedScope(
      _selectedScope,
      _reportScopes(_groupListenable.value),
    );
    _groupListenable.addListener(_handleGroupsChanged);
    _saveEventListenable.addListener(_reloadAfterScopedSave);
    if (_selectedScope.isGroup) {
      _reportItemsStore.load(_selectedScope);
    }
  }

  @override
  void dispose() {
    _groupListenable.removeListener(_handleGroupsChanged);
    _saveEventListenable.removeListener(_reloadAfterScopedSave);
    _reportItemsStore.dispose();
    super.dispose();
  }

  List<ItemScope> _reportScopes(GroupState state) {
    return <ItemScope>[
      const ItemScope.personal(),
      for (final group in state.visibleGroups)
        ItemScope.group(id: group.id, label: group.name),
    ];
  }

  ItemScope _normalizedScope(ItemScope current, List<ItemScope> scopes) {
    for (final scope in scopes) {
      if (scope.storageKey == current.storageKey) return scope;
    }
    return const ItemScope.personal();
  }

  void _handleGroupsChanged() {
    final normalized = _normalizedScope(
      _selectedScope,
      _reportScopes(_groupListenable.value),
    );
    final storageChanged = normalized.storageKey != _selectedScope.storageKey;
    final labelChanged = normalized.label != _selectedScope.label;
    if (!storageChanged && !labelChanged) return;

    setState(() {
      _selectedScope = normalized;
      if (storageChanged) {
        _selectedMonth = null;
      }
    });
    if (normalized.isGroup) {
      _reportItemsStore.load(normalized);
    }
  }

  void _selectReportScope(ItemScope scope) {
    if (scope.storageKey == _selectedScope.storageKey) return;
    setState(() {
      _selectedScope = scope;
      _selectedMonth = null;
    });
    if (scope.isGroup) {
      _reportItemsStore.load(scope);
    }
  }

  void _reloadAfterScopedSave() {
    final event = _saveEventListenable.value;
    if (event == null || !_selectedScope.isGroup) return;
    if (event.scope.storageKey != _selectedScope.storageKey) return;
    _reportItemsStore.load(_selectedScope);
  }

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
    return ValueListenableBuilder<GroupState>(
      valueListenable: _groupListenable,
      builder: (context, groupState, _) {
        final scopes = _reportScopes(groupState);
        final selectedScope = _normalizedScope(_selectedScope, scopes);
        if (selectedScope.storageKey != _selectedScope.storageKey ||
            selectedScope.label != _selectedScope.label) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final storageChanged =
                selectedScope.storageKey != _selectedScope.storageKey;
            setState(() {
              _selectedScope = selectedScope;
              if (storageChanged) {
                _selectedMonth = null;
              }
            });
          });
        }

        return ValueListenableBuilder<List<ConsumableItem>>(
          valueListenable: _personalItemsListenable,
          builder: (context, personalItems, _) {
            return ValueListenableBuilder<ReportItemsState>(
              valueListenable: _reportItemsStore,
              builder: (context, reportItemState, _) {
                final groupStateMatches =
                    reportItemState.scope.storageKey ==
                    selectedScope.storageKey;
                final reportItems = selectedScope.isPersonal
                    ? personalItems
                    : groupStateMatches
                    ? reportItemState.items
                    : const <ConsumableItem>[];
                final isScopeLoading =
                    selectedScope.isGroup &&
                    groupStateMatches &&
                    reportItemState.isLoading;
                final scopeErrorMessage =
                    selectedScope.isGroup && groupStateMatches
                    ? reportItemState.errorMessage
                    : null;

                return _buildReportContent(
                  context: context,
                  scopes: scopes,
                  selectedScope: selectedScope,
                  items: reportItems,
                  isScopeLoading: isScopeLoading,
                  scopeErrorMessage: scopeErrorMessage,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildReportContent({
    required BuildContext context,
    required List<ItemScope> scopes,
    required ItemScope selectedScope,
    required List<ConsumableItem> items,
    required bool isScopeLoading,
    required String? scopeErrorMessage,
  }) {
    final service = ReportService.fromItems(items);
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
              padding: const EdgeInsets.only(top: 16),
              child: ReportScopeTabs(
                scopes: scopes,
                selectedScope: selectedScope,
                onSelected: _selectReportScope,
              ),
            ),
          ),
          if (isScopeLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: _ReportStatusMessage.loading(),
              ),
            ),
          if (scopeErrorMessage?.isNotEmpty == true)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: _ReportStatusMessage.error(scopeErrorMessage!),
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
              child: _ReportSectionCard(
                title: pieTitle,
                child: CategoryPieChart(data: breakdown),
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

class _ReportStatusMessage extends StatelessWidget {
  const _ReportStatusMessage.loading()
    : message = '리포트 데이터를 불러오는 중입니다.',
      icon = Icons.sync,
      color = AppColors.textSecondary;

  const _ReportStatusMessage.error(this.message)
    : icon = Icons.error_outline,
      color = AppColors.danger;

  final String message;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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
