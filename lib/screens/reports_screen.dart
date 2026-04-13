import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/item.dart';
import '../services/item_store.dart';
import '../theme/app_theme.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  @override
  void initState() {
    super.initState();
    ItemStore.instance.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    ItemStore.instance.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() => setState(() {});

  // ---------------------------------------------------------------------------
  // 데이터 계산
  // ---------------------------------------------------------------------------

  /// 전체 구매 이력 수집
  List<PurchaseRecord> _allRecords(List<ConsumableItem> items) {
    return [for (final item in items) ...item.purchaseHistory];
  }

  /// 이번 달 지출 합계
  int _currentMonthTotal(List<PurchaseRecord> records) {
    final now = DateTime.now();
    return records
        .where((r) => r.date.year == now.year && r.date.month == now.month)
        .fold(0, (sum, r) => sum + r.price);
  }

  /// 카테고리별 지출 (전체 기간, 내림차순)
  List<_CategoryStat> _categoryStats(List<ConsumableItem> items) {
    final totals = <String, int>{};
    for (final item in items) {
      for (final r in item.purchaseHistory) {
        totals[item.category] = (totals[item.category] ?? 0) + r.price;
      }
    }
    if (totals.isEmpty) return [];

    final grandTotal = totals.values.fold(0, (a, b) => a + b);
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.map((e) {
      final percent = grandTotal > 0 ? (e.value / grandTotal * 100).round() : 0;
      return _CategoryStat(
        name: e.key,
        amount: e.value,
        percent: percent,
        color: _colorForCategory(e.key),
      );
    }).toList();
  }

  /// 최근 6개월 월별 지출
  List<_MonthlyStat> _monthlyStats(List<PurchaseRecord> records) {
    final now = DateTime.now();
    final result = <_MonthlyStat>[];

    for (var i = 5; i >= 0; i--) {
      // 월 계산 (연도 경계 처리)
      var month = now.month - i;
      var year = now.year;
      while (month <= 0) {
        month += 12;
        year -= 1;
      }

      final total = records
          .where((r) => r.date.year == year && r.date.month == month)
          .fold(0, (sum, r) => sum + r.price);

      result.add(_MonthlyStat(label: '$month월', amount: total));
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // 카테고리 색상 매핑
  // ---------------------------------------------------------------------------
  static const _categoryColors = <String, Color>{
    '욕실/위생': Color(0xFF0891B2),
    '주방/세제': Color(0xFF7C3AED),
    '세탁/청소': Color(0xFFD97706),
    '헤어/바디': Color(0xFFEC4899),
    '가전/필터': Color(0xFF059669),
    // 샘플 데이터 레거시 카테고리
    '위생': Color(0xFF0891B2),
    '주방': Color(0xFF7C3AED),
    '세탁': Color(0xFFD97706),
    '필터': Color(0xFF059669),
  };

  Color _colorForCategory(String category) =>
      _categoryColors[category] ?? const Color(0xFF94A3B8);

  // ---------------------------------------------------------------------------
  // 포맷 헬퍼
  // ---------------------------------------------------------------------------
  String _formatPrice(int price) {
    final str = price.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
    }
    return '$buffer원';
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final items = ItemStore.instance.value;
    final records = _allRecords(items);
    final currentMonthTotal = _currentMonthTotal(records);
    final categoryStats = _categoryStats(items);
    final monthlyStats = _monthlyStats(records);
    final maxMonthly =
        monthlyStats.map((m) => m.amount).fold(0, (a, b) => a > b ? a : b);
    final now = DateTime.now();

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Text(
                '리포트',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ),

          // 이번 달 지출 요약 + 도넛 차트
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${now.month}월 지출 현황',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        Text(
                          '${now.year}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatPrice(currentMonthTotal),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (categoryStats.isEmpty)
                      _emptyChart()
                    else
                      _buildDonutChart(categoryStats),
                  ],
                ),
              ),
            ),
          ),

          // AI 인사이트
          if (categoryStats.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _buildInsightCard(categoryStats),
              ),
            ),

          // 월별 지출 추이 바 차트
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '월별 지출 추이',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 180,
                      child: _buildBarChart(monthlyStats, maxMonthly),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 카테고리별 상세 리스트
          if (categoryStats.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Text(
                  '카테고리별 상세',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.separated(
                itemCount: categoryStats.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) =>
                    _buildCategoryRow(categoryStats[index]),
              ),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 위젯 빌더들
  // ---------------------------------------------------------------------------

  Widget _emptyChart() {
    return SizedBox(
      height: 120,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.pie_chart_outline, size: 36, color: AppColors.textMuted),
            SizedBox(height: 8),
            Text(
              '구매 이력을 추가하면\n카테고리별 분석이 표시됩니다.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonutChart(List<_CategoryStat> stats) {
    return SizedBox(
      height: 200,
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 45,
                sections: stats
                    .map(
                      (c) => PieChartSectionData(
                        value: c.percent.toDouble(),
                        color: c.color,
                        radius: 35,
                        showTitle: false,
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: stats
                .map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: c.color,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 60,
                          child: Text(
                            c.name,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${c.percent}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(List<_CategoryStat> stats) {
    final top = stats.first;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_awesome_outlined,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI 인사이트',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${top.name} 지출이 전체의 ${top.percent}%로 가장 많습니다.',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(List<_MonthlyStat> stats, int maxY) {
    final chartMaxY = maxY > 0 ? (maxY * 1.3).ceilToDouble() : 100000.0;
    final latestIdx = stats.length - 1;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: chartMaxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: chartMaxY / 4,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AppColors.border, strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, _) {
                final idx = value.toInt();
                if (idx < 0 || idx >= stats.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    stats[idx].label,
                    style: TextStyle(
                      fontSize: 11,
                      color: idx == latestIdx
                          ? AppColors.primary
                          : AppColors.textMuted,
                      fontWeight: idx == latestIdx
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: stats.asMap().entries.map((entry) {
          final isLatest = entry.key == latestIdx;
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value.amount.toDouble(),
                width: 28,
                color: isLatest
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.3),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryRow(_CategoryStat c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: c.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: c.color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: c.percent / 100,
                    minHeight: 4,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(c.color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatPrice(c.amount),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              Text(
                '${c.percent}%',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 데이터 모델
// ---------------------------------------------------------------------------

class _CategoryStat {
  final String name;
  final int amount;
  final int percent;
  final Color color;

  const _CategoryStat({
    required this.name,
    required this.amount,
    required this.percent,
    required this.color,
  });
}

class _MonthlyStat {
  final String label;
  final int amount;

  const _MonthlyStat({required this.label, required this.amount});
}
