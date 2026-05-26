import 'package:flutter/material.dart';

import '../../models/item_scope.dart';
import '../../theme/app_theme.dart';

class ItemScopeTabs extends StatelessWidget {
  const ItemScopeTabs({
    super.key,
    required this.scopes,
    required this.selectedScope,
    required this.onSelected,
  });

  final List<ItemScope> scopes;
  final ItemScope selectedScope;
  final ValueChanged<ItemScope> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: scopes.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final scope = scopes[index];
          final active = scope == selectedScope;
          return ChoiceChip(
            label: Text(scope.label),
            selected: active,
            onSelected: (_) => onSelected(scope),
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.surface,
            labelStyle: TextStyle(
              color: active ? Colors.white : AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: BorderSide(
                color: active ? AppColors.primary : AppColors.border,
                width: 0.5,
              ),
            ),
          );
        },
      ),
    );
  }
}
