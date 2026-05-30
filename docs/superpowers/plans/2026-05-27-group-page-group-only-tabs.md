# Group Page Group-Only Tabs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 그룹 페이지의 상단 탭에서 `내 물품`을 제거하고, 가입한 여러 그룹 사이를 전환하는 그룹 전용 탭으로 바꾼다.

**Architecture:** `ItemScope`는 저장/조회 범위 모델로 유지하되, `GroupStore`가 그룹 화면용 `groupScopes`와 `selectedGroupScope`를 제공한다. `GroupScreen`은 이 그룹 전용 scope만 렌더링하고 로드하며, 하단 전역 FAB도 그룹 탭에서는 선택 가능한 그룹이 있을 때만 노출한다.

**Tech Stack:** Flutter, Dart, `ValueNotifier`, Supabase gateway seam, `flutter_test`.

---

## Current Repo Context

- Root `AGENTS.md` requires Korean PR/review communication and blocks new business logic without tests.
- Current group page code lives in `lib/screens/group_screen.dart`.
- Group membership/selection state lives in `lib/services/group_store.dart`.
- Group item loading is already isolated in `lib/services/group_items_store.dart`.
- The current top chip widget is `lib/widgets/group/item_scope_tabs.dart` and can render any `ItemScope`, including `ItemScope.personal()`.
- `GroupState.availableScopes` currently returns `[내 물품, ...joinedGroups]`, and `GroupScreen` passes that directly to `ItemScopeTabs`.
- `MainNavigation._currentAddScope()` already uses `GroupStore.instance.value.selectedScope` when the current bottom tab is 그룹, so group selection semantics affect FAB-created items.
- No Supabase schema or migration change is required.

## File Structure

- Modify: `lib/services/group_store.dart`
  - Add `groupScopes` and `selectedGroupScope`.
  - Make initialization and leave-group fallback select a group scope when groups exist.
- Modify: `lib/screens/group_screen.dart`
  - Render only group scopes in the top tabs.
  - Do not load or render personal items on the group page.
  - Keep group item loading synced when group state changes after create/leave.
- No source change: `lib/widgets/group/item_scope_tabs.dart`
  - Keep the reusable chip UI as-is; the group-only contract is enforced by `GroupScreen` passing `groupScopes`.
- Modify: `lib/main.dart`
  - Hide the global add FAB on the group bottom tab when no group is selectable.
  - Pass the selected group scope to scan/manual add flows on the group bottom tab.
- Modify: `test/services/group_store_test.dart`
  - Cover group-only scopes and group-first selection fallback.
- Modify: `test/screens/group_screen_test.dart`
  - Cover removal of `내 물품` from group tabs and group-only initial loading.
- Modify: `test/widgets/group/item_scope_tabs_test.dart`
  - Update the widget expectation to joined-group tab rendering.
- Modify: `test/widget_test.dart`
  - Cover FAB visibility on the group bottom tab with and without groups.

---

### Task 1: Add Group-Only Scope Semantics to GroupStore

**Files:**
- Modify: `lib/services/group_store.dart`
- Test: `test/services/group_store_test.dart`

- [ ] **Step 1: Write failing GroupStore tests**

Add these tests inside the existing `group('GroupStore', () { ... })` block in `test/services/group_store_test.dart`:

```dart
test('exposes joined groups as group-only scopes', () async {
  gateway.loadGroupsForUserResult = <Map<String, dynamic>>[
    _groupRow(id: 'group-1', name: '우리 가족'),
    _groupRow(id: 'group-2', name: '사무실'),
  ];

  await GroupStore.instance.initialize();

  final groupScopes = GroupStore.instance.value.groupScopes;
  expect(groupScopes.map((scope) => scope.label), ['우리 가족', '사무실']);
  expect(groupScopes.every((scope) => scope.isGroup), isTrue);
  expect(groupScopes.any((scope) => scope.label == '내 물품'), isFalse);
});

test('initialize selects the first joined group for the group page', () async {
  gateway.loadGroupsForUserResult = <Map<String, dynamic>>[
    _groupRow(id: 'group-1', name: '우리 가족'),
    _groupRow(id: 'group-2', name: '사무실'),
  ];

  await GroupStore.instance.initialize();

  expect(
    GroupStore.instance.value.selectedScope,
    const ItemScope.group(id: 'group-1', label: '우리 가족'),
  );
  expect(
    GroupStore.instance.value.selectedGroupScope,
    const ItemScope.group(id: 'group-1', label: '우리 가족'),
  );
});

test('selectedGroupScope falls back to the first group when selected scope is personal', () {
  GroupStore.instance.value = GroupState(
    groups: <BuylogGroup>[
      _groupWithMembers(),
      BuylogGroup(
        id: 'group-2',
        name: '사무실',
        inviteCode: 'BUY-OFFICE',
        createdBy: 'owner-user',
        createdAt: DateTime.parse('2026-05-27T00:00:00.000Z'),
      ),
    ],
    selectedScope: const ItemScope.personal(),
  );

  expect(
    GroupStore.instance.value.selectedGroupScope,
    const ItemScope.group(id: 'group-1', label: '우리 가족'),
  );
});

test('leaves selected group and selects next remaining group', () async {
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

Update the existing test named `builds personal and joined group scopes after initialize` so it still verifies `availableScopes` includes `내 물품`, but expects `selectedScope` to be the first group:

```dart
test('builds personal and joined group scopes after initialize', () async {
  gateway.loadGroupsForUserResult = <Map<String, dynamic>>[
    _groupRow(id: 'group-1', name: '우리 가족'),
    _groupRow(id: 'group-2', name: '사무실'),
  ];

  await GroupStore.instance.initialize();

  final scopes = GroupStore.instance.value.availableScopes;
  expect(scopes.map((scope) => scope.label), ['내 물품', '우리 가족', '사무실']);
  expect(
    GroupStore.instance.value.selectedScope,
    const ItemScope.group(id: 'group-1', label: '우리 가족'),
  );
});
```

Update the existing test named `leaves the selected group and reloads joined groups` so the final selected scope is `group-2` instead of `ItemScope.personal()`:

```dart
expect(
  GroupStore.instance.value.selectedScope,
  const ItemScope.group(id: 'group-2', label: '사무실'),
);
```

- [ ] **Step 2: Run GroupStore tests and confirm they fail**

Run:

```powershell
flutter test test/services/group_store_test.dart --plain-name "group"
```

Expected: FAIL because `groupScopes` and `selectedGroupScope` do not exist and leave fallback still selects personal scope.

- [ ] **Step 3: Add group-only derived scopes**

In `lib/services/group_store.dart`, add these getters to `GroupState` below `availableScopes`:

```dart
List<ItemScope> get groupScopes {
  return <ItemScope>[
    for (final group in visibleGroups)
      ItemScope.group(id: group.id, label: group.name),
  ];
}

ItemScope? get selectedGroupScope {
  final scopes = groupScopes;
  if (selectedScope.isGroup) {
    for (final scope in scopes) {
      if (scope.id == selectedScope.id) {
        return scope;
      }
    }
  }
  return scopes.isEmpty ? null : scopes.first;
}
```

- [ ] **Step 4: Select the first group after initialization**

In `GroupStore.initialize()` in `lib/services/group_store.dart`, replace the success assignment with:

```dart
final groups = await SupabaseService.loadGroupsForUser();
value = GroupState(
  group: groups.isEmpty ? null : groups.first,
  groups: groups,
  selectedScope: _firstGroupScopeOrPersonal(groups),
);
```

Add this private helper inside `GroupStore`:

```dart
ItemScope _firstGroupScopeOrPersonal(List<BuylogGroup> groups) {
  if (groups.isEmpty) {
    return const ItemScope.personal();
  }
  final first = groups.first;
  return ItemScope.group(id: first.id, label: first.name);
}
```

- [ ] **Step 5: Select the next group after leaving a group**

In `GroupStore.leaveGroup()` in `lib/services/group_store.dart`, replace the `selectedScope` and `availableScopes` block with:

```dart
final remainingGroupScopes = <ItemScope>[
  for (final group in groups) ItemScope.group(id: group.id, label: group.name),
];
final selectedScope = _scopeAfterLeavingGroup(
  previousScope: previousState.selectedScope,
  removedGroupId: trimmedGroupId,
  remainingGroupScopes: remainingGroupScopes,
);

