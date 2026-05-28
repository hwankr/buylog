# Group Exclusive Dashboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 그룹 탭에서 `내 물품` 전환을 제거하고, 가입한 그룹의 물품 현황과 그룹 액션에 집중하는 전용 대시보드로 바꾼다.

**Architecture:** 개인 물품 데이터 흐름은 `홈`과 `모든 제품` 탭에 그대로 두고, 그룹 탭은 `GroupStore`가 제공하는 그룹 전용 scope만 사용한다. 그룹 선택 fallback, 그룹 물품 로딩, 요약/필터 계산은 서비스와 store helper에 두고 `GroupScreen`은 상태 조합과 화면 배치만 담당한다.

**Tech Stack:** Flutter, Dart, `ValueNotifier`, existing Supabase gateway seams, `flutter_test`.

---

## Current Context

- 현재 `GroupScreen`은 `ItemScopeTabs`에 `내 물품`과 그룹 scope를 함께 전달한다.
- `GroupStore.availableScopes`는 항상 `ItemScope.personal()`을 첫 항목으로 포함한다.
- `MainNavigation._currentAddScope()`는 그룹 탭에서 `GroupStore.instance.value.selectedScope`가 그룹이면 해당 그룹에 제품을 추가하고, 아니면 개인 물품에 추가한다.
- 그룹 물품 요약과 필터는 이미 `GroupDashboardSummaryBuilder`, `GroupItemFilterChips`, `GroupStatusSummary`, `GroupItemsStore.selectedFilter`로 분리되어 있다.
- 루트 `AGENTS.md` 기준상 새 비즈니스 로직에는 테스트가 필요하고, Flutter 위젯 내부에 비즈니스 로직을 넣으면 안 된다.

## Scope

In scope:

- 그룹 탭에서 `내 물품` 탭과 `내 물품 목록` 렌더링을 제거한다.
- 가입한 그룹이 있으면 첫 그룹을 기본 선택으로 사용한다.
- 여러 그룹이 있으면 그룹 이름 칩으로 그룹만 전환한다.
- 그룹이 없으면 그룹 생성 empty state만 보여주고 물품 목록/요약은 보여주지 않는다.
- 그룹 탭의 FAB/스캔/직접 등록은 현재 선택된 그룹, 또는 선택값이 개인으로 남아 있어도 첫 가입 그룹을 target scope로 사용한다.

Out of scope:

- 초대 코드로 그룹 참여, 담당자, 활동 로그, 멤버별 권한 변경, DB/RLS 변경.
- `모든 제품` 탭의 개인 물품 목록 UX 변경.

## File Structure

- Modify: `lib/services/group_store.dart`
  - `availableGroupScopes`, `selectedGroupScope`, `selectedGroup`를 추가한다.
  - `leaveGroup` 후 남은 그룹이 있으면 첫 그룹 scope를 선택하고, 없으면 개인 scope로 fallback한다.
- Modify: `lib/main.dart`
  - 그룹 탭 FAB target scope를 `selectedGroupScope` 기준으로 결정한다.
- Modify: `lib/screens/group_screen.dart`
  - `ItemScopeTabs`에 개인 scope를 전달하지 않는다.
  - 그룹이 없을 때는 empty state만 렌더링한다.
  - `GroupStore` listener로 그룹 선택 변경과 그룹 생성 후 item load를 동기화한다.
  - 저장 이벤트 reload 비교를 `selectedGroupScope` 기준으로 바꾼다.
- Modify: `test/services/group_store_test.dart`
  - 그룹 전용 scope 파생값과 leave fallback을 검증한다.
- Modify: `test/screens/group_screen_test.dart`
  - 개인 탭/개인 목록 제거, 첫 그룹 자동 로딩, 그룹 전환 로딩, empty state를 검증한다.
- Create: `test/main_navigation_test.dart`
  - 그룹 탭에서 추가 FAB가 첫 그룹 scope를 사용하는지 확인한다.
