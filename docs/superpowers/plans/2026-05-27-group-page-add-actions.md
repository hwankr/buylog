# Group Page Add Actions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 그룹 페이지에서 선택된 그룹에 물품을 바로 추가하고, 이미 그룹이 있는 상태에서도 새 그룹을 만들 수 있는 명확한 진입점을 제공한다.

**Architecture:** 그룹 생성과 물품 저장의 비즈니스 로직은 기존 `GroupStore`, `ItemStore`, `SupabaseService`에 그대로 둔다. `GroupScreen`은 선택된 `ItemScope`를 화면 액션에 연결하고, 새 `GroupQuickActions` 위젯은 콜백만 받는 순수 UI로 만든다. 등록/스캔 화면에는 현재 그룹 대상 배너를 표시해서 사용자가 어느 그룹에 추가하는지 확인할 수 있게 한다.

**Tech Stack:** Flutter, Dart, `ValueNotifier`, `flutter_test`, existing Supabase gateway test seams.

---

## Current Repo Context

- `lib/screens/group_screen.dart` already has `_openScopedAdd(ItemScope scope)` but it is only connected to the empty item list CTA.
- `_CreateGroupDialog` already exists in `lib/screens/group_screen.dart`, but the visible create entry point is only `_EmptyGroupState`, so users with an existing group cannot discover adding another group.
- `lib/main.dart` keeps a global FAB for adding items, including on the group tab when a group is selected. This can stay as a fallback, but the group page needs explicit in-page actions.
- `lib/screens/add_item_screen.dart` and `lib/screens/scan_screen.dart` already accept `targetScope`, so wiring should pass the selected group scope rather than adding storage logic to widgets.
- `AGENTS.md` treats business logic inside Flutter widgets as a P1 issue. This plan keeps persistence, ownership, and selected group behavior in services/stores and adds only UI callbacks to widgets.

## File Structure

- Create: `lib/widgets/group/group_quick_actions.dart`
  - Renders the in-page action controls: manual item add, receipt scan, and group add.
  - Takes callbacks only; no store reads and no persistence.
- Create: `test/widgets/group/group_quick_actions_test.dart`
  - Verifies labels render and each callback is invoked.
- Modify: `lib/screens/group_screen.dart`
  - Adds scan navigation helper.
  - Adds create-group dialog helper for non-empty group states.
  - Renders `GroupQuickActions` when `selectedGroupScope` exists.
- Modify: `test/screens/group_screen_test.dart`
  - Verifies the group page exposes the new actions.
  - Verifies manual add saves using the selected group id.
  - Verifies scan action opens `ScanScreen`.
  - Verifies additional group creation is reachable when a group already exists.
- Modify: `test/services/group_store_test.dart`
  - Adds a regression test for appending a new group and selecting it.
- Modify: `lib/screens/add_item_screen.dart`
  - Shows a compact target-group banner for group scoped registration.
- Modify: `test/screens/add_item_screen_test.dart`
  - Verifies the banner appears for group scope.
- Modify: `lib/screens/scan_screen.dart`
  - Shows a compact target-group banner on scan entry.
- Create: `test/screens/scan_screen_test.dart`
  - Verifies the scan banner appears for group scope.
- Modify: `test/widget_test.dart`
  - Keep existing global FAB expectations unchanged unless product review decides to remove the group-tab FAB later.

---

### Task 1: Protect Additional Group Creation State

**Files:**
- Modify: `test/services/group_store_test.dart`

- [ ] **Step 1: Add the failing regression test**

Add this test inside the existing `group('GroupStore', () { ... })` block, after the current `creates a group and exposes it through state` test:

```dart
test('createGroup appends a new group and selects it when groups already exist', () async {
  GroupStore.instance.value = GroupState(
    groups: <BuylogGroup>[_groupWithMembers()],
    selectedScope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
  );
  gateway.nextCreatedGroupId = 'group-2';

  await GroupStore.instance.createGroup('사무실');

  expect(GroupStore.instance.value.groups.map((group) => group.name), [
    '우리 가족',
    '사무실',
  ]);
  expect(
    GroupStore.instance.value.selectedScope,
    const ItemScope.group(id: 'group-2', label: '사무실'),
  );
  expect(
    GroupStore.instance.value.selectedGroupScope,
    const ItemScope.group(id: 'group-2', label: '사무실'),
  );
});
```