value = GroupState(
  group: groups.isEmpty ? null : groups.first,
  groups: groups,
  selectedScope: selectedScope,
);
```

Add this private helper inside `GroupStore`:

```dart
ItemScope _scopeAfterLeavingGroup({
  required ItemScope previousScope,
  required String removedGroupId,
  required List<ItemScope> remainingGroupScopes,
}) {
  if (previousScope.isGroup && previousScope.id != removedGroupId) {
    for (final scope in remainingGroupScopes) {
      if (scope.id == previousScope.id) {
        return scope;
      }
    }
  }

  if (remainingGroupScopes.isEmpty) {
    return const ItemScope.personal();
  }
  return remainingGroupScopes.first;
}
```

- [ ] **Step 6: Run GroupStore tests**

Run:

```powershell
flutter test test/services/group_store_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit**

```powershell
git add lib/services/group_store.dart test/services/group_store_test.dart
git commit -m "feat: prefer group scopes on group page"
```

---

### Task 2: Render GroupScreen with Group Tabs Only

**Files:**
- Modify: `lib/screens/group_screen.dart`
- Modify: `test/screens/group_screen_test.dart`
- Modify: `test/widgets/group/item_scope_tabs_test.dart`

- [ ] **Step 1: Update tab widget test to group-only expectations**

Replace the existing test in `test/widgets/group/item_scope_tabs_test.dart` with:

```dart
testWidgets('renders joined group tabs and reports group selection', (
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

- [ ] **Step 2: Add GroupScreen tests for no personal tab and no personal item load**

Add this test to `test/screens/group_screen_test.dart`:

```dart
testWidgets('group page renders group tabs only and loads the first group', (
  WidgetTester tester,
) async {
  final itemGateway = _RecordingItemDatabaseGateway()
    ..loadItemsResult = <Map<String, dynamic>>[
      _itemRow(id: 'group-item-1', groupId: 'group-1'),
    ];
  SupabaseService.debugItemDatabaseGateway = itemGateway;
  GroupStore.instance.value = GroupState(
    groups: <BuylogGroup>[
      _group(id: 'group-1', name: '우리 가족'),
      _group(id: 'group-2', name: '사무실'),
    ],
    selectedScope: const ItemScope.personal(),
  );

  await tester.pumpWidget(_wrap());
  await tester.pump();

  expect(find.text('내 물품'), findsNothing);
  expect(find.text('우리 가족'), findsAtLeastNWidgets(1));
  expect(find.text('사무실'), findsOneWidget);
  expect(itemGateway.lastUserId, isNull);
  expect(itemGateway.lastGroupId, 'group-1');
  expect(
    GroupStore.instance.value.selectedScope,
    const ItemScope.group(id: 'group-1', label: '우리 가족'),
  );
});
```

Add this test to the same file:

```dart
testWidgets('empty group page does not render a personal item list', (
  WidgetTester tester,
) async {
  SupabaseService.debugItemDatabaseGateway = _RecordingItemDatabaseGateway();
  GroupStore.instance.value = const GroupState();

  await tester.pumpWidget(_wrap());
  await tester.pump();

  expect(find.text('내 물품'), findsNothing);
  expect(find.text('내 물품 목록'), findsNothing);
  expect(find.text('그룹에 제품 추가'), findsNothing);
  expect(find.text('그룹 만들기'), findsOneWidget);
});
```

Update `_RecordingItemDatabaseGateway` in `test/screens/group_screen_test.dart` so tests can assert query routing:

```dart
class _RecordingItemDatabaseGateway implements ItemDatabaseGateway {
  int loadItemsCalls = 0;
  String? lastUserId;
  String? lastGroupId;
  List<Map<String, dynamic>> loadItemsResult = const [];

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

  @override
  Future<String> ensureCategory({
    required String name,
    required String? userId,
    required String? groupId,
  }) async {
    return 'category-1';
  }

  @override
  Future<void> upsertItem(Map<String, dynamic> payload) async {}