- Modify: `test/widgets/group/item_scope_tabs_test.dart`
  - `ItemScopeTabs` 자체는 generic widget으로 유지하면서 group-only 사용 케이스를 검증한다.

---

### Task 1: Add Group-Only Scope Derivations

**Files:**
- Modify: `lib/services/group_store.dart`
- Modify: `test/services/group_store_test.dart`

- [ ] **Step 1: Write failing tests for group-only scopes**

Add these tests inside the existing `group('GroupStore', () { ... })` block in `test/services/group_store_test.dart`:

```dart
test('exposes group-only scopes without the personal scope', () async {
  gateway.loadGroupsForUserResult = <Map<String, dynamic>>[
    _groupRow(id: 'group-1', name: '우리 가족'),
    _groupRow(id: 'group-2', name: '사무실'),
  ];

  await GroupStore.instance.initialize();

  final scopes = GroupStore.instance.value.availableGroupScopes;
  expect(scopes.map((scope) => scope.label), ['우리 가족', '사무실']);
  expect(scopes.every((scope) => scope.isGroup), isTrue);
});

test('uses the first joined group as selectedGroupScope fallback', () async {
  gateway.loadGroupsForUserResult = <Map<String, dynamic>>[
    _groupRow(id: 'group-1', name: '우리 가족'),
    _groupRow(id: 'group-2', name: '사무실'),
  ];

  await GroupStore.instance.initialize();

  expect(
    GroupStore.instance.value.selectedScope,
    const ItemScope.personal(),
  );
  expect(
    GroupStore.instance.value.selectedGroupScope,
    const ItemScope.group(id: 'group-1', label: '우리 가족'),
  );
  expect(GroupStore.instance.value.selectedGroup?.id, 'group-1');
});

test('keeps the selected joined group as selectedGroupScope', () async {
  gateway.loadGroupsForUserResult = <Map<String, dynamic>>[
    _groupRow(id: 'group-1', name: '우리 가족'),
    _groupRow(id: 'group-2', name: '사무실'),
  ];
  await GroupStore.instance.initialize();

  GroupStore.instance.selectScope(
    const ItemScope.group(id: 'group-2', label: '사무실'),
  );

  expect(
    GroupStore.instance.value.selectedGroupScope,
    const ItemScope.group(id: 'group-2', label: '사무실'),
  );
  expect(GroupStore.instance.value.selectedGroup?.id, 'group-2');
});
```

- [ ] **Step 2: Run focused store tests and verify failure**

Run:

```powershell
flutter test test/services/group_store_test.dart --plain-name "group-only scopes"
flutter test test/services/group_store_test.dart --plain-name "selectedGroupScope"
```

Expected: FAIL because `availableGroupScopes`, `selectedGroupScope`, and `selectedGroup` are not defined.

- [ ] **Step 3: Implement group-only scope helpers**

In `lib/services/group_store.dart`, add these getters to `GroupState` after `availableScopes`:

```dart
List<ItemScope> get availableGroupScopes {
  return <ItemScope>[
    for (final group in visibleGroups)
      ItemScope.group(id: group.id, label: group.name),
  ];
}

ItemScope? get selectedGroupScope {
  if (selectedScope.isGroup &&
      availableGroupScopes.any((scope) => scope == selectedScope)) {
    return selectedScope;
  }
  return availableGroupScopes.isEmpty ? null : availableGroupScopes.first;
}

BuylogGroup? get selectedGroup {
  final scope = selectedGroupScope;
  return scope == null ? null : groupForScope(scope);
}
```

- [ ] **Step 4: Run focused store tests and verify pass**

Run:

```powershell
flutter test test/services/group_store_test.dart --plain-name "group-only scopes"
flutter test test/services/group_store_test.dart --plain-name "selectedGroupScope"
```

Expected: PASS.

- [ ] **Step 5: Commit Task 1**

