import 'package:flutter/foundation.dart';

import '../models/item.dart';
import '../models/item_scope.dart';
import 'group_dashboard_summary.dart';
import 'supabase_service.dart';

class GroupItemsState {
  const GroupItemsState({
    this.scope = const ItemScope.personal(),
    this.items = const [],
    this.selectedFilter = GroupItemFilter.all,
    this.isLoading = false,
    this.errorMessage,
  });

  final ItemScope scope;
  final List<ConsumableItem> items;
  final GroupItemFilter selectedFilter;
  final bool isLoading;
  final String? errorMessage;

  GroupItemsState copyWith({
    ItemScope? scope,
    List<ConsumableItem>? items,
    GroupItemFilter? selectedFilter,
    bool? isLoading,
    String? errorMessage,
  }) {
    return GroupItemsState(
      scope: scope ?? this.scope,
      items: items ?? this.items,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class GroupItemsStore extends ValueNotifier<GroupItemsState> {
  GroupItemsStore() : super(const GroupItemsState());

  int _requestSerial = 0;

  Future<void> load(ItemScope scope) async {
    if (value.isLoading && value.scope == scope) {
      return;
    }

    final request = ++_requestSerial;
    final selectedFilter = value.scope == scope
        ? value.selectedFilter
        : GroupItemFilter.all;
    value = GroupItemsState(
      scope: scope,
      items: value.items,
      selectedFilter: selectedFilter,
      isLoading: true,
    );

    try {
      final items = await SupabaseService.loadItemsForScope(scope);
      if (request != _requestSerial) return;
      value = GroupItemsState(
        scope: scope,
        items: items,
        selectedFilter: selectedFilter,
      );
    } catch (_) {
      if (request != _requestSerial) return;
      value = GroupItemsState(
        scope: scope,
        selectedFilter: selectedFilter,
        errorMessage: '물품 목록을 불러오지 못했습니다.',
      );
    }
  }

  void selectFilter(GroupItemFilter filter) {
    if (value.selectedFilter == filter) return;
    value = value.copyWith(selectedFilter: filter, errorMessage: null);
  }
}
