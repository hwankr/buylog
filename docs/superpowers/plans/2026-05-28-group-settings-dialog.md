# Group Settings Dialog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 그룹 카드에 바로 노출된 `그룹 탈퇴` 액션을 설정 버튼 뒤의 팝업으로 옮기고, 같은 설정 팝업에서 그룹 이름 변경과 관련 액션을 처리할 수 있게 만든다.

**Architecture:** 그룹 이름 변경은 `SupabaseService`와 `GroupStore`에 추가하고, 위젯은 입력, 확인, 상태 표시만 담당한다. `GroupSettingsDialog`는 독립 위젯으로 분리해 설정 액션이 늘어나도 `GroupScreen`이 더 비대해지지 않게 한다.

**Tech Stack:** Flutter, Dart, `ValueNotifier`, `supabase_flutter`, Supabase RLS, `flutter_test`.

---

## Current Repo Context

- 그룹 화면은 `lib/screens/group_screen.dart`에 있다. `_GroupCard` 안에서 현재 `OutlinedButton.icon(label: Text('그룹 탈퇴'))`가 바로 보이고, 버튼이 `_LeaveGroupDialog`를 연다.
- 그룹 상태와 비즈니스 로직은 `lib/services/group_store.dart`의 `GroupStore`가 관리한다.
- Supabase 접근 계약은 `lib/services/supabase_service.dart`의 `GroupDatabaseGateway`와 `SupabaseGroupDatabaseGateway`에 있다.
- `supabase/migrations/20260526193000_add_group_rls_policies.sql`에 이미 `"Group owners can update groups"` 정책이 있어서, owner의 `groups.name` 수정에는 새 migration이 필요하지 않다.
- `ItemScope` equality는 `type`, `id`, `label`을 모두 비교한다. 그룹 이름 변경 후 선택된 scope label을 같이 갱신하지 않으면 선택 상태가 fallback될 수 있다.
- AGENTS.md 기준상 새 비즈니스 로직에 테스트가 없으면 `[P1]`이다. 서비스, store, widget 테스트를 먼저 작성한다.

## File Structure

- Modify: `lib/services/supabase_service.dart`
  - `SupabaseService.renameGroup()`을 추가한다.
  - `GroupDatabaseGateway.renameGroup()` 계약과 Supabase update 구현을 추가한다.
- Modify: `lib/services/group_store.dart`
  - `GroupState.isUpdatingGroup`을 추가한다.
  - `GroupStore.renameGroup()`에서 trim, blank validation, local state update, selected scope label 갱신, 실패 복구를 처리한다.
- Create: `lib/widgets/group/group_settings_dialog.dart`
  - 설정 팝업 UI를 담당한다.
  - 그룹 이름 편집, 초대 코드 복사, 멤버 새로고침, 그룹 탈퇴 액션을 한 팝업 안에 둔다.
- Modify: `lib/screens/group_screen.dart`
  - `_GroupCard`의 직접 탈퇴 버튼을 설정 아이콘 버튼으로 교체한다.
  - `_openGroupSettings()`를 추가해 settings dialog와 기존 `_LeaveGroupDialog`를 연결한다.
- Modify: `test/services/supabase_service_test.dart`
  - rename service trim, blank validation, gateway 호출을 검증한다.
- Modify: `test/services/group_store_test.dart`
  - rename 성공 시 그룹 목록과 selected scope label이 같이 바뀌는지 검증한다.
  - rename 실패 시 이전 상태 복구와 한국어 오류 메시지를 검증한다.
- Modify: `test/screens/group_screen_test.dart`
  - `그룹 탈퇴`가 카드에 바로 보이지 않고 설정 팝업 안에서만 보이는지 검증한다.
  - 설정 팝업에서 탈퇴 dialog로 이어지는 흐름과 그룹 이름 변경 UI를 검증한다.

---

### Task 1: Add Rename Contract to SupabaseService

