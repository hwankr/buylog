import 'package:flutter/material.dart';

import '../../models/group.dart';
import '../../theme/app_theme.dart';

class GroupSettingsDialog extends StatefulWidget {
  const GroupSettingsDialog({
    super.key,
    required this.group,
    required this.canRenameGroup,
    required this.isUpdatingGroup,
    required this.isRefreshingMembers,
    required this.isLeavingGroup,
    required this.errorMessage,
    required this.onRenameGroup,
    required this.onCopyInviteCode,
    required this.onRefreshMembers,
    required this.onLeaveGroup,
  });

  final BuylogGroup group;
  final bool canRenameGroup;
  final bool isUpdatingGroup;
  final bool isRefreshingMembers;
  final bool isLeavingGroup;
  final String? errorMessage;
  final Future<void> Function(String name) onRenameGroup;
  final VoidCallback onCopyInviteCode;
  final VoidCallback onRefreshMembers;
  final VoidCallback onLeaveGroup;

  @override
  State<GroupSettingsDialog> createState() => _GroupSettingsDialogState();
}

class _GroupSettingsDialogState extends State<GroupSettingsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group.name);
  }

  @override
  void didUpdateWidget(covariant GroupSettingsDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.group.name != widget.group.name &&
        _nameController.text != widget.group.name) {
      _nameController.text = widget.group.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submitName() async {
    if (!widget.canRenameGroup || widget.isUpdatingGroup) return;
    if (!_formKey.currentState!.validate()) return;

    final nextName = _nameController.text.trim();
    if (nextName == widget.group.name) {
      Navigator.of(context).pop();
      return;
    }

    try {
      await widget.onRenameGroup(nextName);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final errorMessage = widget.errorMessage;

    return AlertDialog(
      title: const Text('그룹 설정'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Form(
              key: _formKey,
              child: TextFormField(
                key: const Key('group-settings-name-field'),
                controller: _nameController,
                readOnly: !widget.canRenameGroup || widget.isUpdatingGroup,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(labelText: '그룹 이름'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '그룹 이름을 입력해 주세요.';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _submitName(),
              ),
            ),
            const SizedBox(height: 16),
            _SettingsActionButton(
              icon: Icons.copy,
              label: '초대 코드 복사',
              value: widget.group.inviteCode,
              onPressed: widget.onCopyInviteCode,
            ),
            const SizedBox(height: 8),
            _SettingsActionButton(
              icon: Icons.refresh,
              label: '멤버 새로고침',
              value: '최신 멤버 목록',
              onPressed: widget.isRefreshingMembers
                  ? null
                  : widget.onRefreshMembers,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: widget.isLeavingGroup ? null : widget.onLeaveGroup,
              icon: widget.isLeavingGroup
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout, size: 18),
              label: const Text('그룹 탈퇴'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
              ),
            ),
            if (errorMessage?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Text(
                errorMessage!,
                style: const TextStyle(color: AppColors.danger),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.isUpdatingGroup
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
        FilledButton(
          onPressed: widget.canRenameGroup && !widget.isUpdatingGroup
              ? _submitName
              : null,
          child: widget.isUpdatingGroup
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('저장'),
        ),
      ],
    );
  }
}

class _SettingsActionButton extends StatelessWidget {
  const _SettingsActionButton({
    required this.icon,
    required this.label,
    required this.value,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