  @override
  Future<void> insertPurchase(Map<String, dynamic> payload) async {}
}
```

Update the existing test named `renders scope tabs and switches selected group tab`:

```dart
expect(find.text('내 물품'), findsNothing);
expect(find.text('우리 가족'), findsOneWidget);
expect(find.text('사무실'), findsOneWidget);
```

- [ ] **Step 3: Run widget tests and confirm they fail**

Run:

```powershell
flutter test test/widgets/group/item_scope_tabs_test.dart test/screens/group_screen_test.dart --plain-name "group"
```

Expected: FAIL because `GroupScreen` still passes `state.availableScopes` and still initializes item loading from `selectedScope`, which can be personal.

- [ ] **Step 4: Sync GroupScreen item loading to selected group scope**

In `lib/screens/group_screen.dart`, update `_GroupScreenState` lifecycle and helpers:

```dart
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
    GroupStore.instance.selectScope(selectedGroupScope);
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
  _itemsStore.load(scope);
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
  _itemsStore.load(event.scope);
}
```

- [ ] **Step 5: Render only group tabs and hide the item section when there are no groups**

Inside the `ValueListenableBuilder<GroupState>` builder in `lib/screens/group_screen.dart`, replace the selected group calculation and children after the title with this structure:

```dart
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
        child: Text('그룹', style: Theme.of(context).textTheme.headlineMedium),
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
        if (selectedGroup != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _GroupCard(
              group: selectedGroup,
              isRefreshingMembers: state.isRefreshingMembers,
              isLeavingGroup: state.isLeavingGroup,
              onRefreshMembers: () => GroupStore.instance.refreshMembers(
                groupId: selectedGroup.id,
              ),
              onCopyInviteCode: _copyInviteCode,
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
            final summary = GroupDashboardSummaryBuilder.build(
              scope: selectedGroupScope,
              items: itemState.scope.storageKey == selectedGroupScope.storageKey
                  ? itemState.items
                  : const [],
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
                      itemState.isLoading &&
                      itemState.scope.storageKey == selectedGroupScope.storageKey,
                  errorMessage:
                      itemState.scope.storageKey == selectedGroupScope.storageKey
                      ? itemState.errorMessage
                      : null,
                  emptyMessage: '아직 이 그룹에 등록한 물품이 없습니다.',
                  emptyActionLabel: '그룹에 제품 추가',
                  onEmptyAction: () => _openScopedAdd(selectedGroupScope),
                ),
              ],
            );
          },
        ),
      ],
    ],
  ),
);
```

- [ ] **Step 6: Run group screen tests**

Run:

```powershell
flutter test test/widgets/group/item_scope_tabs_test.dart test/screens/group_screen_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit**

```powershell
git add lib/screens/group_screen.dart test/screens/group_screen_test.dart test/widgets/group/item_scope_tabs_test.dart
git commit -m "feat: show group-only tabs on group page"
```

---

### Task 3: Keep the Global Add FAB Group-Only on the Group Tab

**Files:**
- Modify: `lib/main.dart`
- Test: `test/widget_test.dart`

- [ ] **Step 1: Add FAB visibility tests**

Add imports to `test/widget_test.dart`:

```dart
import 'package:buylog/models/group.dart';
```

Add this test:

```dart
testWidgets('group tab hides add FAB when no group exists', (
  WidgetTester tester,
) async {
  GroupStore.instance.value = const GroupState();

  await tester.pumpWidget(const BuylogApp());
  await tester.tap(find.text('그룹'));
  await tester.pump();

  expect(find.byTooltip('제품 추가'), findsNothing);
});
```

Add this test:

```dart
testWidgets('group tab shows add FAB when a group is selected', (
  WidgetTester tester,
) async {
  GroupStore.instance.value = GroupState(
    groups: <BuylogGroup>[_group()],
  );

  await tester.pumpWidget(const BuylogApp());
  await tester.tap(find.text('그룹'));
  await tester.pump();

  expect(find.byTooltip('제품 추가'), findsOneWidget);
});
```

Add this helper at the bottom of `test/widget_test.dart`:

```dart
BuylogGroup _group({String id = 'group-1', String name = '우리 가족'}) {
  return BuylogGroup(
    id: id,
    name: name,
    inviteCode: 'BUY-ABC123',
    createdBy: 'user-1',
    createdAt: DateTime.parse('2026-05-27T00:00:00.000Z'),
  );
}
```

- [ ] **Step 2: Run FAB tests and confirm they fail**

Run:

```powershell
flutter test test/widget_test.dart --plain-name "group tab"
```

Expected: FAIL because the FAB is still shown on the group bottom tab even when no group exists.

- [ ] **Step 3: Make MainNavigation listen to GroupStore for FAB state**

In `lib/main.dart`, replace `_currentAddScope()` with:

```dart
ItemScope _currentAddScope(GroupState groupState) {
  if (_currentIndex != 1) {
    return const ItemScope.personal();
  }

  return groupState.selectedGroupScope ?? const ItemScope.personal();
}

bool _shouldShowFab(GroupState groupState) {
  return switch (_currentIndex) {
    0 => true,
    1 => groupState.selectedGroupScope != null,
    2 => true,
    _ => false,
  };
}
```

