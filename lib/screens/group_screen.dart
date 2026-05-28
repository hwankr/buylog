import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/group.dart';
import '../models/item_scope.dart';
import '../services/group_dashboard_summary.dart';
import '../services/group_items_store.dart';
import '../services/group_store.dart';
import '../services/item_store.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/group/group_item_filter_chips.dart';
import '../widgets/group/group_quick_actions.dart';
import '../widgets/group/group_scoped_item_list.dart';
import '../widgets/group/group_settings_dialog.dart';
import '../widgets/group/group_status_summary.dart';
import '../widgets/group/item_scope_tabs.dart';
import 'add_item_screen.dart';
import 'scan_screen.dart';

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  late final GroupItemsStore _itemsStore;

  @override
  void initState() {
    super.initState();
    _itemsStore = GroupItemsStore();
    GroupStore.instance.addListener(_syncSelectedGroupItems);
    _syncSelectedGroupItems();
    ItemStore.instance.lastSaveEvent.addListener(_reloadAfterScopedSave);
  }

  @override
  void dispose() {
    GroupStore.instance.removeListener(_syncSelectedGroupItems);
    ItemStore.instance.lastSaveEvent.removeListener(_reloadAfterScopedSave);
    _itemsStore.dispose();
    super.dispose();
  }

  void _syncSelectedGroupItems() {
    final selectedGroupScope = GroupStore.instance.value.selectedGroupScope;
    if (selectedGroupScope == null) {
      return;
    }

    final selectedScope = GroupStore.instance.value.selectedScope;
    if (selectedScope.storageKey != selectedGroupScope.storageKey) {
      if (_itemsStore.value.scope.storageKey != selectedGroupScope.storageKey) {
        _itemsStore.load(selectedGroupScope);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final currentState = GroupStore.instance.value;
        if (currentState.selectedScope.storageKey !=
            selectedGroupScope.storageKey) {
          GroupStore.instance.selectScope(selectedGroupScope);
        }
      });
      return;
    }

    if (_itemsStore.value.scope.storageKey != selectedGroupScope.storageKey) {
      _itemsStore.load(selectedGroupScope);
    }
  }

  void _selectScope(ItemScope scope) {
    if (!scope.isGroup) {
      return;
    }
    GroupStore.instance.selectScope(scope);
  }

  void _reloadAfterScopedSave() {
    final event = ItemStore.instance.lastSaveEvent.value;
    final selectedGroupScope = GroupStore.instance.value.selectedGroupScope;
    if (event == null ||
        selectedGroupScope == null ||
        !event.scope.isGroup ||
        event.scope.storageKey != selectedGroupScope.storageKey) {
      return;
    }
    _itemsStore.load(selectedGroupScope);
  }

  Future<void> _copyInviteCode(String inviteCode) async {
    await Clipboard.setData(ClipboardData(text: inviteCode));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('초대 코드가 복사되었습니다.')));
  }

  void _openScopedAdd(ItemScope scope) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddItemScreen(targetScope: scope)),
    );
  }

  void _openScopedScan(ItemScope scope) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (scanContext) => Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              ScanScreen(targetScope: scope),
              Positioned(
                top: MediaQuery.of(scanContext).padding.top + 8,
                right: 12,
                child: Material(
                  color: AppColors.surface,
                  shape: const CircleBorder(),
                  elevation: 1,
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: AppColors.text,
                    onPressed: () => Navigator.of(scanContext).pop(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCreateGroupDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => const _CreateGroupDialog(),
    );
  }

  void _openGroupSettings(BuylogGroup group) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return ValueListenableBuilder<GroupState>(
          valueListenable: GroupStore.instance,
          builder: (context, state, _) {
            var currentGroup = group;
            for (final candidate in state.visibleGroups) {
              if (candidate.id == group.id) {
                currentGroup = candidate;
                break;
              }
            }

            return GroupSettingsDialog(
              group: currentGroup,
              canRenameGroup: currentGroup.isOwner(
                SupabaseService.currentUserId,
              ),
              isUpdatingGroup: state.isUpdatingGroup,
              isRefreshingMembers: state.isRefreshingMembers,
              isLeavingGroup: state.isLeavingGroup,
              errorMessage: state.errorMessage,
              onRenameGroup: (name) => GroupStore.instance.renameGroup(
                groupId: currentGroup.id,
                name: name,
              ),
              onCopyInviteCode: () => _copyInviteCode(currentGroup.inviteCode),
              onRefreshMembers: () =>
                  GroupStore.instance.refreshMembers(groupId: currentGroup.id),
              onLeaveGroup: () {
                Navigator.of(dialogContext).pop();
                if (!mounted) return;
                showDialog<void>(
                  context: this.context,
                  builder: (_) => _LeaveGroupDialog(group: currentGroup),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ValueListenableBuilder<GroupState>(
        valueListenable: GroupStore.instance,
        builder: (context, state, _) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final selectedGroupScope = state.selectedGroupScope;
          final selectedGroup = selectedGroupScope == null
              ? null
              : state.groupForScope(selectedGroupScope);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(0, 20, 0, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    '그룹',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                const SizedBox(height: 16),
                if (state.visibleGroups.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _EmptyGroupState(errorMessage: state.errorMessage),
                  )
                else ...[
                  ItemScopeTabs(
                    scopes: state.groupScopes,
                    selectedScope: selectedGroupScope!,
                    onSelected: _selectScope,
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GroupQuickActions(
                      onAddItem: () => _openScopedAdd(selectedGroupScope),
                      onScanReceipt: () => _openScopedScan(selectedGroupScope),
                      onCreateGroup: _openCreateGroupDialog,
                      isCreateGroupDisabled: state.isSaving,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (selectedGroup != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _GroupCard(
                        group: selectedGroup,
                        isRefreshingMembers: state.isRefreshingMembers,
                        isLeavingGroup: state.isLeavingGroup,
                        isUpdatingGroup: state.isUpdatingGroup,
                        onRefreshMembers: () => GroupStore.instance
                            .refreshMembers(groupId: selectedGroup.id),
                        onCopyInviteCode: _copyInviteCode,
                        onOpenSettings: () => _openGroupSettings(selectedGroup),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      '${selectedGroupScope.label} 목록',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  ValueListenableBuilder<GroupItemsState>(
                    valueListenable: _itemsStore,
                    builder: (context, itemState, _) {
                      final isSelectedItemScope =
                          itemState.scope.storageKey ==
                          selectedGroupScope.storageKey;
                      final summary = GroupDashboardSummaryBuilder.build(
                        scope: selectedGroupScope,
                        items: isSelectedItemScope ? itemState.items : const [],
                        selectedFilter: itemState.selectedFilter,
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                            child: GroupStatusSummary(summary: summary),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: GroupItemFilterChips(
                              summary: summary,
                              onSelected: _itemsStore.selectFilter,
                            ),
                          ),
                          GroupScopedItemList(
                            items: summary.filteredItems,
                            isLoading:
                                itemState.isLoading && isSelectedItemScope,
                            errorMessage: isSelectedItemScope
                                ? itemState.errorMessage
                                : null,
                            emptyMessage: '아직 이 그룹에 등록된 물품이 없습니다.',
                            emptyActionLabel: '그룹에 제품 추가',
                            onEmptyAction: () =>
                                _openScopedAdd(selectedGroupScope),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmptyGroupState extends StatelessWidget {
  const _EmptyGroupState({this.errorMessage});

  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primaryLight2,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.group_outlined,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '아직 연결된 그룹이 없습니다.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '가족이나 룸메이트와 함께 유통기한을 관리하려면 그룹을 만들어 보세요.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (errorMessage?.isNotEmpty == true) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                errorMessage!,
                style: const TextStyle(
                  color: AppColors.danger,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const _CreateGroupDialog(),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('그룹 만들기'),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.isRefreshingMembers,
    required this.isLeavingGroup,
    required this.isUpdatingGroup,
    required this.onRefreshMembers,
    required this.onCopyInviteCode,
    required this.onOpenSettings,
  });

  final BuylogGroup group;
  final bool isRefreshingMembers;
  final bool isLeavingGroup;
  final bool isUpdatingGroup;
  final VoidCallback onRefreshMembers;
  final ValueChanged<String> onCopyInviteCode;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight2,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.home_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  group.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: '그룹 설정',
                onPressed: isLeavingGroup || isUpdatingGroup
                    ? null
                    : onOpenSettings,
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 8, 6, 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '초대 코드: ${group.inviteCode}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: '초대 코드 복사',
                  onPressed: () => onCopyInviteCode(group.inviteCode),
                  icon: const Icon(Icons.copy, size: 18),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  '멤버 ${group.members.length}명',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: '멤버 새로고침',
                onPressed: isRefreshingMembers ? null : onRefreshMembers,
                icon: isRefreshingMembers
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (group.members.isEmpty)
            const Text(
              '아직 등록된 멤버가 없습니다.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            )
          else
            Column(
              children: [
                for (final member in group.members)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _MemberRow(member: member),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member});

  final BuylogGroupMember member;

  @override
  Widget build(BuildContext context) {
    final initial = member.displayName.isNotEmpty
        ? member.displayName.characters.first
        : '?';

    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.primaryLight2,
          foregroundColor: AppColors.primaryDark,
          child: Text(
            initial,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            member.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.text,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: member.role == GroupRole.owner
                ? AppColors.primaryLight2
                : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Text(
            member.role.displayLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: member.role == GroupRole.owner
                  ? AppColors.primaryDark
                  : AppColors.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _LeaveGroupDialog extends StatefulWidget {
  const _LeaveGroupDialog({required this.group});

  final BuylogGroup group;

  @override
  State<_LeaveGroupDialog> createState() => _LeaveGroupDialogState();
}

class _LeaveGroupDialogState extends State<_LeaveGroupDialog> {
  String? _selectedNewOwnerUserId;

  @override
  void initState() {
    super.initState();
    final candidates = widget.group.delegationCandidates(
      SupabaseService.currentUserId,
    );
    _selectedNewOwnerUserId = candidates.isEmpty
        ? null
        : candidates.first.userId;
  }

  Future<void> _submit() async {
    final isOwner = widget.group.isOwner(SupabaseService.currentUserId);
    final candidates = widget.group.delegationCandidates(
      SupabaseService.currentUserId,
    );

    try {
      await GroupStore.instance.leaveGroup(
        groupId: widget.group.id,
        newOwnerUserId: isOwner && candidates.isNotEmpty
            ? _selectedNewOwnerUserId
            : null,
      );

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
    final isOwner = widget.group.isOwner(SupabaseService.currentUserId);
    final candidates = widget.group.delegationCandidates(
      SupabaseService.currentUserId,
    );
    final requiresDelegation = isOwner && candidates.isNotEmpty;

    return ValueListenableBuilder<GroupState>(
      valueListenable: GroupStore.instance,
      builder: (context, state, _) {
        return AlertDialog(
          title: Text(requiresDelegation ? '관리자 위임 후 탈퇴' : '그룹 탈퇴'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('이 그룹에서 나가면 그룹 물품과 멤버 목록을 볼 수 없습니다.'),
              if (requiresDelegation) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedNewOwnerUserId,
                  decoration: const InputDecoration(labelText: '새 관리자'),
                  items: [
                    for (final member in candidates)
                      DropdownMenuItem<String>(
                        value: member.userId,
                        child: Text(member.displayName),
                      ),
                  ],
                  onChanged: state.isLeavingGroup
                      ? null
                      : (value) {
                          setState(() {
                            _selectedNewOwnerUserId = value;
                          });
                        },
                ),
              ],
              if (state.errorMessage?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Text(
                  state.errorMessage!,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: state.isLeavingGroup
                  ? null
                  : () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: state.isLeavingGroup ? null : _submit,
              child: state.isLeavingGroup
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(requiresDelegation ? '위임 후 탈퇴' : '탈퇴'),
            ),
          ],
        );
      },
    );
  }
}

class _CreateGroupDialog extends StatefulWidget {
  const _CreateGroupDialog();

  @override
  State<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<_CreateGroupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (GroupStore.instance.value.isSaving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      await GroupStore.instance.createGroup(_controller.text);
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
    return ValueListenableBuilder<GroupState>(
      valueListenable: GroupStore.instance,
      builder: (context, state, _) {
        return AlertDialog(
          title: const Text('그룹 만들기'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Form(
                key: _formKey,
                child: TextFormField(
                  controller: _controller,
                  autofocus: !state.isSaving,
                  readOnly: state.isSaving,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(labelText: '그룹 이름'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '그룹 이름을 입력해 주세요.';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
              ),
              if (state.errorMessage?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    state.errorMessage!,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: state.isSaving
                  ? null
                  : () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: state.isSaving ? null : _submit,
              child: state.isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('만들기'),
            ),
          ],
        );
      },
    );
  }
}