Run:

```powershell
git add lib/services/group_store.dart test/services/group_store_test.dart
git commit -m "feat: expose group-only scopes"
```

---

### Task 2: Keep Group Selection After Leaving Groups

**Files:**
- Modify: `lib/services/group_store.dart`
- Modify: `test/services/group_store_test.dart`

- [ ] **Step 1: Write failing leave fallback test**

Add this test inside `group('GroupStore', () { ... })` in `test/services/group_store_test.dart`:

```dart
test('selects the next group after leaving the selected group', () async {
  gateway.loadGroupsForUserResult = <Map<String, dynamic>>[
    _groupRow(id: 'group-1', name: '우리 가족'),
    _groupRow(id: 'group-2', name: '사무실'),
  ];
  await GroupStore.instance.initialize();
  GroupStore.instance.selectScope(
    const ItemScope.group(id: 'group-1', label: '우리 가족'),
  );
  gateway.loadGroupsForUserResult = <Map<String, dynamic>>[
    _groupRow(id: 'group-2', name: '사무실'),
  ];

  await GroupStore.instance.leaveGroup(groupId: 'group-1');

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

- [ ] **Step 2: Run focused leave test and verify failure**

Run:

```powershell
flutter test test/services/group_store_test.dart --plain-name "selects the next group"
```

Expected: FAIL because current `leaveGroup` selects `ItemScope.personal()` after leaving the selected group.

- [ ] **Step 3: Update `leaveGroup` selected scope calculation**

In `lib/services/group_store.dart`, replace the selected scope block inside `leaveGroup` after `final groups = await SupabaseService.loadGroupsForUser();` with:

```dart
final remainingScopes = <ItemScope>[
  for (final group in groups) ItemScope.group(id: group.id, label: group.name),
];
final previousSelectedStillExists = remainingScopes.any(
  (scope) => scope == previousState.selectedScope,
);
final selectedScope = previousSelectedStillExists
    ? previousState.selectedScope
    : remainingScopes.isEmpty
    ? const ItemScope.personal()
    : remainingScopes.first;

value = GroupState(
  group: groups.isEmpty ? null : groups.first,
  groups: groups,
  selectedScope: selectedScope,
);
```

Remove the old local `availableScopes` calculation from the same method.

- [ ] **Step 4: Update old expectation that now conflicts**

In the existing test named `leaves the selected group and reloads joined groups`, change this expectation:

```dart
expect(
  GroupStore.instance.value.selectedScope,
  const ItemScope.personal(),
);
```

to:

```dart
expect(
  GroupStore.instance.value.selectedScope,
  const ItemScope.group(id: 'group-2', label: '사무실'),
);
```

- [ ] **Step 5: Run GroupStore tests**

Run:

```powershell
flutter test test/services/group_store_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit Task 2**

Run:

```powershell
git add lib/services/group_store.dart test/services/group_store_test.dart
git commit -m "fix: keep group scope after leaving group"
```

---

### Task 3: Make Add Flow Use Group-Only Fallback

**Files:**
- Modify: `lib/main.dart`
- Create: `test/main_navigation_test.dart`

- [ ] **Step 1: Write failing navigation scope test**

Create `test/main_navigation_test.dart`:

```dart
import 'package:buylog/main.dart';
import 'package:buylog/models/group.dart';
import 'package:buylog/models/item_scope.dart';
import 'package:buylog/services/group_store.dart';
import 'package:buylog/services/item_store.dart';
import 'package:buylog/services/supabase_service.dart';
import 'package:buylog/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    GroupStore.instance.resetForTesting();
    ItemStore.instance.value = [];
    SupabaseService.debugItemDatabaseGateway = _RecordingItemDatabaseGateway();
  });

  tearDown(() {
    GroupStore.instance.resetForTesting();
    ItemStore.instance.value = [];
    SupabaseService.debugItemDatabaseGateway = null;
  });

  testWidgets('group tab add action targets the first group when selected scope is personal', (
    tester,
  ) async {
    final gateway = _RecordingItemDatabaseGateway();
    SupabaseService.debugItemDatabaseGateway = gateway;
    GroupStore.instance.value = GroupState(
      groups: <BuylogGroup>[_group()],
      selectedScope: const ItemScope.personal(),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const MainNavigation(),
      ),
    );

    await tester.tap(find.text('그룹'));
    await tester.pump();
    await tester.tap(find.byTooltip('제품 추가'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('직접 등록'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '정수기 필터');
    await tester.tap(find.text('등록 완료'));
    await tester.pumpAndSettle();

    expect(gateway.ensureCategoryUserId, isNull);
    expect(gateway.ensureCategoryGroupId, 'group-1');
    expect(gateway.upsertPayload?['group_id'], 'group-1');
    expect(gateway.upsertPayload?['user_id'], isNull);
  });
}

BuylogGroup _group() {
  return BuylogGroup(
    id: 'group-1',
    name: '우리 가족',
    inviteCode: 'BUY-ABC123',
    createdBy: SupabaseService.currentUserId,
    createdAt: DateTime.parse('2026-05-26T00:00:00.000Z'),
    members: <BuylogGroupMember>[],
  );
}

class _RecordingItemDatabaseGateway implements ItemDatabaseGateway {
  String? ensureCategoryUserId;
  String? ensureCategoryGroupId;
  Map<String, dynamic>? upsertPayload;

  @override
  Future<List<Map<String, dynamic>>> loadItems({
    required String? userId,
    required String? groupId,
  }) async {
    return const <Map<String, dynamic>>[];
  }

  @override
  Future<String> ensureCategory({
    required String name,
    required String? userId,
    required String? groupId,
  }) async {
    ensureCategoryUserId = userId;
    ensureCategoryGroupId = groupId;
    return 'category-1';
  }

  @override
  Future<void> upsertItem(Map<String, dynamic> payload) async {
    upsertPayload = Map<String, dynamic>.from(payload);
  }

  @override
  Future<void> insertPurchase(Map<String, dynamic> payload) async {}
}
```

- [ ] **Step 2: Run navigation test and verify failure**

Run:

```powershell
flutter test test/main_navigation_test.dart
```

Expected: FAIL before `MainNavigation._currentAddScope()` uses `selectedGroupScope`, because `ensureCategoryGroupId` is null and the payload is saved as a personal item.

- [ ] **Step 3: Update group tab add target selection**

In `lib/main.dart`, replace `_currentAddScope()` with:

```dart
ItemScope _currentAddScope() {
  if (_currentIndex != 1) {
    return const ItemScope.personal();
  }

  return GroupStore.instance.value.selectedGroupScope ??
      const ItemScope.personal();
}
```

- [ ] **Step 4: Run navigation test**

Run:

```powershell
flutter test test/main_navigation_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit Task 3**

Run:

```powershell
git add lib/main.dart test/main_navigation_test.dart
git commit -m "fix: target group scope from group tab add action"
```

---

### Task 4: Remove Personal Scope From GroupScreen

**Files:**
- Modify: `lib/screens/group_screen.dart`
- Modify: `test/screens/group_screen_test.dart`

- [ ] **Step 1: Write failing screen tests for group-only rendering**

Add these tests to `test/screens/group_screen_test.dart`:

```dart
testWidgets('group screen hides personal item tab and personal item list', (
  tester,
) async {
  GroupStore.instance.value = GroupState(
    groups: <BuylogGroup>[_group(id: 'group-1', name: '우리 가족')],
    selectedScope: const ItemScope.personal(),
  );

  await tester.pumpWidget(_wrap());
  await tester.pump();

  expect(find.text('내 물품'), findsNothing);
  expect(find.text('내 물품 목록'), findsNothing);
  expect(find.text('우리 가족'), findsAtLeastNWidgets(1));
  expect(find.text('우리 가족 목록'), findsOneWidget);
});

