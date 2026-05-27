import '../models/item.dart';
import '../models/item_scope.dart';

enum GroupItemFilter {
  all('전체'),
  urgent('긴급'),
  soon('곧'),
  fresh('여유');

  const GroupItemFilter(this.label);

  final String label;
}

class GroupDashboardSummary {
  const GroupDashboardSummary({
    required this.scope,
    required this.selectedFilter,
    required this.totalCount,
    required this.urgentCount,
    required this.soonCount,
    required this.freshCount,
    required this.filteredItems,
  });

  final ItemScope scope;
  final GroupItemFilter selectedFilter;
  final int totalCount;
  final int urgentCount;
  final int soonCount;
  final int freshCount;
  final List<ConsumableItem> filteredItems;

  String get scopeTitle => scope.isGroup ? '${scope.label} 물품' : '내 물품';

  int countFor(GroupItemFilter filter) {
    return switch (filter) {
      GroupItemFilter.all => totalCount,
      GroupItemFilter.urgent => urgentCount,
      GroupItemFilter.soon => soonCount,
      GroupItemFilter.fresh => freshCount,
    };
  }
}

class GroupDashboardSummaryBuilder {
  const GroupDashboardSummaryBuilder._();

  static GroupDashboardSummary build({
    required ItemScope scope,
    required List<ConsumableItem> items,
    required GroupItemFilter selectedFilter,
  }) {
    final sorted = List<ConsumableItem>.of(items)
      ..sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));

    return GroupDashboardSummary(
      scope: scope,
      selectedFilter: selectedFilter,
      totalCount: sorted.length,
      urgentCount: sorted.where(_isUrgent).length,
      soonCount: sorted.where(_isSoon).length,
      freshCount: sorted.where(_isFresh).length,
      filteredItems: List<ConsumableItem>.unmodifiable(
        sorted.where((item) => _matches(item, selectedFilter)),
      ),
    );
  }

  static bool _matches(ConsumableItem item, GroupItemFilter filter) {
    return switch (filter) {
      GroupItemFilter.all => true,
      GroupItemFilter.urgent => _isUrgent(item),
      GroupItemFilter.soon => _isSoon(item),
      GroupItemFilter.fresh => _isFresh(item),
    };
  }

  static bool _isUrgent(ConsumableItem item) => item.daysRemaining <= 7;

  static bool _isSoon(ConsumableItem item) {
    return item.daysRemaining > 7 && item.daysRemaining <= 30;
  }

  static bool _isFresh(ConsumableItem item) => item.daysRemaining > 30;
}
