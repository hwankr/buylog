import 'package:flutter/material.dart';

import '../../models/item.dart';
import '../../screens/items_screen.dart';
import '../../theme/app_theme.dart';

class GroupScopedItemList extends StatelessWidget {
  const GroupScopedItemList({
    super.key,
    required this.items,
    required this.isLoading,
    this.errorMessage,
    required this.emptyMessage,
    this.emptyActionLabel,
    this.onEmptyAction,
  });

  final List<ConsumableItem> items;
  final bool isLoading;
  final String? errorMessage;
  final String emptyMessage;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage?.isNotEmpty == true) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Text(
          errorMessage!,
          style: const TextStyle(color: AppColors.danger, fontSize: 13),
        ),
      );
    }

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              emptyMessage,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            if (emptyActionLabel != null && onEmptyAction != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onEmptyAction,
                icon: const Icon(Icons.add, size: 18),
                label: Text(emptyActionLabel!),
              ),
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        children: [
          for (final item in items) ...[
            ItemRow(item: item),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