Replace `_openAddSheet()` with:

```dart
Future<void> _openAddSheet(GroupState groupState) async {
  final choice = await showModalBottomSheet<_AddChoice>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => const _AddActionSheet(),
  );
  if (!mounted || choice == null) return;
  final targetScope = _currentAddScope(groupState);
  switch (choice) {
    case _AddChoice.scan:
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => Scaffold(
            backgroundColor: AppColors.background,
            body: Stack(
              children: [
                ScanScreen(targetScope: targetScope),
                Positioned(
                  top: MediaQuery.of(ctx).padding.top + 8,
                  right: 12,
                  child: Material(
                    color: AppColors.surface,
                    shape: const CircleBorder(),
                    elevation: 1,
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      color: AppColors.text,
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    case _AddChoice.manual:
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AddItemScreen(targetScope: targetScope),
        ),
      );
  }
}
```

Wrap the `Scaffold` returned by `MainNavigationState.build()` in a `ValueListenableBuilder<GroupState>`:

```dart
@override
Widget build(BuildContext context) {
  return ValueListenableBuilder<GroupState>(
    valueListenable: GroupStore.instance,
    builder: (context, groupState, _) {
      final showFab = _shouldShowFab(groupState);

      return Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [for (var i = 0; i < _tabs.length; i++) _screenAt(i)],
        ),
        floatingActionButton: showFab
            ? FloatingActionButton(
                onPressed: () => _openAddSheet(groupState),
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                elevation: 6,
                tooltip: '제품 추가',
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.add, size: 26),
              )
            : null,
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(
              top: BorderSide(color: AppColors.border, width: 0.5),
            ),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: switchTab,
            items: [
              for (final t in _tabs)
                BottomNavigationBarItem(
                  icon: Icon(t.icon),
                  activeIcon: Icon(t.activeIcon),
                  label: t.label,
                ),
            ],
          ),
        ),
      );
    },
  );
}
```

- [ ] **Step 4: Run FAB tests**

Run:

```powershell
flutter test test/widget_test.dart --plain-name "group tab"
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add lib/main.dart test/widget_test.dart
git commit -m "feat: keep group tab add action scoped"
```

---

### Task 4: Full Verification

**Files:**
- No new source files.

- [ ] **Step 1: Run analyzer**

Run:

```powershell
flutter analyze --no-fatal-infos
```

Expected: exit code 0.

- [ ] **Step 2: Run focused tests**

Run:

```powershell
flutter test test/services/group_store_test.dart test/screens/group_screen_test.dart test/widgets/group/item_scope_tabs_test.dart test/widget_test.dart
```

Expected: all tests pass.

- [ ] **Step 3: Run full test suite**

Run:

```powershell
flutter test
```

Expected: all tests pass.

- [ ] **Step 4: Check worktree scope**

Run:

```powershell
git status --short
```

Expected: only these files are modified:

```text
lib/services/group_store.dart
lib/screens/group_screen.dart
lib/main.dart
test/services/group_store_test.dart
test/screens/group_screen_test.dart
test/widgets/group/item_scope_tabs_test.dart
test/widget_test.dart
```

- [ ] **Step 5: Final commit if earlier task commits were skipped**

```powershell
git add lib/services/group_store.dart lib/screens/group_screen.dart lib/main.dart test/services/group_store_test.dart test/screens/group_screen_test.dart test/widgets/group/item_scope_tabs_test.dart test/widget_test.dart
git commit -m "feat: switch group page to group-only tabs"
```

Expected: commit contains only the group-only tab behavior and related tests.

---

## Self-Review

- Spec coverage: The plan removes `내 물품` from the group page tabs, uses joined groups as the tab source, and keeps group item loading scoped to the selected group.
- Business logic boundary: Group-scope fallback and selection semantics live in `GroupStore`; widgets only render state and dispatch selection callbacks.
- Test coverage: New business logic has service tests; UI behavior has screen/widget tests; bottom-tab add behavior has app-shell tests.
- No DB changes: Existing `ItemScope.group` and `SupabaseService.loadItemsForScope` already support group item loading.
- Regression risk: `availableScopes` remains available for existing code, while `groupScopes` becomes the group-page-specific API.