**Files:**
- Modify: `test/services/supabase_service_test.dart`
- Modify: `lib/services/supabase_service.dart`
- Touch fakes as needed: `test/services/group_store_test.dart`, `test/screens/group_screen_test.dart`

- [ ] **Step 1: Write failing service tests**

Add these fields to `_RecordingGroupDatabaseGateway` in `test/services/supabase_service_test.dart`:

```dart
  int renameGroupCalls = 0;
  String? renameGroupGroupId;
  String? renameGroupName;
```

Add this method to the same fake gateway:

```dart
  @override
  Future<Map<String, dynamic>> renameGroup({
    required String groupId,
    required String name,
  }) async {
    renameGroupCalls += 1;
    renameGroupGroupId = groupId;
    renameGroupName = name;
    return <String, dynamic>{
      'id': groupId,
      'name': name,
      'invite_code': 'BUY-ABC123',
      'created_by': SupabaseService.currentUserId,
      'created_at': '2026-05-26T00:00:00.000Z',
      'group_members': <Map<String, dynamic>>[],
    };
  }
```

Add this test group after `SupabaseService.createGroup`:

```dart
  group('SupabaseService.renameGroup', () {
    tearDown(() {
      SupabaseService.debugGroupDatabaseGateway = null;
    });

    test('trims group id and name before gateway update', () async {
      final gateway = _RecordingGroupDatabaseGateway();
      SupabaseService.debugGroupDatabaseGateway = gateway;

      final group = await SupabaseService.renameGroup(
        groupId: ' group-1 ',
        name: '  새 가족  ',
      );

      expect(gateway.renameGroupCalls, 1);
      expect(gateway.renameGroupGroupId, 'group-1');
      expect(gateway.renameGroupName, '새 가족');
      expect(group.id, 'group-1');
      expect(group.name, '새 가족');
    });

    test('rejects blank group ids without calling gateway', () async {
      final gateway = _RecordingGroupDatabaseGateway();
      SupabaseService.debugGroupDatabaseGateway = gateway;

      await expectLater(
        SupabaseService.renameGroup(groupId: '   ', name: '새 가족'),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'Group id is required.',
          ),
        ),
      );

      expect(gateway.renameGroupCalls, 0);
    });

    test('rejects blank names without calling gateway', () async {
      final gateway = _RecordingGroupDatabaseGateway();
      SupabaseService.debugGroupDatabaseGateway = gateway;

      await expectLater(
        SupabaseService.renameGroup(groupId: 'group-1', name: '   '),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'Group name is required.',
          ),
        ),
      );

      expect(gateway.renameGroupCalls, 0);
    });
  });
```

- [ ] **Step 2: Run the service test and verify it fails**

Run:

```powershell
flutter test test/services/supabase_service_test.dart
```

Expected: FAIL with compile errors for `renameGroup`.

- [ ] **Step 3: Add `SupabaseService.renameGroup()`**

Add this method after `createGroup()` in `lib/services/supabase_service.dart`:

```dart
  static Future<BuylogGroup> renameGroup({
    required String groupId,
    required String name,
  }) async {
    final trimmedGroupId = groupId.trim();
    if (trimmedGroupId.isEmpty) {
      throw ArgumentError.value(groupId, 'groupId', 'Group id is required.');
    }

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Group name is required.');
    }

    final updatedGroup = await _groupDatabaseGateway.renameGroup(
      groupId: trimmedGroupId,
      name: trimmedName,
    );
    return BuylogGroup.fromSupabase(updatedGroup);
  }
```

- [ ] **Step 4: Extend the group gateway contract**

Add this method to `abstract class GroupDatabaseGateway`:

```dart
  Future<Map<String, dynamic>> renameGroup({
    required String groupId,
    required String name,
  });
```

Add this method to `SupabaseGroupDatabaseGateway`:

```dart
  @override
  Future<Map<String, dynamic>> renameGroup({
    required String groupId,
    required String name,
  }) async {
    final row = await _client
        .from('groups')
        .update({'name': name})
        .eq('id', groupId)
        .select(_groupProjection)
        .single();
    return Map<String, dynamic>.from(row);
  }
```