- [ ] **Step 2: Run the focused test and confirm it fails**

Run:

```powershell
flutter test test/services/group_store_test.dart
```

Expected: FAIL because `_RecordingGroupDatabaseGateway.nextCreatedGroupId` does not exist.

- [ ] **Step 3: Extend the group gateway fake**

In `test/services/group_store_test.dart`, add this field to `_RecordingGroupDatabaseGateway`:

```dart
String nextCreatedGroupId = 'group-1';
```

Then change `createGroupWithOwner` to use it:

```dart
@override
Future<Map<String, dynamic>> createGroupWithOwner({
  required String name,
  required String inviteCode,
}) async {
  if (createGroupWithOwnerError != null) {
    throw createGroupWithOwnerError!;
  }

  createdGroupValues = <String, dynamic>{
    'name': name,
    'invite_code': inviteCode,
  };
  return <String, dynamic>{
    'id': nextCreatedGroupId,
    'name': name,
    'invite_code': inviteCode,
    'created_by': SupabaseService.currentUserId,
    'created_at': '2026-05-26T00:00:00.000Z',
    'group_members': <Map<String, dynamic>>[],
  };
}
```

- [ ] **Step 4: Run the focused test and confirm it passes**

Run:

```powershell
flutter test test/services/group_store_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add test/services/group_store_test.dart
git commit -m "test: cover adding another group"
```

---

### Task 2: Add a Pure Group Quick Actions Widget

**Files:**
- Create: `lib/widgets/group/group_quick_actions.dart`
- Create: `test/widgets/group/group_quick_actions_test.dart`

- [ ] **Step 1: Write the widget tests**

Create `test/widgets/group/group_quick_actions_test.dart`:

```dart
import 'package:buylog/theme/app_theme.dart';
import 'package:buylog/widgets/group/group_quick_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders group page quick actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: GroupQuickActions(
            onAddItem: () {},
            onScanReceipt: () {},
            onCreateGroup: () {},
          ),
        ),
      ),
    );

    expect(find.text('물품 추가'), findsOneWidget);
    expect(find.text('영수증 스캔'), findsOneWidget);
    expect(find.text('그룹 추가'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsWidgets);
    expect(find.byIcon(Icons.document_scanner_outlined), findsOneWidget);
    expect(find.byIcon(Icons.group_add_outlined), findsOneWidget);
  });

  testWidgets('invokes each quick action callback', (tester) async {
    var addItemCalls = 0;
    var scanCalls = 0;
    var createGroupCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: GroupQuickActions(
            onAddItem: () => addItemCalls += 1,
            onScanReceipt: () => scanCalls += 1,
            onCreateGroup: () => createGroupCalls += 1,
          ),
        ),
      ),
    );

    await tester.tap(find.text('물품 추가'));
    await tester.tap(find.text('영수증 스캔'));
    await tester.tap(find.text('그룹 추가'));

    expect(addItemCalls, 1);
    expect(scanCalls, 1);
    expect(createGroupCalls, 1);
  });

  testWidgets('disables group creation while the store is saving', (tester) async {
    var createGroupCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: GroupQuickActions(
            onAddItem: () {},
            onScanReceipt: () {},
            onCreateGroup: () => createGroupCalls += 1,
            isCreateGroupDisabled: true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('그룹 추가'));

    expect(createGroupCalls, 0);
  });
}
```

- [ ] **Step 2: Run the focused test and confirm it fails**

Run:

```powershell
flutter test test/widgets/group/group_quick_actions_test.dart
```

Expected: FAIL because `GroupQuickActions` does not exist.

- [ ] **Step 3: Implement the widget**

Create `lib/widgets/group/group_quick_actions.dart`:

```dart
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
```

- [ ] **Step 4: Run the focused test and confirm it passes**