testWidgets('group screen loads first group items when selected scope is personal', (
  tester,
) async {
  final itemGateway = _RecordingItemDatabaseGateway()
    ..loadItemsResult = <Map<String, dynamic>>[
      _itemRow(id: 'group-item-1', groupId: 'group-1'),
    ];
  SupabaseService.debugItemDatabaseGateway = itemGateway;
  GroupStore.instance.value = GroupState(
    groups: <BuylogGroup>[_group(id: 'group-1', name: '우리 가족')],
    selectedScope: const ItemScope.personal(),
  );

  await tester.pumpWidget(_wrap());
  await tester.pump();

  expect(itemGateway.lastUserId, isNull);
  expect(itemGateway.lastGroupId, 'group-1');
  expect(find.text('group-item-1'), findsOneWidget);
});

testWidgets('empty group state does not render item dashboard or list heading', (
  tester,
) async {
  await tester.pumpWidget(_wrap());
  await tester.pump();

  expect(find.text('그룹'), findsOneWidget);
  expect(find.text('아직 연결된 그룹이 없습니다.'), findsOneWidget);
  expect(find.text('전체'), findsNothing);
  expect(find.textContaining('목록'), findsNothing);
});
```

Update `_RecordingItemDatabaseGateway` in the same file to record the last query:

```dart
String? lastUserId;
String? lastGroupId;

@override
Future<List<Map<String, dynamic>>> loadItems({
  required String? userId,
  required String? groupId,
}) async {
  loadItemsCalls += 1;
  lastUserId = userId;
  lastGroupId = groupId;
  return loadItemsResult;
}
```

- [ ] **Step 2: Run focused screen tests and verify failure**

Run:

```powershell
flutter test test/screens/group_screen_test.dart --plain-name "group screen hides personal"
flutter test test/screens/group_screen_test.dart --plain-name "loads first group items"
flutter test test/screens/group_screen_test.dart --plain-name "empty group state"
```

Expected: FAIL because `GroupScreen` still renders personal scope tabs and can load personal scope.

- [ ] **Step 3: Add group-store listener and group-scope loader**

In `lib/screens/group_screen.dart`, replace the current `initState`, `dispose`, `_selectScope`, and `_reloadAfterScopedSave` methods in `_GroupScreenState` with:

```dart
@override
void initState() {
  super.initState();
  _itemsStore = GroupItemsStore();
  GroupStore.instance.addListener(_reloadForSelectedGroup);
  ItemStore.instance.lastSaveEvent.addListener(_reloadAfterScopedSave);
  _reloadForSelectedGroup();
}

@override
void dispose() {
  GroupStore.instance.removeListener(_reloadForSelectedGroup);
  ItemStore.instance.lastSaveEvent.removeListener(_reloadAfterScopedSave);
  _itemsStore.dispose();
  super.dispose();
}

void _selectScope(ItemScope scope) {
  if (!scope.isGroup) return;
  GroupStore.instance.selectScope(scope);
}

void _reloadForSelectedGroup() {
  final scope = GroupStore.instance.value.selectedGroupScope;
  if (scope == null) return;
  if (_itemsStore.value.scope.storageKey == scope.storageKey &&
      !_itemsStore.value.isLoading) {
    return;
  }
  _itemsStore.load(scope);
}

