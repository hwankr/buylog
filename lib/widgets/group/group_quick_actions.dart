import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class GroupQuickActions extends StatelessWidget {
  const GroupQuickActions({
    super.key,
    required this.onAddItem,
    required this.onScanReceipt,
    required this.onCreateGroup,
    this.isCreateGroupDisabled = false,
  });

  final VoidCallback onAddItem;
  final VoidCallback onScanReceipt;
  final VoidCallback onCreateGroup;
  final bool isCreateGroupDisabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onAddItem,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('물품 추가'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onScanReceipt,
                icon: const Icon(Icons.document_scanner_outlined, size: 18),
                label: const Text('영수증 스캔'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: isCreateGroupDisabled ? null : onCreateGroup,
            icon: const Icon(Icons.group_add_outlined, size: 18),
            label: const Text('그룹 추가'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
