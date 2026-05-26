import 'package:flutter/material.dart';

import '../../screens/items_screen.dart';
import '../../services/group_items_store.dart';
import '../../theme/app_theme.dart';

class GroupScopedItemList extends StatelessWidget {
  const GroupScopedItemList({super.key, required this.state});

  final GroupItemsState state;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.errorMessage?.isNotEmpty == true) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Text(
          state.errorMessage!,
          style: const TextStyle(color: AppColors.danger, fontSize: 13),
        ),
      );
    }

    if (state.items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Text(
          '표시할 물품이 없습니다.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        children: [
          for (final item in state.items) ...[
            ItemRow(item: item),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
