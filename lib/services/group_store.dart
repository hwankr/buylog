import 'package:flutter/foundation.dart';

import '../models/group.dart';
import '../models/item_scope.dart';
import 'supabase_service.dart';

class GroupState {
  const GroupState({
    this.group,
    this.groups = const [],
    this.selectedScope = const ItemScope.personal(),
    this.isLoading = false,
    this.isSaving = false,
    this.isRefreshingMembers = false,
    this.errorMessage,
  });

  static const _unset = Object();

  final BuylogGroup? group;
  final List<BuylogGroup> groups;
  final ItemScope selectedScope;
  final bool isLoading;
  final bool isSaving;
  final bool isRefreshingMembers;
  final String? errorMessage;

  List<BuylogGroup> get visibleGroups {
    if (groups.isNotEmpty) return List<BuylogGroup>.unmodifiable(groups);
    final currentGroup = group;
    if (currentGroup == null) return const <BuylogGroup>[];
    return <BuylogGroup>[currentGroup];
  }

  List<ItemScope> get availableScopes {
    return <ItemScope>[
      const ItemScope.personal(),
      for (final group in visibleGroups)
        ItemScope.group(id: group.id, label: group.name),
    ];
  }

  BuylogGroup? groupForScope(ItemScope scope) {
    if (!scope.isGroup) return null;
    for (final group in visibleGroups) {
      if (group.id == scope.id) return group;
    }
    return null;
  }

  GroupState copyWith({
    Object? group = _unset,
    List<BuylogGroup>? groups,
    ItemScope? selectedScope,
    bool? isLoading,
    bool? isSaving,
    bool? isRefreshingMembers,
    Object? errorMessage = _unset,
  }) {
    final nextGroups = groups ?? this.groups;
    final nextGroup = identical(group, _unset)
        ? (nextGroups.isNotEmpty ? nextGroups.first : this.group)
        : group as BuylogGroup?;

    return GroupState(
      group: nextGroup,
      groups: nextGroups,
      selectedScope: selectedScope ?? this.selectedScope,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isRefreshingMembers: isRefreshingMembers ?? this.isRefreshingMembers,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class GroupStore extends ValueNotifier<GroupState> {
  GroupStore._() : super(const GroupState());

  static final GroupStore instance = GroupStore._();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    value = value.copyWith(isLoading: true, errorMessage: null);

    try {
      final groups = await SupabaseService.loadGroupsForUser();
      value = GroupState(
        group: groups.isEmpty ? null : groups.first,
        groups: groups,
      );
    } catch (_) {
      _initialized = false;
      value = value.copyWith(
        isLoading: false,
        errorMessage: '그룹 정보를 불러오지 못했습니다.',
      );
      rethrow;
    }
  }

  Future<void> createGroup(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Group name is required.');
    }

    final previousState = value;
    value = previousState.copyWith(isSaving: true, errorMessage: null);

    try {
      final group = await SupabaseService.createGroup(name: trimmedName);
      final groups = <BuylogGroup>[...previousState.visibleGroups, group];
      value = GroupState(
        group: groups.first,
        groups: groups,
        selectedScope: ItemScope.group(id: group.id, label: group.name),
      );
    } catch (_) {
      value = GroupState(
        group: previousState.group,
        groups: previousState.groups,
        selectedScope: previousState.selectedScope,
        isLoading: previousState.isLoading,
        errorMessage: '그룹을 만들지 못했습니다. 잠시 후 다시 시도해 주세요.',
      );
      rethrow;
    }
  }

  void selectScope(ItemScope scope) {
    final allowed = value.availableScopes.any(
      (candidate) => candidate == scope,
    );
    if (!allowed) return;
    value = value.copyWith(selectedScope: scope, errorMessage: null);
  }

  Future<void> refreshMembers({String? groupId}) async {
    final currentGroup = groupId == null
        ? value.group
        : value.groupForScope(ItemScope.group(id: groupId, label: ''));
    if (currentGroup == null || value.isRefreshingMembers) {
      return;
    }

    final previousState = value;
    value = previousState.copyWith(
      isRefreshingMembers: true,
      errorMessage: null,
    );

    try {
      final members = await SupabaseService.loadGroupMembers(
        groupId: currentGroup.id,
      );
      final updatedGroup = currentGroup.copyWith(members: members);
      final updatedGroups = value.visibleGroups
          .map((group) => group.id == updatedGroup.id ? updatedGroup : group)
          .toList(growable: false);
      value = value.copyWith(
        group: updatedGroups.isEmpty ? null : updatedGroups.first,
        groups: updatedGroups,
        isRefreshingMembers: false,
        errorMessage: null,
      );
    } catch (_) {
      value = previousState.copyWith(
        isRefreshingMembers: false,
        errorMessage: '멤버 목록을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.',
      );
      rethrow;
    }
  }

  @visibleForTesting
  void resetForTesting() {
    _initialized = false;
    value = const GroupState();
  }
}
