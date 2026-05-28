# Add Item Scope Toggle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 제품 추가 화면에서 개인/그룹 저장 위치를 토글할 수 있게 만들고, 일반 페이지 진입은 개인 추가를, 그룹 페이지 진입은 그룹 추가를 기본값으로 사용한다.

**Architecture:** `MainNavigation._currentAddScope()`는 기존처럼 진입 기본 스코프만 결정한다. `AddItemScreen`은 새 아이템 등록 모드에서만 내부 `_selectedScope` 상태와 `GroupStore`의 그룹 목록을 사용해 개인/그룹 토글을 표시하고, 저장/중복검사/OCR 검수 저장은 선택된 스코프를 사용한다. 편집 모드는 기존 아이템의 스코프를 유지하고 토글을 숨겨서 제품 이동 기능으로 범위를 넓히지 않는다.

**Tech Stack:** Flutter, Dart, `ValueNotifier`, existing `ItemScope`/`GroupStore`/`ItemStore`, `flutter_test`.

---

## Current Context

- `lib/main.dart`의 `MainNavigation._currentAddScope()`는 현재 탭이 그룹 탭이면 `GroupStore.instance.value.selectedGroupScope`, 그 외에는 `ItemScope.personal()`을 `AddItemScreen`/`ScanScreen`에 전달한다.
- `lib/screens/add_item_screen.dart`는 현재 `widget.targetScope`를 `_effectiveScope`로 읽기만 하므로, 화면 안에서 저장 위치를 바꿀 수 없다.
- `lib/services/item_store.dart`와 `lib/services/supabase_service.dart`는 이미 `ItemScope`를 받아 개인 저장은 `user_id`, 그룹 저장은 `group_id`로 분기한다.
- `lib/services/group_store.dart`는 `availableGroupScopes`와 `selectedGroupScope`를 제공한다.
- 기존 `test/main_navigation_test.dart`는 일반/그룹 FAB 기본 스코프를 검증한다.
- 기존 `test/screens/add_item_screen_test.dart`는 그룹 targetScope 저장을 검증하지만, 화면 내 토글은 아직 없다.

## Scope

In scope:

- 새 제품 등록 화면에 개인/그룹 저장 위치 토글을 추가한다.
- 일반 페이지에서 등록 버튼으로 진입하면 `내 물품`이 기본 선택된다.
- 그룹 페이지에서 등록 버튼으로 진입하면 선택된 그룹이 기본 선택된다.
- 사용자가 토글로 저장 위치를 바꾸면 중복 검사와 최종 저장 모두 바뀐 스코프를 사용한다.
- OCR 검수로 진입한 `AddItemScreen`도 같은 토글과 기본 스코프 규칙을 사용한다.
- 그룹이 없으면 개인 선택만 표시하거나 토글 UI를 생략해 기존 개인 추가 흐름을 유지한다.
- 편집 모드에서는 토글을 표시하지 않고 기존 아이템 스코프를 유지한다.

Out of scope:

- 기존 아이템을 개인에서 그룹으로 이동하거나 그룹 간 이동하는 편집 기능.
- 그룹 생성/초대 UX 변경.
- DB schema/RLS 변경.

## File Structure

- Modify: `lib/screens/add_item_screen.dart`
  - `_selectedScope` 상태를 추가한다.
  - `_effectiveScope`가 새 등록 모드에서는 `_selectedScope`, 편집 모드에서는 기존 아이템 스코프를 반환하게 한다.
  - `GroupStore`를 구독하는 scope toggle UI를 기본 정보 섹션 위에 추가한다.
  - 토글 선택 시 중복 검사와 저장이 새 스코프를 사용하게 한다.
- Modify: `test/screens/add_item_screen_test.dart`
  - 개인 기본값, 그룹 기본값, 개인에서 그룹으로 전환, 그룹에서 개인으로 전환, 편집 모드 토글 숨김을 검증한다.
- Modify: `test/main_navigation_test.dart`
  - 기존 FAB 기본 스코프 테스트가 토글 추가 후에도 통과하도록 key 기반 등록 helper를 유지한다.

---

### Task 1: Add Scope Toggle Tests For AddItemScreen

**Files:**
- Modify: `test/screens/add_item_screen_test.dart`

- [ ] **Step 1: Replace the existing test file with scope-toggle coverage**

Replace `test/screens/add_item_screen_test.dart` with:

```dart
import 'package:buylog/models/group.dart';
import 'package:buylog/models/item.dart';
import 'package:buylog/models/item_scope.dart';
import 'package:buylog/screens/add_item_screen.dart';
import 'package:buylog/services/group_store.dart';
import 'package:buylog/services/item_store.dart';
import 'package:buylog/services/supabase_service.dart';
import 'package:buylog/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _RecordingItemDatabaseGateway gateway;

  setUp(() {
    gateway = _RecordingItemDatabaseGateway();
    SupabaseService.debugItemDatabaseGateway = gateway;
    GroupStore.instance.resetForTesting();
    ItemStore.instance.value = [];
  });

  tearDown(() {
    SupabaseService.debugItemDatabaseGateway = null;
    GroupStore.instance.resetForTesting();
    ItemStore.instance.value = [];
  });

  testWidgets('personal target scope is selected by default', (tester) async {
    _seedGroups();

    await tester.pumpWidget(_wrap(const AddItemScreen()));

    expect(_scopeChip('personal'), findsOneWidget);
    expect(
      tester.widget<ChoiceChip>(_scopeChip('personal')).selected,
      isTrue,
    );
    expect(
      tester.widget<ChoiceChip>(_scopeChip('group:group-1')).selected,
      isFalse,
    );
  });

  testWidgets('group target scope is selected by default', (tester) async {
    _seedGroups();

    await tester.pumpWidget(
      _wrap(
        const AddItemScreen(
          targetScope: ItemScope.group(id: 'group-1', label: 'Family'),
        ),
      ),
    );

    expect(
      tester.widget<ChoiceChip>(_scopeChip('personal')).selected,
      isFalse,
    );
    expect(
      tester.widget<ChoiceChip>(_scopeChip('group:group-1')).selected,
      isTrue,
    );
  });

  testWidgets('switching from personal to group saves with group id', (
    tester,
  ) async {
    _seedGroups();

    await tester.pumpWidget(_wrap(const AddItemScreen()));
    await tester.tap(_scopeChip('group:group-1'));
    await tester.pump();
    await _submitMinimalItem(tester);

    expect(gateway.upsertedItemPayload?['user_id'], isNull);
    expect(gateway.upsertedItemPayload?['group_id'], 'group-1');
  });

  testWidgets('switching from group to personal saves as personal item', (
    tester,
  ) async {
    _seedGroups();

    await tester.pumpWidget(
      _wrap(
        const AddItemScreen(
          targetScope: ItemScope.group(id: 'group-1', label: 'Family'),
        ),
      ),
    );
    await tester.tap(_scopeChip('personal'));
    await tester.pump();
    await _submitMinimalItem(tester);

    expect(gateway.upsertedItemPayload?['user_id'], SupabaseService.currentUserId);
    expect(gateway.upsertedItemPayload?['group_id'], isNull);
  });

  testWidgets('edit mode hides scope toggle and preserves item group scope', (
    tester,
  ) async {
    _seedGroups();

    await tester.pumpWidget(
      _wrap(
        AddItemScreen(
          editItem: ConsumableItem(
            id: 'item-1',
            name: 'filter',
            brand: 'Coway',
            category: '주방/세제',
            icon: Icons.kitchen_outlined,
            daysRemaining: 10,
            cycleDays: 30,
            progress: 0.2,
            groupId: 'group-1',
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('add_item_scope_toggle')), findsNothing);
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    expect(gateway.upsertedItemPayload?['user_id'], isNull);
    expect(gateway.upsertedItemPayload?['group_id'], 'group-1');
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(theme: AppTheme.lightTheme, home: child);
}

Finder _scopeChip(String storageKey) {
  return find.byKey(ValueKey('add_item_scope_$storageKey'));
}

void _seedGroups() {
  GroupStore.instance.value = GroupState(
    groups: <BuylogGroup>[
      BuylogGroup(
        id: 'group-1',
        name: 'Family',
        inviteCode: 'BUY-ABC123',
        createdBy: SupabaseService.currentUserId,
        createdAt: DateTime.parse('2026-05-26T00:00:00.000Z'),
      ),
    ],
    selectedScope: const ItemScope.group(id: 'group-1', label: 'Family'),
  );
}

Future<void> _submitMinimalItem(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'filter');
  await tester.enterText(find.byType(TextFormField).at(1), 'Coway');
  await tester.enterText(find.byType(TextFormField).at(2), '30');
  await tester.enterText(find.byType(TextFormField).at(3), '8900');
  await tester.enterText(find.byType(TextFormField).at(4), 'Market');
  await tester.tap(find.byType(FilledButton).last);
  await tester.pumpAndSettle();
}

class _RecordingItemDatabaseGateway implements ItemDatabaseGateway {
  Map<String, dynamic>? upsertedItemPayload;

  @override
  Future<List<Map<String, dynamic>>> loadItems({
    required String? userId,
    required String? groupId,
  }) async {
    return const [];
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
  Future<void> upsertItem(Map<String, dynamic> payload) async {
    upsertedItemPayload = Map<String, dynamic>.from(payload);
  }

  @override
  Future<void> insertPurchase(Map<String, dynamic> payload) async {}
}
```

