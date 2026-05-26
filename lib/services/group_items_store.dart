import 'package:flutter/foundation.dart';

import '../models/item.dart';
import '../models/item_scope.dart';
import 'supabase_service.dart';

class GroupItemsState {
  const GroupItemsState({
    this.scope = const ItemScope.personal(),
    this.items = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  final ItemScope scope;
  final List<ConsumableItem> items;
  final bool isLoading;
  final String? errorMessage;
}

class GroupItemsStore extends ValueNotifier<GroupItemsState> {
  GroupItemsStore() : super(const GroupItemsState());

  int _requestSerial = 0;

  Future<void> load(ItemScope scope) async {
    if (value.isLoading && value.scope == scope) {
      return;
    }

    final request = ++_requestSerial;
    value = GroupItemsState(scope: scope, items: value.items, isLoading: true);

    try {
      final items = await SupabaseService.loadItemsForScope(scope);
      if (request != _requestSerial) return;
      value = GroupItemsState(scope: scope, items: items);
    } catch (_) {
      if (request != _requestSerial) return;
      value = GroupItemsState(scope: scope, errorMessage: '물품 목록을 불러오지 못했습니다.');
    }
  }
}