- [ ] **Step 5: Update other fake gateways for the new interface**

Add this method to `_RecordingGroupDatabaseGateway` in `test/services/group_store_test.dart`:

```dart
  @override
  Future<Map<String, dynamic>> renameGroup({
    required String groupId,
    required String name,
  }) async {
    return _groupRow(id: groupId, name: name);
  }
```

Add this method to `_FakeGroupDatabaseGateway` in `test/screens/group_screen_test.dart`:

```dart
  @override
  Future<Map<String, dynamic>> renameGroup({
    required String groupId,
    required String name,
  }) async {
    return _groupRow(id: groupId, name: name);
  }
```

- [ ] **Step 6: Run focused service tests**

Run:

```powershell
flutter test test/services/supabase_service_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit**

Run:

```powershell
git add lib/services/supabase_service.dart test/services/supabase_service_test.dart test/services/group_store_test.dart test/screens/group_screen_test.dart
git commit -m "feat: add group rename service"
```

Expected: commit succeeds with the service contract and fake updates.

---

### Task 2: Add Rename State and Behavior to GroupStore

**Files:**
- Modify: `test/services/group_store_test.dart`
- Modify: `lib/services/group_store.dart`

- [ ] **Step 1: Write failing store tests**

Extend `_RecordingGroupDatabaseGateway` in `test/services/group_store_test.dart`:

```dart
  int renameGroupCalls = 0;
  String? renameGroupGroupId;
  String? renameGroupName;
  Object? renameGroupError;
```

Replace the temporary `renameGroup` fake method from Task 1 with:

```dart
  @override
  Future<Map<String, dynamic>> renameGroup({
    required String groupId,
    required String name,
  }) async {
    renameGroupCalls += 1;
    renameGroupGroupId = groupId;
    renameGroupName = name;
    if (renameGroupError != null) {
      throw renameGroupError!;
    }
    return _groupRow(id: groupId, name: name);
  }
```

Add these tests inside the existing `GroupStore` group:

```dart
    test('renames selected group and updates selected scope label', () async {
      gateway.loadGroupsForUserResult = <Map<String, dynamic>>[
        _groupRow(id: 'group-1', name: '우리 가족'),
        _groupRow(id: 'group-2', name: '사무실'),
      ];
      await GroupStore.instance.initialize();
      GroupStore.instance.selectScope(
        const ItemScope.group(id: 'group-1', label: '우리 가족'),
      );

      await GroupStore.instance.renameGroup(
        groupId: ' group-1 ',
        name: '  새 가족  ',
      );

      expect(gateway.renameGroupCalls, 1);
      expect(gateway.renameGroupGroupId, 'group-1');
      expect(gateway.renameGroupName, '새 가족');
      expect(GroupStore.instance.value.groups.first.name, '새 가족');
      expect(
        GroupStore.instance.value.selectedScope,
        const ItemScope.group(id: 'group-1', label: '새 가족'),
      );
      expect(GroupStore.instance.value.isUpdatingGroup, isFalse);
      expect(GroupStore.instance.value.errorMessage, isNull);
    });

    test('keeps previous group state when rename fails', () async {
      gateway.loadGroupsForUserResult = <Map<String, dynamic>>[
        _groupRow(id: 'group-1', name: '우리 가족'),
      ];
      await GroupStore.instance.initialize();
      gateway.renameGroupError = StateError('rename failed');

      await expectLater(
        GroupStore.instance.renameGroup(groupId: 'group-1', name: '새 가족'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'rename failed',
          ),
        ),
      );

      expect(GroupStore.instance.value.groups.single.name, '우리 가족');
      expect(GroupStore.instance.value.isUpdatingGroup, isFalse);
      expect(
        GroupStore.instance.value.errorMessage,
        '그룹 이름을 변경하지 못했습니다. 잠시 후 다시 시도해 주세요.',
      );
    });

    test('rejects blank rename values before gateway call', () async {
      gateway.loadGroupsForUserResult = <Map<String, dynamic>>[
        _groupRow(id: 'group-1', name: '우리 가족'),
      ];
      await GroupStore.instance.initialize();

      await expectLater(
        GroupStore.instance.renameGroup(groupId: 'group-1', name: '   '),
        throwsA(isA<ArgumentError>()),
      );

      expect(gateway.renameGroupCalls, 0);
      expect(GroupStore.instance.value.groups.single.name, '우리 가족');
    });
