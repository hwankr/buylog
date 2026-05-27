import 'package:buylog/models/item.dart';
import 'package:buylog/models/item_scope.dart';
import 'package:buylog/services/group_dashboard_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GroupDashboardSummaryBuilder', () {
    test('counts items by replacement urgency', () {
      final summary = GroupDashboardSummaryBuilder.build(
        scope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
        items: [
          _item('expired', daysRemaining: -1),
          _item('urgent', daysRemaining: 7),
          _item('soon', daysRemaining: 30),
          _item('fresh', daysRemaining: 31),
        ],
        selectedFilter: GroupItemFilter.all,
      );

      expect(summary.totalCount, 4);
      expect(summary.urgentCount, 2);
      expect(summary.soonCount, 1);
      expect(summary.freshCount, 1);
      expect(summary.scopeTitle, '우리 가족 물품');
    });

    test('filters items without changing summary totals', () {
      final summary = GroupDashboardSummaryBuilder.build(
        scope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
        items: [
          _item('urgent', daysRemaining: 3),
          _item('soon', daysRemaining: 20),
          _item('fresh', daysRemaining: 45),
        ],
        selectedFilter: GroupItemFilter.soon,
      );

      expect(summary.totalCount, 3);
      expect(summary.filteredItems.map((item) => item.id), ['soon']);
      expect(summary.countFor(GroupItemFilter.all), 3);
      expect(summary.countFor(GroupItemFilter.urgent), 1);
      expect(summary.countFor(GroupItemFilter.soon), 1);
      expect(summary.countFor(GroupItemFilter.fresh), 1);
    });
  });
}

ConsumableItem _item(String id, {required int daysRemaining}) {
  return ConsumableItem(
    id: id,
    name: id,
    brand: '브랜드',
    category: '주방/세제',
    icon: ConsumableItem.iconForCategory('주방/세제'),
    daysRemaining: daysRemaining,
    cycleDays: 30,
    progress: 0.5,
  );
}
