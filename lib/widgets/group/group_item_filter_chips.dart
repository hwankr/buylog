import 'package:flutter/material.dart';

import '../../services/group_dashboard_summary.dart';
import '../../theme/app_theme.dart';

class GroupItemFilterChips extends StatelessWidget {
  const GroupItemFilterChips({
    super.key,
    required this.summary,
    required this.onSelected,
  });

  final GroupDashboardSummary summary;
  final ValueChanged<GroupItemFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final filter in GroupItemFilter.values)
          ChoiceChip(
            label: Text('${filter.label} ${summary.countFor(filter)}'),
            selected: summary.selectedFilter == filter,
            onSelected: (_) => onSelected(filter),
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.surface,
            labelStyle: TextStyle(
              color: summary.selectedFilter == filter
                  ? Colors.white
                  : AppColors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: BorderSide(
                color: summary.selectedFilter == filter
                    ? AppColors.primary
                    : AppColors.border,
                width: 0.5,
              ),
            ),
          ),
      ],
    );
  }
}
