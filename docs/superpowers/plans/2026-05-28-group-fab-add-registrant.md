# Group FAB Add Registrant Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 그룹 페이지의 우측 하단 `+` 버튼이 선택된 그룹에 제품을 추가하고, 그룹 아이템에서 누가 추가했는지 식별 가능한 정보를 사용할 수 있게 만든다.

**Architecture:** 기존 `ItemScope` 흐름을 유지해서 `MainNavigation`이 현재 탭과 `GroupStore.selectedGroupScope`로 추가 대상 스코프를 결정한다. 저장은 계속 `SupabaseService.saveItem()`에서 `user_id`, `group_id`, `registered_by`를 결정하게 두고, 조회 projection과 `ConsumableItem` 모델을 확장해 등록자 표시명을 UI에서 사용할 수 있게 한다.

**Tech Stack:** Flutter, Dart, `ValueNotifier`, Supabase PostgREST joins, `flutter_test`.

---

## Current Context

- `lib/main.dart`에는 루트 `FloatingActionButton`과 `_openAddSheet()`가 있고, 수동 등록은 `AddItemScreen(targetScope: targetScope)`, OCR 등록은 `ScanScreen(targetScope: targetScope)`로 이동한다.
- `lib/models/item_scope.dart`는 개인/그룹 저장 위치를 `ItemScope.personal()`과 `ItemScope.group(...)`로 표현한다.
- `lib/screens/add_item_screen.dart`는 `targetScope`를 받아 `ItemStore.instance.add(item, scope: _effectiveScope)`로 저장한다.
- `lib/services/supabase_service.dart`는 그룹 저장 시 `product_items.user_id = null`, `group_id = scope.id`, `registered_by = currentUserId`를 upsert payload에 넣는다.
- `lib/models/item.dart`에는 `registeredBy` ID 필드가 있지만, 등록자 표시명/email fallback은 아직 모델과 UI에서 직접 쓰기 어렵다.
- `lib/widgets/group/group_scoped_item_list.dart`는 그룹 아이템을 `ItemRow`로 렌더링한다.

## Scope

In scope:

- 그룹 탭에서 우측 하단 `+` 버튼을 누르면 선택된 그룹, 또는 선택값이 개인으로 남아 있으면 첫 번째 그룹에 제품이 저장되도록 회귀 테스트를 고정한다.
- 개인 탭/모든 제품 탭의 `+` 버튼은 계속 개인 아이템 추가로 동작한다.
- 그룹 아이템 저장 시 `registered_by`가 현재 사용자 ID로 저장되는 것을 테스트로 고정한다.
- 그룹 아이템 조회 시 `registered_by` 사용자의 표시명/email을 함께 가져오고 `ConsumableItem`에서 `registeredByLabel`로 사용할 수 있게 한다.
- 그룹 아이템 목록과 상세 화면에서 등록자 정보를 작게 표시한다.

Out of scope:

- 그룹 초대/가입, 멤버 권한 변경, RLS 정책 변경.
- 기존 DB 컬럼 추가. `product_items.registered_by`는 이미 존재하므로 migration은 만들지 않는다.
- 구매 이력별 `purchased_by` 표시. 이번 범위는 "아이템을 추가한 사람"인 `product_items.registered_by`만 다룬다.

## File Structure

- Modify: `lib/main.dart`
  - `_currentAddScope()`가 그룹 탭에서 `GroupStore.instance.value.selectedGroupScope`를 우선 반환하도록 유지/보강한다.
- Modify: `lib/services/supabase_service.dart`
  - `product_items` projection에 등록자 user join alias를 추가한다.
  - `_itemFromJoinedRow()`/`ConsumableItem.fromSupabase()`가 등록자 표시 정보를 받을 수 있게 한다.
- Modify: `lib/models/item.dart`
  - `registeredByDisplayName`, `registeredByEmail`, `registeredByLabel`을 추가한다.
- Modify: `lib/screens/items_screen.dart`
  - `ItemRow` subtitle에 그룹 아이템 등록자 label을 표시한다.
