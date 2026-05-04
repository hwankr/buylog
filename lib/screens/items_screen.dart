import 'package:flutter/material.dart';
import '../models/item.dart';
import '../services/item_store.dart';
import '../theme/app_theme.dart';
import '../widgets/dday_badge.dart';
import 'item_detail_screen.dart';

/// "모든 제품" tab — full list with filter chips (전체 / 긴급 / 곧 / 여유).
class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key, this.showBack = false});

  /// When pushed on top of the stack (e.g. from home's "모두 보기"), show
  /// a back button instead of the bare title block.
  final bool showBack;

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

enum _Filter { all, urgent, soon, fresh }

class _ItemsScreenState extends State<ItemsScreen> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.showBack
          ? AppBar(
              backgroundColor: AppColors.background,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: const Text('모든 제품'),
            )
          : null,
      body: SafeArea(
        top: !widget.showBack,
        child: ValueListenableBuilder<List<ConsumableItem>>(
          valueListenable: ItemStore.instance,
          builder: (context, items, _) {
            final counts = _counts(items);
            final filtered = _applyFilter(items)
              ..sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));

            return CustomScrollView(
              slivers: [
                if (!widget.showBack)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '모든 제품',
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '전체 ${items.length}개 · 이번 주 교체 ${counts[_Filter.urgent]}개',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final f in _Filter.values)
                          _FilterChip(
                            label: _labelOf(f),
                            count: counts[f] ?? 0,
                            active: _filter == f,
                            onTap: () => setState(() => _filter = f),
                          ),
                      ],
                    ),
                  ),
                ),
                if (filtered.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyView(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                    sliver: SliverList.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) =>
                          ItemRow(item: filtered[index]),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Map<_Filter, int> _counts(List<ConsumableItem> items) => {
    _Filter.all: items.length,
    _Filter.urgent: items.where((i) => i.daysRemaining <= 7).length,
    _Filter.soon: items
        .where((i) => i.daysRemaining > 7 && i.daysRemaining <= 30)
        .length,
    _Filter.fresh: items.where((i) => i.daysRemaining > 30).length,
  };

  List<ConsumableItem> _applyFilter(List<ConsumableItem> items) =>
      switch (_filter) {
        _Filter.all => List.of(items),
        _Filter.urgent => items.where((i) => i.daysRemaining <= 7).toList(),
        _Filter.soon => items
            .where((i) => i.daysRemaining > 7 && i.daysRemaining <= 30)
            .toList(),
        _Filter.fresh => items.where((i) => i.daysRemaining > 30).toList(),
      };

  String _labelOf(_Filter f) => switch (f) {
    _Filter.all => '전체',
    _Filter.urgent => '긴급',
    _Filter.soon => '곧',
    _Filter.fresh => '여유',
  };
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : AppColors.textSecondary,
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: (active ? Colors.white : AppColors.textSecondary)
                    .withValues(alpha: 0.7),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact item row used in the items list and "다가오는 교체" home section.
class ItemRow extends StatelessWidget {
  const ItemRow({
    super.key,
    required this.item,
    this.dense = false,
    this.onTap,
  });

  final ConsumableItem item;
  final bool dense;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tile = dense ? 36.0 : 40.0;
    final iconSize = dense ? 18.0 : 20.0;
    final cyclePart = item.aiPredictedDays ?? item.cycleDays;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap:
            onTap ??
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item)),
            ),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: tile,
                height: tile,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  item.icon,
                  size: iconSize,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.brand} · 주기 $cyclePart일',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              DdayBadge(daysRemaining: item.daysRemaining),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.border,
                  width: 1,
                  style: BorderStyle.solid,
                ),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 30,
                color: AppColors.textSoft,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '해당 조건의 제품이 없어요',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '필터를 바꾸거나 제품을 새로 추가해보세요',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