void _reloadAfterScopedSave() {
  final event = ItemStore.instance.lastSaveEvent.value;
  final selectedScope = GroupStore.instance.value.selectedGroupScope;
  if (event == null ||
      selectedScope == null ||
      event.scope.storageKey != selectedScope.storageKey) {
    return;
  }
  _itemsStore.load(selectedScope);
}
```

- [ ] **Step 4: Render only group scopes**

In `GroupScreen.build`, replace:

```dart
final selectedGroup = state.groupForScope(state.selectedScope);
```

with:

```dart
final selectedScope = state.selectedGroupScope;
final selectedGroup = state.selectedGroup;
```

Replace the `ItemScopeTabs` block:

```dart
ItemScopeTabs(
  scopes: state.availableScopes,
  selectedScope: state.selectedScope,
  onSelected: _selectScope,
),
const SizedBox(height: 16),
```

with:

```dart
if (state.availableGroupScopes.length > 1) ...[
  ItemScopeTabs(
    scopes: state.availableGroupScopes,
    selectedScope: selectedScope ?? state.availableGroupScopes.first,
    onSelected: _selectScope,
  ),
  const SizedBox(height: 16),
],
```

Replace the group card and empty state branch:

```dart
if (selectedGroup != null)
  Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: _GroupCard(
      group: selectedGroup,
      isRefreshingMembers: state.isRefreshingMembers,
      isLeavingGroup: state.isLeavingGroup,
      onRefreshMembers: () => GroupStore.instance
          .refreshMembers(groupId: selectedGroup.id),
      onCopyInviteCode: _copyInviteCode,
    ),
  )
else if (state.visibleGroups.isEmpty)
  Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: _EmptyGroupState(errorMessage: state.errorMessage),
  ),
const SizedBox(height: 16),
```

with:

```dart
if (selectedGroup != null)
  Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: _GroupCard(
      group: selectedGroup,
      isRefreshingMembers: state.isRefreshingMembers,
      isLeavingGroup: state.isLeavingGroup,
      onRefreshMembers: () => GroupStore.instance
          .refreshMembers(groupId: selectedGroup.id),
      onCopyInviteCode: _copyInviteCode,
    ),
  )
else
  Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: _EmptyGroupState(errorMessage: state.errorMessage),
  ),
```

- [ ] **Step 5: Render dashboard only when a group is selected**

Wrap the existing list heading and `ValueListenableBuilder<GroupItemsState>` block with:

```dart
if (selectedScope != null && selectedGroup != null) ...[
  const SizedBox(height: 16),
  Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Text(
      '${selectedScope.label} 목록',
      style: Theme.of(context).textTheme.titleLarge,
    ),
  ),
  ValueListenableBuilder<GroupItemsState>(
    valueListenable: _itemsStore,
    builder: (context, itemState, _) {
      final summary = GroupDashboardSummaryBuilder.build(
        scope: itemState.scope,
        items: itemState.items,
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
            isLoading: itemState.isLoading,
            errorMessage: itemState.errorMessage,
            emptyMessage: '아직 이 그룹에 등록된 물품이 없습니다.',
            emptyActionLabel: '그룹에 제품 추가',
            onEmptyAction: () => _openScopedAdd(selectedScope),
          ),
        ],
      );
    },
  ),
],
```

Delete the old unconditional heading:

```dart
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 20),
  child: Text(
    '${state.selectedScope.label} 목록',
    style: Theme.of(context).textTheme.titleLarge,
  ),
),
```

Delete the personal empty message branches:

```dart
emptyMessage: summary.scope.isGroup
    ? '아직 이 그룹에 등록된 물품이 없습니다.'
    : '표시할 내 물품이 없습니다.',
emptyActionLabel: summary.scope.isGroup
    ? '그룹에 제품 추가'
    : '내 물품 추가',
