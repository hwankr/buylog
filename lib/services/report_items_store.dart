import 'package:flutter/foundation.dart';

import '../models/item.dart';
import '../models/item_scope.dart';
import 'supabase_service.dart';

class ReportItemsState {
  const ReportItemsState({
    this.scope = const ItemScope.personal(),
    this.items = const <ConsumableItem>[],
    this.isLoading = false,
    this.errorMessage,
  });

  final ItemScope scope;
  final List<ConsumableItem> items;
  final bool isLoading;
  final String? errorMessage;
}

class ReportItemsStore extends ValueNotifier<ReportItemsState> {
  ReportItemsStore() : super(const ReportItemsState());

  int _requestSerial = 0;

  Future<void> load(ItemScope scope) async {
    if (value.isLoading && value.scope.storageKey == scope.storageKey) {
      return;
    }

    final request = ++_requestSerial;
    value = ReportItemsState(
      scope: scope,
      items: value.scope.storageKey == scope.storageKey
          ? value.items
          : const <ConsumableItem>[],
      isLoading: true,
    );

    try {
      final items = await SupabaseService.loadItemsForScope(scope);
      if (request != _requestSerial) return;
      value = ReportItemsState(scope: scope, items: items);
    } catch (_) {
      if (request != _requestSerial) return;
      value = ReportItemsState(
        scope: scope,
        items: const <ConsumableItem>[],
        errorMessage: '리포트 데이터를 불러오지 못했습니다.',
      );
    }
  }
}