- [ ] **Step 2: Run AddItemScreen tests and verify failure**

Run:

```powershell
flutter test test/screens/add_item_screen_test.dart
```

Expected: FAIL because `add_item_scope_toggle` and `add_item_scope_*` keys do not exist.

- [ ] **Step 3: Commit the failing tests**

Do not commit if your team avoids red commits. If following this plan literally with checkpoint commits, run:

```powershell
git add test/screens/add_item_screen_test.dart
git commit -m "test: specify add item scope toggle"
```

---

### Task 2: Add Mutable Scope State To AddItemScreen

**Files:**
- Modify: `lib/screens/add_item_screen.dart`

- [ ] **Step 1: Add GroupStore import and selected scope state**

In `lib/screens/add_item_screen.dart`, add this import:

```dart
import '../services/group_store.dart';
```

Inside `_AddItemScreenState`, after `_selectedCategory`, add:

```dart
late ItemScope _selectedScope;
```

- [ ] **Step 2: Replace `_effectiveScope` with edit-aware selected scope logic**

Replace the current `_effectiveScope` getter with:

```dart
bool get _canChangeScope => !_isEditing;

ItemScope get _initialScope {
  final explicit = widget.targetScope;
  if (explicit != null) return explicit;

  final editGroupId = widget.editItem?.groupId;
  if (editGroupId != null && editGroupId.isNotEmpty) {
    return ItemScope.group(id: editGroupId, label: '그룹');
  }

  return const ItemScope.personal();
}

ItemScope get _effectiveScope {
  if (_isEditing) return _initialScope;
  return _selectedScope;
}
```

- [ ] **Step 3: Initialize selected scope**

In `initState()`, immediately after:

```dart
super.initState();
```

add:

```dart
_selectedScope = _initialScope;
```

- [ ] **Step 4: Run AddItemScreen tests and verify partial failure**

Run:

```powershell
flutter test test/screens/add_item_screen_test.dart
```

Expected: still FAIL because the UI toggle is not rendered yet, but compile errors for `_selectedScope` are gone.

---

### Task 3: Render Personal/Group Scope Toggle

**Files:**
- Modify: `lib/screens/add_item_screen.dart`

- [ ] **Step 1: Add scope option helper**

Inside `_AddItemScreenState`, add this method before `_submit()`:

```dart
List<ItemScope> _scopeOptions(GroupState state) {
  final options = <ItemScope>[
    const ItemScope.personal(),
    ...state.availableGroupScopes,
  ];

  final selectedAlreadyIncluded = options.any(
    (scope) => scope.storageKey == _selectedScope.storageKey,
  );
  if (!selectedAlreadyIncluded && _selectedScope.isGroup) {
    options.add(_selectedScope);
  }

  return options;
}
```

- [ ] **Step 2: Add scope toggle widget**

Inside `_AddItemScreenState`, add this widget method before `_buildBasicInfoSection()`:

```dart
Widget _buildScopeToggle() {
  if (!_canChangeScope) return const SizedBox.shrink();

  return ValueListenableBuilder<GroupState>(
    valueListenable: GroupStore.instance,
    builder: (context, state, _) {
      final options = _scopeOptions(state);
      if (options.length <= 1) {
        return const SizedBox.shrink();
      }

      return Column(
        key: const ValueKey('add_item_scope_toggle'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '등록 위치',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final scope in options)
                ChoiceChip(
                  key: ValueKey('add_item_scope_${scope.storageKey}'),
                  label: Text(scope.label),
                  selected: scope.storageKey == _selectedScope.storageKey,
                  onSelected: (_) {
                    setState(() {
                      _selectedScope = scope;
                    });
                  },
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  labelStyle: TextStyle(
                    color: scope.storageKey == _selectedScope.storageKey
                        ? Colors.white
                        : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                    side: BorderSide(
                      color: scope.storageKey == _selectedScope.storageKey
                          ? AppColors.primary
                          : AppColors.border,
                      width: 0.5,
                    ),
                  ),
                ),
            ],
          ),
        ],
      );
    },
  );
}
```

- [ ] **Step 3: Insert toggle into the form**

In `build()`, inside the main `Column` and immediately before:

```dart
_sectionTitle('기본 정보'),
```

insert:

```dart
_buildScopeToggle(),
if (_canChangeScope && _scopeOptions(GroupStore.instance.value).length > 1)
  const SizedBox(height: 24),
```

If the file still contains garbled Korean strings from prior encoding, keep the existing `_sectionTitle(...)` call unchanged and insert the toggle immediately above it.

- [ ] **Step 4: Run AddItemScreen tests**