```

- [ ] **Step 6: Update old scope tab test expectations**

In `test/screens/group_screen_test.dart`, rename the existing test:

```dart
testWidgets('renders scope tabs and switches selected group tab', (
```

to:

```dart
testWidgets('renders group scope tabs and switches selected group tab', (
```

Change the personal tab expectation:

```dart
expect(find.text('내 물품'), findsOneWidget);
```

to:

```dart
expect(find.text('내 물품'), findsNothing);
```

- [ ] **Step 7: Run screen tests**

Run:

```powershell
flutter test test/screens/group_screen_test.dart
```

Expected: PASS.

- [ ] **Step 8: Commit Task 4**

Run:

```powershell
git add lib/screens/group_screen.dart test/screens/group_screen_test.dart
git commit -m "feat: make group screen group-only"
```

---

### Task 5: Keep Widget Tests Aligned With Generic Scope Tabs

**Files:**
- Modify: `test/widgets/group/item_scope_tabs_test.dart`

- [ ] **Step 1: Add group-only usage coverage**

Add this test to `test/widgets/group/item_scope_tabs_test.dart`:

```dart
testWidgets('renders group-only tabs when personal scope is not provided', (
  tester,
) async {
  ItemScope? selected;

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: ItemScopeTabs(
          scopes: const <ItemScope>[
            ItemScope.group(id: 'group-1', label: '우리 가족'),
            ItemScope.group(id: 'group-2', label: '사무실'),
          ],
          selectedScope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
          onSelected: (scope) => selected = scope,
        ),
      ),
    ),
  );

  expect(find.text('내 물품'), findsNothing);
  expect(find.text('우리 가족'), findsOneWidget);
  expect(find.text('사무실'), findsOneWidget);

  await tester.tap(find.text('사무실'));
  expect(selected, const ItemScope.group(id: 'group-2', label: '사무실'));
});
```

- [ ] **Step 2: Run scope tab widget tests**

Run:

```powershell
flutter test test/widgets/group/item_scope_tabs_test.dart
```

Expected: PASS.

- [ ] **Step 3: Commit Task 5**

Run:

```powershell
git add test/widgets/group/item_scope_tabs_test.dart
git commit -m "test: cover group-only scope tabs"
```

---

### Task 6: Final Verification

**Files:**
- No file edits.

- [ ] **Step 1: Run formatter**

Run:

```powershell
dart format lib/services/group_store.dart lib/main.dart lib/screens/group_screen.dart test/services/group_store_test.dart test/screens/group_screen_test.dart test/widgets/group/item_scope_tabs_test.dart test/main_navigation_test.dart
```

Expected: command exits 0 and only planned files are formatted.

- [ ] **Step 2: Run analyzer**

Run:

```powershell
flutter analyze --no-fatal-infos
```

Expected: exit code 0.

- [ ] **Step 3: Run focused tests**

Run:

```powershell
flutter test test/services/group_store_test.dart
flutter test test/screens/group_screen_test.dart
flutter test test/widgets/group/item_scope_tabs_test.dart
flutter test test/main_navigation_test.dart
```

Expected: all focused tests pass.

- [ ] **Step 4: Run full test suite**

Run:

```powershell
flutter test
```

Expected: all tests pass.

- [ ] **Step 5: Inspect git diff**

Run:

```powershell
git status --short
git diff --stat
```

Expected: only these files changed:

```text
lib/services/group_store.dart
lib/main.dart
lib/screens/group_screen.dart
test/services/group_store_test.dart
test/screens/group_screen_test.dart
test/widgets/group/item_scope_tabs_test.dart
test/main_navigation_test.dart
```

The plan document itself is already tracked separately if this plan has been committed before implementation.

---

## Self-Review

- Spec coverage: The plan removes `내 물품` from `GroupScreen`, keeps personal items in `모든 제품`, and strengthens group-only selection, dashboard, and add flow.
- Business logic boundary: Group fallback selection lives in `GroupState`; item loading stays in `GroupItemsStore`; summary/filter logic stays in `GroupDashboardSummaryBuilder`.
- Type consistency: The plan uses existing `ItemScope`, `GroupState`, `GroupItemsStore`, `GroupDashboardSummaryBuilder`, `ItemScopeTabs`, and `GroupScopedItemList` names consistently.
- Test coverage: Store fallback, screen rendering, group item loading, widget behavior, and navigation add-scope behavior are covered.
- Placeholder scan: No unresolved implementation placeholders are present.