- Modify: `lib/screens/item_detail_screen.dart`
  - 그룹 아이템 상세 header에 등록자 metadata row를 표시한다.
- Modify: `test/main_navigation_test.dart`
  - 그룹 탭 `+` 수동 등록이 `group_id`, null `user_id`, `registered_by`를 저장하는지 검증한다.
- Modify: `test/services/supabase_service_test.dart`
  - 그룹 아이템 조회가 등록자 표시명을 모델로 매핑하는지 검증한다.
- Create: `test/widgets/item_row_test.dart`
  - 그룹 아이템 row에서 등록자 label이 보이고, 개인 아이템 row에서는 보이지 않는지 검증한다.
- Create: `test/screens/item_detail_screen_test.dart`
  - 그룹 아이템 상세 화면에서 등록자 metadata가 보이는지 검증한다.

---

### Task 1: Lock Group FAB Add Target

**Files:**
- Modify: `lib/main.dart`
- Modify: `test/main_navigation_test.dart`

- [ ] **Step 1: Extend the group FAB regression test**

In `test/main_navigation_test.dart`, update the existing test named `group tab add action targets the first group when selected scope is personal` so the final expectations include `registered_by`:

```dart
expect(gateway.ensureCategoryUserId, isNull);
expect(gateway.ensureCategoryGroupId, 'group-1');
expect(gateway.upsertPayload?['group_id'], 'group-1');
expect(gateway.upsertPayload?['user_id'], isNull);
expect(
  gateway.upsertPayload?['registered_by'],
  SupabaseService.currentUserId,
);
```

Add this second test in the same file to protect the personal-tab behavior:

```dart
testWidgets('home tab add action still targets personal items', (
  tester,
) async {
  final gateway = _RecordingItemDatabaseGateway();
  SupabaseService.debugItemDatabaseGateway = gateway;
  GroupStore.instance.value = GroupState(
    groups: <BuylogGroup>[_group()],
    selectedScope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
  );

  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.lightTheme, home: const MainNavigation()),
  );

  await tester.tap(find.byTooltip('제품 추가'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('직접 등록'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).first, '정수기 필터');
  await tester.tap(find.text('등록 완료'));
  await tester.pumpAndSettle();

  expect(gateway.ensureCategoryUserId, SupabaseService.currentUserId);
  expect(gateway.ensureCategoryGroupId, isNull);
  expect(gateway.upsertPayload?['user_id'], SupabaseService.currentUserId);
  expect(gateway.upsertPayload?['group_id'], isNull);
  expect(
    gateway.upsertPayload?['registered_by'],
    SupabaseService.currentUserId,
  );
});
```

- [ ] **Step 2: Run the navigation tests**

Run:

```powershell
flutter test test/main_navigation_test.dart
```

Expected: the new personal-tab test passes if `_currentAddScope()` already handles tab context correctly; otherwise it fails with `group_id` set on a personal add.

- [ ] **Step 3: Keep `_currentAddScope()` scoped by current tab**

In `lib/main.dart`, make `_currentAddScope()` exactly:

```dart
ItemScope _currentAddScope() {
  if (_currentIndex != 1) {
    return const ItemScope.personal();
  }

  return GroupStore.instance.value.selectedGroupScope ??
      const ItemScope.personal();
}
```

This keeps the default `+` behavior personal outside the group page, and makes the group page `+` use the selected group or the first available group fallback.

- [ ] **Step 4: Re-run the navigation tests**

Run:

```powershell
flutter test test/main_navigation_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit Task 1**

Run:

```powershell
git add lib/main.dart test/main_navigation_test.dart
git commit -m "test: lock grouped add action from fab"
```

---

### Task 2: Expose Registrant Data In Item Model

**Files:**
- Modify: `lib/models/item.dart`
- Modify: `lib/services/supabase_service.dart`
- Modify: `test/services/supabase_service_test.dart`

- [ ] **Step 1: Add failing mapping test for registered user display data**

In `test/services/supabase_service_test.dart`, add this test inside `group('SupabaseService.loadItemsForScope', () { ... })`:

```dart
test('maps registered user display data for group items', () async {
  final gateway = _RecordingItemDatabaseGateway()
    ..loadItemsResult = <Map<String, dynamic>>[
      _itemRow(id: 'group-item-1', groupId: 'group-1')
        ..['registered_by_user'] = <String, dynamic>{
          'id': SupabaseService.currentUserId,
          'display_name': '민서',
          'email': 'minseo@example.com',
        },
    ];
  SupabaseService.debugItemDatabaseGateway = gateway;

  final items = await SupabaseService.loadItemsForScope(
    const ItemScope.group(id: 'group-1', label: '우리 가족'),
  );

  expect(items.single.registeredBy, SupabaseService.currentUserId);
  expect(items.single.registeredByDisplayName, '민서');
  expect(items.single.registeredByEmail, 'minseo@example.com');
  expect(items.single.registeredByLabel, '민서');
});
```

Also add this fallback test:

```dart
test('uses registered user email as label when display name is blank', () async {
  final gateway = _RecordingItemDatabaseGateway()
    ..loadItemsResult = <Map<String, dynamic>>[
      _itemRow(id: 'group-item-1', groupId: 'group-1')
        ..['registered_by_user'] = <String, dynamic>{
          'id': SupabaseService.currentUserId,
          'display_name': '   ',
          'email': 'minseo@example.com',
        },
    ];
  SupabaseService.debugItemDatabaseGateway = gateway;

  final items = await SupabaseService.loadItemsForScope(
    const ItemScope.group(id: 'group-1', label: '우리 가족'),
  );

  expect(items.single.registeredByLabel, 'minseo@example.com');
});
```

- [ ] **Step 2: Run the focused Supabase mapping tests and verify failure**

Run:

```powershell
flutter test test/services/supabase_service_test.dart --plain-name "registered user"
```

Expected: FAIL because `registeredByDisplayName`, `registeredByEmail`, and `registeredByLabel` do not exist yet.

- [ ] **Step 3: Extend `ConsumableItem`**

In `lib/models/item.dart`, add fields after `registeredBy`:

```dart
final String? registeredByDisplayName;
final String? registeredByEmail;
```

Update the constructor parameters:

```dart
this.registeredBy,
this.registeredByDisplayName,
this.registeredByEmail,
```

Add this getter to `ConsumableItem`:

```dart
String? get registeredByLabel {
  final displayName = registeredByDisplayName?.trim();
  if (displayName != null && displayName.isNotEmpty) {
    return displayName;
  }

  final email = registeredByEmail?.trim();
  if (email != null && email.isNotEmpty) {
    return email;
  }

  final id = registeredBy?.trim();
  return id == null || id.isEmpty ? null : id;
}
```

- [ ] **Step 4: Parse registered user data in `fromSupabase`**

In `lib/models/item.dart`, inside `ConsumableItem.fromSupabase`, add this before `return ConsumableItem(`:

```dart
final registeredUser = data['registered_by_user'] as Map<String, dynamic>?;
final registeredDisplayName =
    (registeredUser?['display_name'] as String?)?.trim();
final registeredEmail = (registeredUser?['email'] as String?)?.trim();
```

Then update the returned `ConsumableItem`:

```dart
registeredBy: data['registered_by'] as String?,
registeredByDisplayName: registeredDisplayName?.isNotEmpty == true
    ? registeredDisplayName
    : null,
registeredByEmail: registeredEmail?.isNotEmpty == true
    ? registeredEmail
    : null,
```

- [ ] **Step 5: Add registered user join to item projection**

In `lib/services/supabase_service.dart`, update `_itemProjection` in `SupabaseItemDatabaseGateway` so it includes the registered user relation immediately after `registered_by`:

```dart
registered_by,
registered_by_user:users!product_items_registered_by_fkey (
  id,
  display_name,
  email
),
```

Keep the existing scalar `registered_by` field because it is the stable ID used for comparisons and fallback labels.

- [ ] **Step 6: Run Supabase service tests**

Run:

```powershell
flutter test test/services/supabase_service_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit Task 2**

Run:

```powershell
git add lib/models/item.dart lib/services/supabase_service.dart test/services/supabase_service_test.dart
git commit -m "feat: expose item registrant metadata"
```

---

### Task 3: Show Registrant In Group Item Rows

**Files:**
- Modify: `lib/screens/items_screen.dart`
- Create: `test/widgets/item_row_test.dart`

- [ ] **Step 1: Create failing ItemRow widget tests**

Create `test/widgets/item_row_test.dart`:

```dart
import 'package:buylog/models/item.dart';
import 'package:buylog/screens/items_screen.dart';
import 'package:buylog/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('group item row shows the registrant label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ItemRow(
            item: _item(
              groupId: 'group-1',
              registeredByDisplayName: '민서',
              registeredByEmail: 'minseo@example.com',
            ),
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.textContaining('추가: 민서'), findsOneWidget);
  });

  testWidgets('personal item row does not show registrant metadata', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ItemRow(
            item: _item(
              registeredByDisplayName: '민서',
              registeredByEmail: 'minseo@example.com',
            ),
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.textContaining('추가:'), findsNothing);
  });
}

ConsumableItem _item({
  String? groupId,
  String? registeredByDisplayName,
  String? registeredByEmail,
}) {
  return ConsumableItem(
    id: 'item-1',
    name: '정수기 필터',
    brand: '코웨이',
    category: '필터',
    icon: Icons.filter_alt_outlined,
    daysRemaining: 20,
    cycleDays: 30,
    progress: 0.3,
    groupId: groupId,
    registeredBy: 'user-1',
    registeredByDisplayName: registeredByDisplayName,
    registeredByEmail: registeredByEmail,
  );
}
```

- [ ] **Step 2: Run the row tests and verify failure**

Run:

```powershell
flutter test test/widgets/item_row_test.dart
```

Expected: FAIL because `ItemRow` does not render `registeredByLabel`.

- [ ] **Step 3: Update `ItemRow` subtitle composition**

In `lib/screens/items_screen.dart`, inside `ItemRow.build`, add this after `final cyclePart = item.aiPredictedDays ?? item.cycleDays;`:

```dart
final registeredByLabel = item.groupId == null ? null : item.registeredByLabel;
final subtitleParts = <String>[
  if (item.brand.trim().isNotEmpty) item.brand.trim(),
  '주기 $cyclePart일',
  if (registeredByLabel != null) '추가: $registeredByLabel',
];
```

Replace the existing subtitle `Text` widget content:

```dart
'${item.brand} · 주기 $cyclePart일',
```

with:

```dart
subtitleParts.join(' · '),
```

The full subtitle `Text` block should be:

```dart
Text(
  subtitleParts.join(' · '),
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  style: const TextStyle(
    fontSize: 11.5,
    color: AppColors.textMuted,
  ),
),
```

- [ ] **Step 4: Run the row tests**

Run:

```powershell
flutter test test/widgets/item_row_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit Task 3**

Run:

```powershell
git add lib/screens/items_screen.dart test/widgets/item_row_test.dart
git commit -m "feat: show registrant on group item rows"
```

---

### Task 4: Show Registrant In Item Detail

**Files:**
- Modify: `lib/screens/item_detail_screen.dart`
- Create: `test/screens/item_detail_screen_test.dart`

- [ ] **Step 1: Create failing detail screen test**

Create `test/screens/item_detail_screen_test.dart`:

```dart
import 'package:buylog/models/item.dart';
import 'package:buylog/screens/item_detail_screen.dart';
import 'package:buylog/services/item_store.dart';
import 'package:buylog/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    ItemStore.instance.value = [];
  });

  tearDown(() {
    ItemStore.instance.value = [];
  });

  testWidgets('group item detail shows the registrant label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: ItemDetailScreen(
          item: ConsumableItem(
            id: 'item-1',
            name: '정수기 필터',
            brand: '코웨이',
            category: '필터',
            icon: Icons.filter_alt_outlined,
            daysRemaining: 20,
            cycleDays: 30,
            progress: 0.3,
            groupId: 'group-1',
            registeredBy: 'user-1',
            registeredByDisplayName: '민서',
            registeredByEmail: 'minseo@example.com',
          ),
        ),
      ),
    );

    expect(find.text('추가한 사람'), findsOneWidget);
    expect(find.text('민서'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the detail test and verify failure**

Run:

```powershell
flutter test test/screens/item_detail_screen_test.dart
```

Expected: FAIL because the detail screen does not render registrant metadata.

- [ ] **Step 3: Add a detail metadata widget**

In `lib/screens/item_detail_screen.dart`, add this method inside `_ItemDetailScreenState`:

```dart
Widget _buildRegistrantMeta() {
  final registeredByLabel = _item.groupId == null ? null : _item.registeredByLabel;
  if (registeredByLabel == null) {
    return const SizedBox.shrink();
  }

  return Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Row(
      children: [
        const Icon(
          Icons.person_add_alt_1_outlined,
          size: 15,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: 6),
        const Text(
          '추가한 사람',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            registeredByLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 4: Render the metadata below brand**

In `_buildProductHeader()`, inside the `Column` that currently renders category, item name, and brand, add `_buildRegistrantMeta()` immediately after the brand `Text`:

```dart
const SizedBox(height: 2),
Text(
  _item.brand,
  style: const TextStyle(
    fontSize: 14,
    color: AppColors.textMuted,
  ),
),
_buildRegistrantMeta(),
```

If the existing brand `Text` already has the same structure, only add the final `_buildRegistrantMeta()` call after it.

- [ ] **Step 5: Run the detail test**

Run:

```powershell
flutter test test/screens/item_detail_screen_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit Task 4**

Run:

```powershell
git add lib/screens/item_detail_screen.dart test/screens/item_detail_screen_test.dart
git commit -m "feat: show registrant on item detail"
```

---

### Task 5: Final Verification

**Files:**
- No file edits.

- [ ] **Step 1: Format changed files**

Run:

```powershell
dart format lib/main.dart lib/models/item.dart lib/services/supabase_service.dart lib/screens/items_screen.dart lib/screens/item_detail_screen.dart test/main_navigation_test.dart test/services/supabase_service_test.dart test/widgets/item_row_test.dart test/screens/item_detail_screen_test.dart
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
flutter test test/main_navigation_test.dart
flutter test test/services/supabase_service_test.dart
flutter test test/widgets/item_row_test.dart
flutter test test/screens/item_detail_screen_test.dart
```

Expected: all focused tests pass.

- [ ] **Step 4: Run full test suite**

Run:

```powershell
flutter test
```

Expected: all tests pass.

- [ ] **Step 5: Manual smoke test**

Run:

```powershell
flutter run -d windows
```

Manual checks:

1. 그룹 탭으로 이동한다.
2. 우측 하단 `+` 버튼을 누르고 `직접 등록`을 선택한다.
3. 제품을 저장한다.
4. Supabase `product_items` row가 `user_id = null`, `group_id = 선택된 그룹 id`, `registered_by = 현재 사용자 id`인지 확인한다.
5. 그룹 목록에 저장한 제품이 나타나고 subtitle에 `추가: <표시명>`이 보이는지 확인한다.
6. 제품 상세 화면에서 `추가한 사람 <표시명>`이 보이는지 확인한다.
7. 홈 탭 또는 모든 제품 탭의 `+` 버튼으로 저장한 제품은 `user_id = 현재 사용자 id`, `group_id = null`로 저장되는지 확인한다.

- [ ] **Step 6: Inspect final diff**

Run:

```powershell
git status --short
git diff --stat
```

Expected: only the planned source/test files and this plan document changed.

---

## Self-Review

- Spec coverage: The plan covers group-page FAB add, default personal FAB behavior outside the group page, `registered_by` persistence, registered user lookup, model exposure, list UI, and detail UI.
- Business logic boundary: Scope ownership stays in `SupabaseService.saveItem()` and `GroupStore`; widgets only receive model data and render it.
- Test coverage: Navigation scope, Supabase mapping, row rendering, and detail rendering are covered with focused tests.
- Null safety: Registrant fields are nullable, and UI only renders labels when `registeredByLabel` is non-null.
- Placeholder scan: No unresolved implementation placeholders remain.