Run:

```powershell
flutter test test/screens/add_item_screen_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit Task 2-3 implementation**

Run:

```powershell
git add lib/screens/add_item_screen.dart test/screens/add_item_screen_test.dart
git commit -m "feat: add item scope toggle"
```

---

### Task 4: Lock FAB Defaults With Toggle Present

**Files:**
- Modify: `test/main_navigation_test.dart`

- [ ] **Step 1: Add assertions that the opened form default is correct**

In `test/main_navigation_test.dart`, update `_addManualItem` so it accepts an expected selected scope key:

```dart
Future<void> _addManualItem(
  WidgetTester tester, {
  required String expectedSelectedScopeKey,
}) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.edit_outlined));
  await tester.pumpAndSettle();

  final chip = tester.widget<ChoiceChip>(
    find.byKey(ValueKey('add_item_scope_$expectedSelectedScopeKey')),
  );
  expect(chip.selected, isTrue);

  await tester.enterText(find.byType(TextFormField).first, 'filter');
  await tester.tap(find.byType(FilledButton).last);
  await tester.pumpAndSettle();
}
```

Update the group test call:

```dart
await _addManualItem(
  tester,
  expectedSelectedScopeKey: 'group:group-1',
);
```

Update the home test call:

```dart
await _addManualItem(
  tester,
  expectedSelectedScopeKey: 'personal',
);
```

- [ ] **Step 2: Run main navigation tests**

Run:

```powershell
flutter test test/main_navigation_test.dart
```

Expected: PASS. This proves 일반 페이지 진입 defaults to personal and 그룹 페이지 진입 defaults to group while the new toggle is visible.

- [ ] **Step 3: Commit Task 4**

Run:

```powershell
git add test/main_navigation_test.dart
git commit -m "test: lock add form default scope from fab"
```

---

### Task 5: Regression And Verification

**Files:**
- No file edits.

- [ ] **Step 1: Format changed files**

Run:

```powershell
dart format lib/screens/add_item_screen.dart test/screens/add_item_screen_test.dart test/main_navigation_test.dart
```

Expected: command exits 0.

- [ ] **Step 2: Run analyzer**

Run:

```powershell
flutter analyze --no-fatal-infos
```

Expected: exit code 0.

- [ ] **Step 3: Run focused tests**

Run:

```powershell
flutter test test/screens/add_item_screen_test.dart
flutter test test/main_navigation_test.dart
```

Expected: both focused test files pass.

- [ ] **Step 4: Run related store/service tests**

Run:

```powershell
flutter test test/services/item_store_test.dart test/services/supabase_service_test.dart test/screens/group_screen_test.dart
```

Expected: all related tests pass, proving the changed screen still saves through existing scope-aware services.

- [ ] **Step 5: Run full test suite**

Run:

```powershell
flutter test
```

Expected: all tests pass.

- [ ] **Step 6: Optional manual smoke check**

Run:

```powershell
flutter run -d windows
```

Manual checks:

1. 홈 또는 모든 제품 탭에서 `+` → `직접 등록`을 연다.
2. 등록 위치가 개인으로 기본 선택되어 있는지 확인한다.
3. 그룹 토글로 바꾼 뒤 저장하면 그룹 목록에 나타나는지 확인한다.
4. 그룹 탭에서 `+` → `직접 등록`을 연다.
5. 등록 위치가 현재 그룹으로 기본 선택되어 있는지 확인한다.
6. 개인 토글로 바꾼 뒤 저장하면 개인 목록에 저장되는지 확인한다.
7. OCR 등록 흐름에서도 같은 토글이 보이고 저장 위치가 반영되는지 확인한다.

- [ ] **Step 7: Inspect final diff**

Run:

```powershell
git status --short
git diff --stat
```

Expected: only these files changed for this feature:

```text
lib/screens/add_item_screen.dart
test/screens/add_item_screen_test.dart
test/main_navigation_test.dart
docs/superpowers/plans/2026-05-28-add-item-scope-toggle.md
```

If earlier uncommitted work exists in the same branch, verify the diff manually and do not revert unrelated files.

---

## Self-Review

- Spec coverage: The plan adds the requested personal/group toggle on product add, preserves personal default from general pages, preserves group default from group pages, and lets users override the default before saving.
- Business logic boundary: Scope persistence stays in `ItemStore`/`SupabaseService`; `AddItemScreen` only owns the user's current selection.
- Type consistency: The plan uses existing `ItemScope`, `GroupState`, `GroupStore`, `ItemStore`, and `ChoiceChip` APIs consistently.
- Test coverage: Add form defaults, toggling in both directions, edit-mode preservation, and FAB default behavior are covered.
- Placeholder scan: No unresolved implementation placeholders remain.
