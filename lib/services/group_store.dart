import 'package:flutter/foundation.dart';

import '../models/group.dart';
import 'supabase_service.dart';

class GroupState {
  const GroupState({
    this.group,
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
  });

  static const _unset = Object();

  final BuylogGroup? group;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  GroupState copyWith({
    Object? group = _unset,
    bool? isLoading,
    bool? isSaving,
    Object? errorMessage = _unset,
  }) {
    return GroupState(
      group: identical(group, _unset) ? this.group : group as BuylogGroup?,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
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
      final group = await SupabaseService.loadDefaultGroup();
      value = GroupState(group: group);
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
      value = GroupState(group: group);
    } catch (_) {
      value = GroupState(
        group: previousState.group,
        isLoading: previousState.isLoading,
        errorMessage: '그룹을 만들지 못했습니다. 잠시 후 다시 시도해 주세요.',
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