Run:

```powershell
flutter test test/widgets/group/group_quick_actions_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add lib/widgets/group/group_quick_actions.dart test/widgets/group/group_quick_actions_test.dart
git commit -m "feat: add group quick actions"
```

---

### Task 3: Wire Quick Actions Into GroupScreen

**Files:**
- Modify: `lib/screens/group_screen.dart`
- Modify: `test/screens/group_screen_test.dart`

- [ ] **Step 1: Add GroupScreen action tests and test support**

In `test/screens/group_screen_test.dart`, add these imports:

```dart
import 'package:buylog/screens/add_item_screen.dart';
import 'package:buylog/screens/scan_screen.dart';
```

Extend `_RecordingItemDatabaseGateway` with save recording:

```dart
Map<String, dynamic>? upsertedItemPayload;

@override
Future<void> upsertItem(Map<String, dynamic> payload) async {
  upsertedItemPayload = Map<String, dynamic>.from(payload);
}
```

Extend `_FakeGroupDatabaseGateway` with a deterministic next group id:

```dart
String nextCreatedGroupId = 'group-1';
```

Then change `_FakeGroupDatabaseGateway.createGroupWithOwner` so it passes that id:

```dart
final group = _groupRow(
  id: nextCreatedGroupId,
  name: name,
  inviteCode: inviteCode,
);
```

Add these tests before the final `empty group item list shows add CTA` test:

```dart
testWidgets('existing group page exposes in-page add actions', (tester) async {
  GroupStore.instance.value = GroupState(
    groups: <BuylogGroup>[_group()],
    selectedScope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
  );

  await tester.pumpWidget(_wrap());
  await tester.pump();

  expect(find.text('물품 추가'), findsOneWidget);
  expect(find.text('영수증 스캔'), findsOneWidget);
  expect(find.text('그룹 추가'), findsOneWidget);
});

testWidgets('manual group page add saves with the selected group id', (
  tester,
) async {
  final itemGateway = _RecordingItemDatabaseGateway();
  SupabaseService.debugItemDatabaseGateway = itemGateway;
  GroupStore.instance.value = GroupState(
    groups: <BuylogGroup>[_group()],
    selectedScope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
  );

  await tester.pumpWidget(_wrap());
  await tester.pump();
  await tester.tap(find.text('물품 추가'));
  await tester.pumpAndSettle();

  expect(find.byType(AddItemScreen), findsOneWidget);

  await tester.enterText(find.byType(TextFormField).at(0), '세제');
  await tester.enterText(find.byType(TextFormField).at(1), '브랜드');
  await tester.enterText(find.byType(TextFormField).at(2), '30');
  await tester.enterText(find.byType(TextFormField).at(3), '8900');
  await tester.enterText(find.byType(TextFormField).at(4), '마트');
  await tester.tap(find.text('등록 완료'));
  await tester.pumpAndSettle();

  expect(itemGateway.upsertedItemPayload?['group_id'], 'group-1');
  expect(itemGateway.upsertedItemPayload?['user_id'], isNull);
});

testWidgets('scan group page action opens ScanScreen', (tester) async {
  GroupStore.instance.value = GroupState(
    groups: <BuylogGroup>[_group()],
    selectedScope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
  );

  await tester.pumpWidget(_wrap());
  await tester.pump();
  await tester.tap(find.text('영수증 스캔'));
  await tester.pumpAndSettle();

  expect(find.byType(ScanScreen), findsOneWidget);
});

testWidgets('group add action creates another group from non-empty state', (
  tester,
) async {
  final gateway = _FakeGroupDatabaseGateway()
    ..nextCreatedGroupId = 'group-2';
  SupabaseService.debugGroupDatabaseGateway = gateway;
  GroupStore.instance.value = GroupState(
    groups: <BuylogGroup>[_group(id: 'group-1', name: '우리 가족')],
    selectedScope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
  );

  await tester.pumpWidget(_wrap());
  await tester.pump();
  await tester.tap(find.text('그룹 추가'));
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextFormField), '사무실');
  await tester.tap(find.text('만들기'));
  await tester.pump();
  await tester.pumpAndSettle();

  expect(gateway.createGroupWithOwnerCalls, 1);
  expect(gateway.createdGroupValues?['name'], '사무실');
  expect(GroupStore.instance.value.groups.map((group) => group.name), [
    '우리 가족',
    '사무실',
  ]);
  expect(
    GroupStore.instance.value.selectedScope,
    const ItemScope.group(id: 'group-2', label: '사무실'),
  );
});
```