```

- [ ] **Step 2: Run store tests and verify they fail**

Run:

```powershell
flutter test test/services/group_store_test.dart
```

Expected: FAIL with compile errors for `isUpdatingGroup` and `renameGroup`.

- [ ] **Step 3: Add `isUpdatingGroup` to `GroupState`**

Update `GroupState` in `lib/services/group_store.dart`:

```dart
  const GroupState({
    this.group,
    this.groups = const [],
    this.selectedScope = const ItemScope.personal(),
    this.isLoading = false,
    this.isSaving = false,
    this.isRefreshingMembers = false,
    this.isLeavingGroup = false,
    this.isUpdatingGroup = false,
    this.errorMessage,
  });
```

Add the field:

```dart
  final bool isUpdatingGroup;
```

Add the `copyWith` parameter:

```dart
    bool? isUpdatingGroup,
```

Set it in the returned `GroupState`:

```dart
      isUpdatingGroup: isUpdatingGroup ?? this.isUpdatingGroup,
```

- [ ] **Step 4: Add `GroupStore.renameGroup()`**

Add this method after `createGroup()` in `lib/services/group_store.dart`:

```dart
  Future<void> renameGroup({
    required String groupId,
    required String name,
  }) async {
    final trimmedGroupId = groupId.trim();
    if (trimmedGroupId.isEmpty) {
      throw ArgumentError.value(groupId, 'groupId', 'Group id is required.');
    }

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Group name is required.');
    }

    final previousState = value;
    final currentGroup = previousState.groupForScope(
      ItemScope.group(id: trimmedGroupId, label: ''),
    );
    if (currentGroup?.name == trimmedName || value.isUpdatingGroup) {
      return;
    }

    value = previousState.copyWith(isUpdatingGroup: true, errorMessage: null);

    try {
      final updatedGroup = await SupabaseService.renameGroup(
        groupId: trimmedGroupId,
        name: trimmedName,
      );
      final updatedGroups = previousState.visibleGroups
          .map((group) => group.id == updatedGroup.id ? updatedGroup : group)
          .toList(growable: false);
      final selectedScope =
          previousState.selectedScope.isGroup &&
              previousState.selectedScope.id == updatedGroup.id
          ? ItemScope.group(id: updatedGroup.id, label: updatedGroup.name)
          : previousState.selectedScope;

      value = GroupState(
        group: updatedGroups.isEmpty ? null : updatedGroups.first,
        groups: updatedGroups,
        selectedScope: selectedScope,
      );
    } catch (_) {
      value = previousState.copyWith(
        isUpdatingGroup: false,
        errorMessage: '그룹 이름을 변경하지 못했습니다. 잠시 후 다시 시도해 주세요.',
      );
      rethrow;
    }
  }
```

- [ ] **Step 5: Run store tests**

Run:

```powershell
flutter test test/services/group_store_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

Run:

```powershell
git add lib/services/group_store.dart test/services/group_store_test.dart
git commit -m "feat: rename group from store"
```

Expected: commit succeeds with store behavior and tests.

---

### Task 3: Create the Group Settings Dialog Widget

**Files:**
- Create: `lib/widgets/group/group_settings_dialog.dart`

- [ ] **Step 1: Create the settings dialog widget**

Create `lib/widgets/group/group_settings_dialog.dart`:

```dart
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
                decoration: InputDecoration(
                  labelText: '그룹 이름',
                  helperText: widget.canRenameGroup
                      ? '그룹 목록과 물품 목록 제목에 표시됩니다.'
                      : '관리자만 그룹 이름을 변경할 수 있습니다.',
                ),
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
              value: '최신 멤버 목록을 다시 불러옵니다.',
              onPressed:
                  widget.isRefreshingMembers ? null : widget.onRefreshMembers,
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
          onPressed:
              widget.canRenameGroup && !widget.isUpdatingGroup ? _submitName : null,
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
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Format the new widget**

Run:

```powershell
dart format lib\widgets\group\group_settings_dialog.dart
```

Expected: formatter completes without parse errors.

- [ ] **Step 3: Commit**

Run:

```powershell
git add lib/widgets/group/group_settings_dialog.dart
git commit -m "feat: add group settings dialog"
```

Expected: commit succeeds with only the new widget.

---

### Task 4: Wire Settings Dialog into GroupScreen

**Files:**
- Modify: `test/screens/group_screen_test.dart`
- Modify: `lib/screens/group_screen.dart`

- [ ] **Step 1: Update widget tests for settings entry**

In `test/screens/group_screen_test.dart`, update existing leave tests so they open settings first:

```dart
    await tester.tap(find.byTooltip('그룹 설정'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('그룹 탈퇴'));
    await tester.pumpAndSettle();
```

Add this widget test near the current group card tests:

```dart
  testWidgets('group leave action is only shown inside settings dialog', (
    tester,
  ) async {
    GroupStore.instance.value = GroupState(
      groups: <BuylogGroup>[_group()],
      selectedScope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
    );

    await tester.pumpWidget(_wrap());

    expect(find.text('그룹 탈퇴'), findsNothing);
    expect(find.byTooltip('그룹 설정'), findsOneWidget);

    await tester.tap(find.byTooltip('그룹 설정'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('그룹 설정'), findsOneWidget);
    expect(find.text('그룹 탈퇴'), findsOneWidget);
  });
```

Add this widget test for rename:

```dart
  testWidgets('owner renames group from settings dialog', (tester) async {
    final gateway = _FakeGroupDatabaseGateway();
    SupabaseService.debugGroupDatabaseGateway = gateway;
    GroupStore.instance.value = GroupState(
      groups: <BuylogGroup>[_group()],
      selectedScope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
    );

    await tester.pumpWidget(_wrap());
    await tester.tap(find.byTooltip('그룹 설정'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('group-settings-name-field')),
      '새 가족',
    );
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(gateway.renameGroupCalls, 1);
    expect(gateway.renameGroupGroupId, 'group-1');
    expect(gateway.renameGroupName, '새 가족');
    expect(GroupStore.instance.value.selectedScope.label, '새 가족');
    expect(find.text('새 가족'), findsAtLeastNWidgets(1));
  });
```

Extend `_FakeGroupDatabaseGateway`:

```dart
  int renameGroupCalls = 0;
  String? renameGroupGroupId;
  String? renameGroupName;
```

Replace the temporary `renameGroup` fake method with:

```dart
  @override
  Future<Map<String, dynamic>> renameGroup({
    required String groupId,
    required String name,
  }) async {
    renameGroupCalls += 1;
    renameGroupGroupId = groupId;
    renameGroupName = name;
    final group = _groupRow(id: groupId, name: name);
    _currentGroup = group;
    return group;
  }
```

- [ ] **Step 2: Run widget tests and verify they fail**

Run:

```powershell
flutter test test/screens/group_screen_test.dart
```

Expected: FAIL because the settings tooltip and dialog are not wired yet.

- [ ] **Step 3: Import the settings dialog**

Add this import to `lib/screens/group_screen.dart`:

```dart
import '../widgets/group/group_settings_dialog.dart';
```

- [ ] **Step 4: Add `_openGroupSettings()` to `_GroupScreenState`**

Add this method after `_openScopedAdd()`:

```dart
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
              onRefreshMembers: () => GroupStore.instance.refreshMembers(
                groupId: currentGroup.id,
              ),
              onLeaveGroup: () {
                Navigator.of(dialogContext).pop();
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
```

- [ ] **Step 5: Pass settings state into `_GroupCard`**

Update the `_GroupCard` construction:

```dart
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
```

Update `_GroupCard` constructor and fields:

```dart
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
```

- [ ] **Step 6: Replace the direct leave button with a settings icon**

In `_GroupCard.build()`, update the title row by adding the icon button after the expanded group name:

```dart
              IconButton(
                tooltip: '그룹 설정',
                onPressed:
                    isLeavingGroup || isUpdatingGroup ? null : onOpenSettings,
                icon: const Icon(Icons.settings_outlined),
              ),
```

Remove the existing `Align` block that renders:

```dart
              label: const Text('그룹 탈퇴'),
```

Keep `_LeaveGroupDialog` unchanged except for any test-driven wording changes already present.

- [ ] **Step 7: Run widget tests**

Run:

```powershell
flutter test test/screens/group_screen_test.dart
```

Expected: PASS.

- [ ] **Step 8: Commit**

Run:

```powershell
git add lib/screens/group_screen.dart lib/widgets/group/group_settings_dialog.dart test/screens/group_screen_test.dart
git commit -m "feat: move group actions into settings"
```

Expected: commit succeeds with UI wiring and widget tests.

---

### Task 5: Verify the Whole Change

**Files:**
- Verify: `lib/services/supabase_service.dart`
- Verify: `lib/services/group_store.dart`
- Verify: `lib/screens/group_screen.dart`
- Verify: `lib/widgets/group/group_settings_dialog.dart`
- Verify: `test/services/supabase_service_test.dart`
- Verify: `test/services/group_store_test.dart`
- Verify: `test/screens/group_screen_test.dart`

- [ ] **Step 1: Format changed Dart files**

Run:

```powershell
dart format lib\services\supabase_service.dart lib\services\group_store.dart lib\screens\group_screen.dart lib\widgets\group\group_settings_dialog.dart test\services\supabase_service_test.dart test\services\group_store_test.dart test\screens\group_screen_test.dart
```

Expected: formatter completes without parse errors.

- [ ] **Step 2: Run focused tests**

Run:

```powershell
flutter test test/services/supabase_service_test.dart test/services/group_store_test.dart test/screens/group_screen_test.dart
```

Expected: PASS for service, store, and group screen tests.

- [ ] **Step 3: Run analyzer**

Run:

```powershell
flutter analyze --no-fatal-infos
```

Expected: exits 0.

- [ ] **Step 4: Run full test suite**

Run:

```powershell
flutter test
```

Expected: PASS for the full Flutter test suite.

- [ ] **Step 5: Review final diff**

Run:

```powershell
git diff -- lib\services\supabase_service.dart lib\services\group_store.dart lib\screens\group_screen.dart lib\widgets\group\group_settings_dialog.dart test\services\supabase_service_test.dart test\services\group_store_test.dart test\screens\group_screen_test.dart
```

Expected: diff only contains group rename service/store logic, settings dialog UI, direct leave button removal, updated widget flows, and tests.

---

## Self-Review

- Spec coverage: 직접 노출된 `그룹 탈퇴`는 설정 아이콘 뒤로 이동한다. 설정 팝업에서 그룹 이름 변경, 초대 코드 복사, 멤버 새로고침, 그룹 탈퇴를 처리한다.
- Placeholder scan: 파일 경로, 테스트 코드, 구현 코드, 실행 명령, expected result가 구체적으로 들어 있다.
- Type consistency: `renameGroup`, `isUpdatingGroup`, `GroupSettingsDialog`, `onRenameGroup`, `onOpenSettings` 이름을 테스트와 구현에서 동일하게 사용한다.
- Boundary check: Supabase update와 로컬 상태 갱신은 service/store에 있고, widget은 입력 검증과 콜백 호출만 맡는다.
- Migration check: 기존 RLS의 `"Group owners can update groups"` 정책을 사용하므로 새 SQL migration은 계획하지 않는다.