- [ ] **Step 2: Run the focused test and confirm it fails**

Run:

```powershell
flutter test test/screens/group_screen_test.dart
```

Expected: FAIL because `GroupScreen` does not render `물품 추가`, `영수증 스캔`, or `그룹 추가` for an existing group.

- [ ] **Step 3: Add navigation helpers to GroupScreen**

In `lib/screens/group_screen.dart`, add imports:

```dart
import '../widgets/group/group_quick_actions.dart';
import 'scan_screen.dart';
```

Add these methods inside `_GroupScreenState`, after `_openScopedAdd`:

```dart
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
```

- [ ] **Step 4: Render GroupQuickActions for selected groups**

In `lib/screens/group_screen.dart`, insert this block immediately after the `ItemScopeTabs` and its following `SizedBox(height: 16)`:

```dart
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
```

The surrounding section should remain inside the `else ...[` branch where `selectedGroupScope!` has already been established.

- [ ] **Step 5: Run the focused screen tests**

Run:

```powershell
flutter test test/screens/group_screen_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add lib/screens/group_screen.dart test/screens/group_screen_test.dart
git commit -m "feat: expose group page add actions"
```

---

### Task 4: Show the Target Group on Add and Scan Screens

**Files:**
- Modify: `lib/screens/add_item_screen.dart`
- Modify: `test/screens/add_item_screen_test.dart`
- Modify: `lib/screens/scan_screen.dart`
- Create: `test/screens/scan_screen_test.dart`

- [ ] **Step 1: Add AddItemScreen banner test**

In `test/screens/add_item_screen_test.dart`, add this test after the existing group registration test:

```dart
testWidgets('shows the target group while adding a group item', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: const AddItemScreen(
        targetScope: ItemScope.group(id: 'group-1', label: '우리 가족'),
      ),
    ),
  );

  expect(find.text('우리 가족에 추가 중'), findsOneWidget);
});
```

- [ ] **Step 2: Add ScanScreen banner test**

Create `test/screens/scan_screen_test.dart`:

```dart
import 'package:buylog/models/item_scope.dart';
import 'package:buylog/screens/scan_screen.dart';
import 'package:buylog/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the target group while scanning for a group', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: ScanScreen(
            targetScope: ItemScope.group(id: 'group-1', label: '우리 가족'),
          ),
        ),
      ),
    );

    expect(find.text('우리 가족에 스캔 추가'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run the focused tests and confirm they fail**

Run:

```powershell
flutter test test/screens/add_item_screen_test.dart test/screens/scan_screen_test.dart
```

Expected: FAIL because neither screen renders the target group banner yet.

- [ ] **Step 4: Implement AddItemScreen banner**

In `lib/screens/add_item_screen.dart`, add this helper inside `_AddItemScreenState`, near `_buildOcrBanner`:

```dart
Widget _buildScopeBanner() {
  final scope = _effectiveScope;
  if (!scope.isGroup) {
    return const SizedBox.shrink();
  }

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.primaryLight2,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.primaryLight, width: 0.5),
    ),
    child: Row(
      children: [
        const Icon(Icons.group_outlined, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${scope.label}에 추가 중',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
```

Then insert this block at the top of the `SingleChildScrollView` column, before the OCR banner:

```dart
if (_effectiveScope.isGroup) ...[
  _buildScopeBanner(),
  const SizedBox(height: 20),
],
```

- [ ] **Step 5: Implement ScanScreen banner**

In `lib/screens/scan_screen.dart`, add this helper inside `_ScanScreenState`:

```dart
Widget _buildScopeBanner() {
  if (!widget.targetScope.isGroup) {
    return const SizedBox.shrink();
  }

  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryLight2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primaryLight, width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.group_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${widget.targetScope.label}에 스캔 추가',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
```

In `_buildIdle`, insert the banner after the subtitle text and before `const SizedBox(height: 32)`:

```dart
_buildScopeBanner(),
```

- [ ] **Step 6: Run the focused tests**

Run:

```powershell
flutter test test/screens/add_item_screen_test.dart test/screens/scan_screen_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit**

```powershell
git add lib/screens/add_item_screen.dart lib/screens/scan_screen.dart test/screens/add_item_screen_test.dart test/screens/scan_screen_test.dart
git commit -m "feat: show group target during item entry"
```

---

### Task 5: Verification

**Files:**
- Verify all changed files.

- [ ] **Step 1: Format changed Dart files**

Run:

```powershell
dart format lib/widgets/group/group_quick_actions.dart lib/screens/group_screen.dart lib/screens/add_item_screen.dart lib/screens/scan_screen.dart test/widgets/group/group_quick_actions_test.dart test/screens/group_screen_test.dart test/screens/add_item_screen_test.dart test/screens/scan_screen_test.dart test/services/group_store_test.dart
```

Expected: command exits `0`.

- [ ] **Step 2: Run focused tests**

Run:

```powershell
flutter test test/services/group_store_test.dart test/widgets/group/group_quick_actions_test.dart test/screens/group_screen_test.dart test/screens/add_item_screen_test.dart test/screens/scan_screen_test.dart test/widget_test.dart
```

Expected: PASS.

- [ ] **Step 3: Run analyzer**

Run:

```powershell
flutter analyze --no-fatal-infos
```

Expected: no analyzer errors.

- [ ] **Step 4: Run full test suite**

Run:

```powershell
flutter test
```

Expected: PASS.

- [ ] **Step 5: Manual smoke test**

Run:

```powershell
flutter run -d windows
```

Manual checks:

1. 그룹 탭에서 기존 그룹이 선택된 상태로 `물품 추가`, `영수증 스캔`, `그룹 추가`가 보인다.
2. `물품 추가`를 누르면 등록 화면에 `선택 그룹명에 추가 중` 배너가 보이고 저장된 row의 `group_id`가 선택 그룹 id로 들어간다.
3. `영수증 스캔`을 누르면 스캔 화면에 `선택 그룹명에 스캔 추가` 배너가 보인다.
4. `그룹 추가`를 누르면 생성 다이얼로그가 뜨고, 생성 성공 후 새 그룹 탭이 선택된다.
5. 그룹이 하나도 없는 상태에서는 기존 빈 상태의 `그룹 만들기` 흐름이 계속 동작한다.

- [ ] **Step 6: Final commit if task commits were not created**

```powershell
git add lib/widgets/group/group_quick_actions.dart lib/screens/group_screen.dart lib/screens/add_item_screen.dart lib/screens/scan_screen.dart test/widgets/group/group_quick_actions_test.dart test/screens/group_screen_test.dart test/screens/add_item_screen_test.dart test/screens/scan_screen_test.dart test/services/group_store_test.dart
git commit -m "feat: improve group page add flows"
```

---

## Self-Review

- Spec coverage: The plan covers the weak group item addition path with explicit manual and scan actions, and covers missing additional group creation with a non-empty-state `그룹 추가` action.
- Business logic boundary: `GroupQuickActions` is callback-only, and `GroupScreen` only performs navigation/dialog presentation. Group creation still goes through `GroupStore.createGroup`, and item saving still goes through `ItemStore`/`SupabaseService`.
- Tests: New business behavior is protected at widget and store levels, including selected group id propagation and new group selection after creation.
- Null safety: `GroupQuickActions` only renders when `selectedGroupScope` is non-null. Add/scan scope banners use existing non-null `ItemScope` getters.
- UI risk: The global FAB remains unchanged, so existing navigation tests and user muscle memory keep working while the group page gains clearer in-context actions.
