# Group Tab Switching UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a tab switching UI in the Group screen so users can switch between `내 물품`, `그룹1`, `그룹2`, and later groups without putting filtering or loading logic inside widgets.

**Architecture:** Keep the existing bottom navigation unchanged and make the Group screen own only the group-context item view. Extend group state to expose all joined groups, introduce a focused item-scope model, and add a separate `GroupItemsStore` for scoped loading so `HomeScreen` and `ItemsScreen` continue using the current `ItemStore` flow. Supabase query details remain centralized in `SupabaseService` behind testable gateway seams.

**Tech Stack:** Flutter, Dart, `ValueNotifier`, Supabase Flutter, `flutter_test`, widget tests.

---

## Current Repo Context

- Root `AGENTS.md` requires Korean PR/review communication and blocks business logic inside Flutter widgets.
- `lib/main.dart` already has a bottom navigation `GroupScreen` tab at index 1.
- `lib/screens/group_screen.dart` currently renders one default group from `GroupStore.instance`.
- `lib/services/group_store.dart` currently stores only `GroupState.group`, loaded by `SupabaseService.loadDefaultGroup()`.
- `lib/services/item_store.dart` loads personal items only with `SupabaseService.loadItems()` and is used by home/items screens.
- `public.product_items` already has mutually exclusive `user_id` and `group_id`; current `loadItems()` only queries `user_id`.
- Existing verification pair for buylog is `flutter analyze --no-fatal-infos` and `flutter test`.

## File Structure

- Create: `lib/models/item_scope.dart`
  - Defines `ItemScopeType` and `ItemScope`.
  - Provides labels for `내 물품` and joined groups.
- Modify: `lib/models/item.dart`
  - Add nullable `groupId` and `registeredBy` metadata parsed from Supabase rows.
  - Keep existing constructor defaults so current tests and widgets remain source-compatible except where assertions need scope metadata.
- Modify: `lib/models/group.dart`
  - No structural change required if `BuylogGroup` remains the tab source.
- Modify: `lib/services/supabase_service.dart`
  - Add `loadGroupsForUser()`.
  - Add `loadItemsForScope(ItemScope scope)`.
  - Add a minimal debug item gateway seam matching the current group gateway pattern.
- Modify: `lib/services/group_store.dart`
  - Add `groups`, `selectedScope`, `selectScope(...)`, and a derived `availableScopes`.
  - Preserve `group` as a backward-compatible default-group getter or field.
- Create: `lib/services/group_items_store.dart`
  - Loads items for the selected `ItemScope`.
  - Exposes loading/error/items state separate from the global `ItemStore`.
- Modify: `lib/screens/group_screen.dart`
  - Add horizontal tab chips: `내 물품 | <group.name> | ...`.
  - Render scoped item list under the selected tab.
  - Keep group summary/member card visible for group tabs.
- Create: `lib/widgets/group/item_scope_tabs.dart`
  - Pure UI widget for stable horizontal scope tab rendering.
- Create: `lib/widgets/group/group_scoped_item_list.dart`
  - Pure UI widget for loading, error, empty, and list states.
- Modify: `test/services/group_store_test.dart`
  - Cover multiple groups and selected scope behavior.
- Create: `test/services/group_items_store_test.dart`
  - Cover scoped load success, error, stale-result avoidance, and no duplicate load while loading.
- Modify: `test/services/supabase_service_test.dart`
  - Cover Supabase payload/query routing through fake gateway.
- Modify: `test/screens/group_screen_test.dart`
  - Cover tab rendering and switching.
- Create: `test/widgets/group/item_scope_tabs_test.dart`
  - Cover horizontal tab labels, selected state, and callback.

---

### Task 1: Add Item Scope Model

**Files:**
- Create: `lib/models/item_scope.dart`
- Test: `test/services/group_store_test.dart`

- [ ] **Step 1: Write scope model tests**

Append these tests near the model tests in `test/services/group_store_test.dart`:

```dart
import 'package:buylog/models/item_scope.dart';

group('ItemScope', () {
  test('builds the personal scope label', () {
    const scope = ItemScope.personal();

    expect(scope.type, ItemScopeType.personal);
    expect(scope.id, isNull);
    expect(scope.label, '내 물품');
    expect(scope.storageKey, 'personal');
  });

  test('builds a group scope label and stable key', () {
    const scope = ItemScope.group(id: 'group-1', label: '우리 가족');

    expect(scope.type, ItemScopeType.group);
    expect(scope.id, 'group-1');
    expect(scope.label, '우리 가족');
    expect(scope.storageKey, 'group:group-1');
  });
});
```

- [ ] **Step 2: Run model test and confirm it fails**

Run:

```powershell
flutter test test/services/group_store_test.dart --plain-name "ItemScope"
```

Expected: FAIL because `package:buylog/models/item_scope.dart` does not exist.

- [ ] **Step 3: Implement `ItemScope`**

Create `lib/models/item_scope.dart`:

```dart
enum ItemScopeType { personal, group }

class ItemScope {
  const ItemScope._({
    required this.type,
    required this.id,
    required this.label,
  });

  const ItemScope.personal()
    : this._(type: ItemScopeType.personal, id: null, label: '내 물품');

  const ItemScope.group({required String id, required String label})
    : this._(type: ItemScopeType.group, id: id, label: label);

  final ItemScopeType type;
  final String? id;
  final String label;

  String get storageKey {
    return switch (type) {
      ItemScopeType.personal => 'personal',
      ItemScopeType.group => 'group:$id',
    };
  }

  bool get isPersonal => type == ItemScopeType.personal;
  bool get isGroup => type == ItemScopeType.group;

  @override
  bool operator ==(Object other) {
    return other is ItemScope &&
        other.type == type &&
        other.id == id &&
        other.label == label;
  }

  @override
  int get hashCode => Object.hash(type, id, label);
}
```

- [ ] **Step 4: Run scope model test**

Run:

```powershell
flutter test test/services/group_store_test.dart --plain-name "ItemScope"
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add lib/models/item_scope.dart test/services/group_store_test.dart
git commit -m "feat: add item scope model"
```

---

### Task 2: Extend Item Metadata for Group Rows

**Files:**
- Modify: `lib/models/item.dart`
- Test: `test/services/supabase_service_test.dart`

- [ ] **Step 1: Write parsing coverage for group item metadata**

Add this test to `test/services/supabase_service_test.dart` or the nearest existing `ConsumableItem.fromSupabase` test file:

```dart
test('ConsumableItem parses group ownership metadata', () {
  final item = ConsumableItem.fromSupabase(
    data: <String, dynamic>{
      'id': 'item-1',
      'name': '세제',
      'brand': '브랜드',
      'group_id': 'group-1',
      'registered_by': 'user-1',
      'replacement_cycle_days': 30,
    },
    categoryName: '주방/세제',
    purchases: <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'purchase-1',
        'purchase_date': DateTime.now()
            .subtract(const Duration(days: 5))
            .toIso8601String(),
        'price': 8900,
        'store_name': '마트',
      },
    ],
  );

  expect(item.groupId, 'group-1');
  expect(item.registeredBy, 'user-1');
});
```

- [ ] **Step 2: Run parsing test and confirm it fails**

Run:

```powershell
flutter test test/services/supabase_service_test.dart --plain-name "ConsumableItem parses group ownership metadata"
```

Expected: FAIL because `groupId` and `registeredBy` are not defined.

- [ ] **Step 3: Add metadata fields**

Modify `lib/models/item.dart`:

```dart
class ConsumableItem {
  final String id;
  final String name;
  final String brand;
  final String category;
  final IconData icon;
  final int daysRemaining;
  final int cycleDays;
  final double progress;
  final int? aiPredictedDays;
  final double? aiConfidence;
  final List<PurchaseRecord> purchaseHistory;
  final String? imageUrl;
  final String? groupId;
  final String? registeredBy;

  const ConsumableItem({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    required this.icon,
    required this.daysRemaining,
    required this.cycleDays,
    required this.progress,
    this.aiPredictedDays,
    this.aiConfidence,
    this.purchaseHistory = const [],
    this.imageUrl,
    this.groupId,
    this.registeredBy,
  });
```

Inside `ConsumableItem.fromSupabase`, pass the metadata:

```dart
return ConsumableItem(
  id: data['id'] as String,
  name: data['name'] as String? ?? '',
  brand: data['brand'] as String? ?? '',
  category: categoryName,
  icon: iconForCategory(categoryName),
  daysRemaining: cycleDays - daysSince,
  cycleDays: cycleDays,
  progress: (daysSince / cycleDays).clamp(0.0, 1.0),
  imageUrl: data['image_url'] as String?,
  groupId: data['group_id'] as String?,
  registeredBy: data['registered_by'] as String?,
  aiPredictedDays: aiPrediction?['predicted_cycle_days'] as int?,
  aiConfidence: (aiPrediction?['confidence'] as num?)?.toDouble(),
  purchaseHistory: sorted
      .map(
        (p) => PurchaseRecord(
          id: p['id'] as String?,
          date: DateTime.parse(p['purchase_date']),
          price: (p['price'] as int?) ?? 0,
          store: (p['store_name'] as String?) ?? '',
        ),
      )
      .toList(),
);
```

- [ ] **Step 4: Run parsing test**

Run:

```powershell
flutter test test/services/supabase_service_test.dart --plain-name "ConsumableItem parses group ownership metadata"
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add lib/models/item.dart test/services/supabase_service_test.dart
git commit -m "feat: parse item group metadata"
```

---

### Task 3: Add Supabase Scoped Loading

**Files:**
- Modify: `lib/services/supabase_service.dart`
- Test: `test/services/supabase_service_test.dart`

- [ ] **Step 1: Write gateway tests for scoped item loading**

Add tests that use the existing fake service pattern in `test/services/supabase_service_test.dart`:

```dart
test('loadItemsForScope loads personal items through user id', () async {
  final gateway = _RecordingItemDatabaseGateway()
    ..loadItemsResult = <Map<String, dynamic>>[
      _itemRow(id: 'personal-1', userId: SupabaseService.currentUserId),
    ];
  SupabaseService.debugItemDatabaseGateway = gateway;

  final items = await SupabaseService.loadItemsForScope(
    const ItemScope.personal(),
  );

  expect(items.single.id, 'personal-1');
  expect(gateway.lastUserId, SupabaseService.currentUserId);
  expect(gateway.lastGroupId, isNull);
});

test('loadItemsForScope loads group items through group id', () async {
  final gateway = _RecordingItemDatabaseGateway()
    ..loadItemsResult = <Map<String, dynamic>>[
      _itemRow(id: 'group-item-1', groupId: 'group-1'),
    ];
  SupabaseService.debugItemDatabaseGateway = gateway;

  final items = await SupabaseService.loadItemsForScope(
    const ItemScope.group(id: 'group-1', label: '우리 가족'),
  );

  expect(items.single.id, 'group-item-1');
  expect(items.single.groupId, 'group-1');
  expect(gateway.lastUserId, isNull);
  expect(gateway.lastGroupId, 'group-1');
});
```

- [ ] **Step 2: Run scoped loading tests and confirm they fail**

Run:

```powershell
flutter test test/services/supabase_service_test.dart --plain-name "loadItemsForScope"
```

Expected: FAIL because `loadItemsForScope` and the debug item gateway seam are not defined.

- [ ] **Step 3: Add item database gateway seam and scoped query**

In `lib/services/supabase_service.dart`, import `ItemScope`:

```dart
import '../models/item_scope.dart';
```

Add the debug gateway field near the group gateway:

```dart
static ItemDatabaseGateway? debugItemDatabaseGateway;

static ItemDatabaseGateway get _itemDatabaseGateway {
  return debugItemDatabaseGateway ?? SupabaseItemDatabaseGateway(_db);
}
```

Add this public method:

```dart
static Future<List<ConsumableItem>> loadItemsForScope(ItemScope scope) async {
  final rows = await _itemDatabaseGateway.loadItems(
    userId: scope.isPersonal ? currentUserId : null,
    groupId: scope.isGroup ? scope.id : null,
  );
  return rows.map(_itemFromJoinedRow).toList(growable: false);
}
```

Extract the duplicated item parsing body from `loadItems()`:

```dart
static ConsumableItem _itemFromJoinedRow(Map<String, dynamic> row) {
  final categoryName =
      (row['categories'] as Map<String, dynamic>?)?['name'] as String? ?? '기타';
  final purchases =
      (row['purchases'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
      <Map<String, dynamic>>[];
  final aiList =
      (row['ai_predictions'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
      <Map<String, dynamic>>[];
  final ai = aiList.isNotEmpty ? aiList.last : null;

  return ConsumableItem.fromSupabase(
    data: row,
    categoryName: categoryName,
    purchases: purchases,
    aiPrediction: ai,
  );
}
```

Add the gateway contracts near `GroupDatabaseGateway`:

```dart
abstract class ItemDatabaseGateway {
  Future<List<Map<String, dynamic>>> loadItems({
    required String? userId,
    required String? groupId,
  });
}

class SupabaseItemDatabaseGateway implements ItemDatabaseGateway {
  const SupabaseItemDatabaseGateway(this._client);

  final SupabaseClient _client;

  static const _itemProjection = '''
    id,
    user_id,
    group_id,
    registered_by,
    name,
    brand,
    image_url,
    replacement_cycle_days,
    created_at,
    categories ( id, name ),
    purchases ( id, purchase_date, price, store_name ),
    ai_predictions ( predicted_cycle_days, confidence )
  ''';

  @override
  Future<List<Map<String, dynamic>>> loadItems({
    required String? userId,
    required String? groupId,
  }) async {
    var query = _client.from('product_items').select(_itemProjection);
    if (groupId != null) {
      query = query.eq('group_id', groupId);
    } else {
      query = query.eq('user_id', userId!);
    }
    final rows = await query.order('created_at', ascending: false);
    return rows
        .whereType<Map<String, dynamic>>()
        .map(Map<String, dynamic>.from)
        .toList(growable: false);
  }
}
```

Make existing `loadItems()` delegate to the new method:

```dart
static Future<List<ConsumableItem>> loadItems() async {
  try {
    return await loadItemsForScope(const ItemScope.personal());
  } catch (e) {
    debugPrint('[Supabase] loadItems 오류: $e');
    return [];
  }
}
```

- [ ] **Step 4: Add fake gateway helpers in test**

Add these helpers to `test/services/supabase_service_test.dart`:

```dart
Map<String, dynamic> _itemRow({
  required String id,
  String? userId,
  String? groupId,
}) {
  return <String, dynamic>{
    'id': id,
    'user_id': userId,
    'group_id': groupId,
    'registered_by': userId ?? SupabaseService.currentUserId,
    'name': '세제',
    'brand': '브랜드',
    'image_url': null,
    'replacement_cycle_days': 30,
    'created_at': '2026-05-26T00:00:00.000Z',
    'categories': <String, dynamic>{'id': 'category-1', 'name': '주방/세제'},
    'purchases': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'purchase-1',
        'purchase_date': '2026-05-20',
        'price': 8900,
        'store_name': '마트',
      },
    ],
    'ai_predictions': <Map<String, dynamic>>[],
  };
}

class _RecordingItemDatabaseGateway implements ItemDatabaseGateway {
  String? lastUserId;
  String? lastGroupId;
  List<Map<String, dynamic>> loadItemsResult = const [];

  @override
  Future<List<Map<String, dynamic>>> loadItems({
    required String? userId,
    required String? groupId,
  }) async {
    lastUserId = userId;
    lastGroupId = groupId;
    return loadItemsResult;
  }
}
```

In test tearDown, clear the seam:

```dart
tearDown(() {
  SupabaseService.debugItemDatabaseGateway = null;
});
```

- [ ] **Step 5: Run scoped loading tests**

Run:

```powershell
flutter test test/services/supabase_service_test.dart --plain-name "loadItemsForScope"
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add lib/services/supabase_service.dart test/services/supabase_service_test.dart
git commit -m "feat: load scoped group items"
```

---

### Task 4: Expand GroupStore to Multiple Scopes

**Files:**
- Modify: `lib/services/group_store.dart`
- Modify: `lib/services/supabase_service.dart`
- Test: `test/services/group_store_test.dart`

- [ ] **Step 1: Write GroupStore scope tests**

Add these tests to the `GroupStore` group in `test/services/group_store_test.dart`:

```dart
test('builds personal and joined group scopes after initialize', () async {
  gateway.loadGroupsForUserResult = <Map<String, dynamic>>[
    _groupRow(id: 'group-1', name: '우리 가족'),
    _groupRow(id: 'group-2', name: '사무실'),
  ];

  await GroupStore.instance.initialize();

  final scopes = GroupStore.instance.value.availableScopes;
  expect(scopes.map((scope) => scope.label), ['내 물품', '우리 가족', '사무실']);
  expect(GroupStore.instance.value.selectedScope, const ItemScope.personal());
});

test('selectScope switches to a joined group scope', () async {
  gateway.loadGroupsForUserResult = <Map<String, dynamic>>[
    _groupRow(id: 'group-1', name: '우리 가족'),
  ];
  await GroupStore.instance.initialize();

  GroupStore.instance.selectScope(
    const ItemScope.group(id: 'group-1', label: '우리 가족'),
  );

  expect(GroupStore.instance.value.selectedScope.label, '우리 가족');
});
```

- [ ] **Step 2: Run GroupStore scope tests and confirm they fail**

Run:

```powershell
flutter test test/services/group_store_test.dart --plain-name "scope"
```

Expected: FAIL because `availableScopes`, `selectedScope`, and `loadGroupsForUser` are missing.

- [ ] **Step 3: Add Supabase group-list method**

In `lib/services/supabase_service.dart`, add:

```dart
static Future<List<BuylogGroup>> loadGroupsForUser() async {
  final rows = await _groupDatabaseGateway.loadGroupsForUser(currentUserId);
  return rows.map(BuylogGroup.fromSupabase).toList(growable: false);
}
```

Extend `GroupDatabaseGateway`:

```dart
Future<List<Map<String, dynamic>>> loadGroupsForUser(String userId);
```

Implement it in `SupabaseGroupDatabaseGateway`:

```dart
@override
Future<List<Map<String, dynamic>>> loadGroupsForUser(String userId) async {
  final rows = await _client
      .from('group_members')
      .select('groups ($_groupProjection)')
      .eq('user_id', userId)
      .order('joined_at', ascending: true);

  return rows
      .whereType<Map<String, dynamic>>()
      .map((row) => row['groups'])
      .whereType<Map<String, dynamic>>()
      .map(Map<String, dynamic>.from)
      .toList(growable: false);
}
```

- [ ] **Step 4: Extend GroupState and GroupStore**

Modify `lib/services/group_store.dart`:

```dart
class GroupState {
  GroupState({
    BuylogGroup? group,
    List<BuylogGroup>? groups,
    this.selectedScope = const ItemScope.personal(),
    this.isLoading = false,
    this.isSaving = false,
    this.isRefreshingMembers = false,
    this.errorMessage,
  }) : groups = List<BuylogGroup>.unmodifiable(
         groups ?? (group == null ? const <BuylogGroup>[] : <BuylogGroup>[group]),
       );

  static const _unset = Object();

  final List<BuylogGroup> groups;
  final ItemScope selectedScope;
  final bool isLoading;
  final bool isSaving;
  final bool isRefreshingMembers;
  final String? errorMessage;

  BuylogGroup? get group => groups.isEmpty ? null : groups.first;

  List<ItemScope> get availableScopes {
    return <ItemScope>[
      const ItemScope.personal(),
      for (final group in groups) ItemScope.group(id: group.id, label: group.name),
    ];
  }

  GroupState copyWith({
    List<BuylogGroup>? groups,
    ItemScope? selectedScope,
    bool? isLoading,
    bool? isSaving,
    bool? isRefreshingMembers,
    Object? errorMessage = _unset,
  }) {
    return GroupState(
      groups: groups ?? this.groups,
      selectedScope: selectedScope ?? this.selectedScope,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isRefreshingMembers: isRefreshingMembers ?? this.isRefreshingMembers,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}
```

Update `initialize()` to load all joined groups:

```dart
final groups = await SupabaseService.loadGroupsForUser();
value = GroupState(groups: groups);
```

Add selection method:

```dart
void selectScope(ItemScope scope) {
  final allowed = value.availableScopes.any((candidate) => candidate == scope);
  if (!allowed) return;
  value = value.copyWith(selectedScope: scope, errorMessage: null);
}
```

When creating a group, replace the old single-group assignment:

```dart
final group = await SupabaseService.createGroup(name: trimmedName);
value = GroupState(
  groups: <BuylogGroup>[...previousState.groups, group],
  selectedScope: ItemScope.group(id: group.id, label: group.name),
);
```

- [ ] **Step 5: Update fake group gateway**

In `test/services/group_store_test.dart`, add to the fake gateway:

```dart
List<Map<String, dynamic>> loadGroupsForUserResult = const [];
int loadGroupsForUserCalls = 0;

@override
Future<List<Map<String, dynamic>>> loadGroupsForUser(String userId) async {
  loadGroupsForUserCalls += 1;
  if (loadGroupsForUserResult.isNotEmpty) {
    return loadGroupsForUserResult;
  }
  return loadDefaultGroupResult == null ? const [] : <Map<String, dynamic>>[loadDefaultGroupResult!];
}
```

In `test/screens/group_screen_test.dart`, add the same required method to `_FakeGroupDatabaseGateway`:

```dart
@override
Future<List<Map<String, dynamic>>> loadGroupsForUser(String userId) async {
  return _currentGroup == null
      ? const <Map<String, dynamic>>[]
      : <Map<String, dynamic>>[Map<String, dynamic>.from(_currentGroup!)];
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
git add lib/services/group_store.dart lib/services/supabase_service.dart test/services/group_store_test.dart
git commit -m "feat: expose group item scopes"
```

---

### Task 5: Add GroupItemsStore

**Files:**
- Create: `lib/services/group_items_store.dart`
- Test: `test/services/group_items_store_test.dart`

- [ ] **Step 1: Write GroupItemsStore tests**

Create `test/services/group_items_store_test.dart`:

```dart
import 'package:buylog/models/item_scope.dart';
import 'package:buylog/services/group_items_store.dart';
import 'package:buylog/services/supabase_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _RecordingItemDatabaseGateway gateway;
  late GroupItemsStore store;

  setUp(() {
    gateway = _RecordingItemDatabaseGateway();
    SupabaseService.debugItemDatabaseGateway = gateway;
    store = GroupItemsStore();
  });

  tearDown(() {
    SupabaseService.debugItemDatabaseGateway = null;
    store.dispose();
  });

  test('loads personal items for personal scope', () async {
    gateway.loadItemsResult = <Map<String, dynamic>>[
      _itemRow(id: 'personal-1', userId: SupabaseService.currentUserId),
    ];

    await store.load(const ItemScope.personal());

    expect(store.value.scope, const ItemScope.personal());
    expect(store.value.items.single.id, 'personal-1');
    expect(store.value.isLoading, isFalse);
    expect(store.value.errorMessage, isNull);
  });

  test('loads group items for group scope', () async {
    gateway.loadItemsResult = <Map<String, dynamic>>[
      _itemRow(id: 'group-item-1', groupId: 'group-1'),
    ];

    await store.load(const ItemScope.group(id: 'group-1', label: '우리 가족'));

    expect(store.value.scope.label, '우리 가족');
    expect(store.value.items.single.groupId, 'group-1');
  });

  test('sets Korean error message when scoped load throws', () async {
    gateway.error = StateError('network failed');

    await store.load(const ItemScope.personal());

    expect(store.value.items, isEmpty);
    expect(store.value.isLoading, isFalse);
    expect(store.value.errorMessage, '물품 목록을 불러오지 못했습니다.');
  });
}

Map<String, dynamic> _itemRow({
  required String id,
  String? userId,
  String? groupId,
}) {
  return <String, dynamic>{
    'id': id,
    'user_id': userId,
    'group_id': groupId,
    'registered_by': userId ?? SupabaseService.currentUserId,
    'name': '세제',
    'brand': '브랜드',
    'image_url': null,
    'replacement_cycle_days': 30,
    'created_at': '2026-05-26T00:00:00.000Z',
    'categories': <String, dynamic>{'id': 'category-1', 'name': '주방/세제'},
    'purchases': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'purchase-1',
        'purchase_date': '2026-05-20',
        'price': 8900,
        'store_name': '마트',
      },
    ],
    'ai_predictions': <Map<String, dynamic>>[],
  };
}

class _RecordingItemDatabaseGateway implements ItemDatabaseGateway {
  Object? error;
  List<Map<String, dynamic>> loadItemsResult = const [];

  @override
  Future<List<Map<String, dynamic>>> loadItems({
    required String? userId,
    required String? groupId,
  }) async {
    if (error != null) {
      throw error!;
    }
    return loadItemsResult;
  }
}
```

- [ ] **Step 2: Run new store tests and confirm they fail**

Run:

```powershell
flutter test test/services/group_items_store_test.dart
```

Expected: FAIL because `GroupItemsStore` does not exist.

- [ ] **Step 3: Implement GroupItemsStore**

Create `lib/services/group_items_store.dart`:

```dart
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

  GroupItemsState copyWith({
    ItemScope? scope,
    List<ConsumableItem>? items,
    bool? isLoading,
    String? errorMessage,
  }) {
    return GroupItemsState(
      scope: scope ?? this.scope,
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class GroupItemsStore extends ValueNotifier<GroupItemsState> {
  GroupItemsStore() : super(const GroupItemsState());

  int _requestSerial = 0;

  Future<void> load(ItemScope scope) async {
    final request = ++_requestSerial;
    value = value.copyWith(scope: scope, isLoading: true, errorMessage: null);

    try {
      final items = await SupabaseService.loadItemsForScope(scope);
      if (request != _requestSerial) return;
      value = GroupItemsState(scope: scope, items: items);
    } catch (_) {
      if (request != _requestSerial) return;
      value = GroupItemsState(
        scope: scope,
        errorMessage: '물품 목록을 불러오지 못했습니다.',
      );
    }
  }
}
```

- [ ] **Step 4: Run GroupItemsStore tests**

Run:

```powershell
flutter test test/services/group_items_store_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add lib/services/group_items_store.dart test/services/group_items_store_test.dart
git commit -m "feat: add scoped group items store"
```

---

### Task 6: Build Pure Group Tab Widgets

**Files:**
- Create: `lib/widgets/group/item_scope_tabs.dart`
- Create: `lib/widgets/group/group_scoped_item_list.dart`
- Create: `test/widgets/group/item_scope_tabs_test.dart`

- [ ] **Step 1: Write item scope tabs widget tests**

Create `test/widgets/group/item_scope_tabs_test.dart`:

```dart
import 'package:buylog/models/item_scope.dart';
import 'package:buylog/theme/app_theme.dart';
import 'package:buylog/widgets/group/item_scope_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders personal and group tabs and reports selection', (tester) async {
    ItemScope? selected;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ItemScopeTabs(
            scopes: const <ItemScope>[
              ItemScope.personal(),
              ItemScope.group(id: 'group-1', label: '우리 가족'),
              ItemScope.group(id: 'group-2', label: '사무실'),
            ],
            selectedScope: const ItemScope.personal(),
            onSelected: (scope) => selected = scope,
          ),
        ),
      ),
    );

    expect(find.text('내 물품'), findsOneWidget);
    expect(find.text('우리 가족'), findsOneWidget);
    expect(find.text('사무실'), findsOneWidget);

    await tester.tap(find.text('사무실'));
    expect(selected, const ItemScope.group(id: 'group-2', label: '사무실'));
  });
}
```

- [ ] **Step 2: Run widget test and confirm it fails**

Run:

```powershell
flutter test test/widgets/group/item_scope_tabs_test.dart
```

Expected: FAIL because `ItemScopeTabs` does not exist.

- [ ] **Step 3: Implement `ItemScopeTabs`**

Create `lib/widgets/group/item_scope_tabs.dart`:

```dart
import 'package:flutter/material.dart';

import '../../models/item_scope.dart';
import '../../theme/app_theme.dart';

class ItemScopeTabs extends StatelessWidget {
  const ItemScopeTabs({
    super.key,
    required this.scopes,
    required this.selectedScope,
    required this.onSelected,
  });

  final List<ItemScope> scopes;
  final ItemScope selectedScope;
  final ValueChanged<ItemScope> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: scopes.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final scope = scopes[index];
          final active = scope == selectedScope;
          return ChoiceChip(
            label: Text(scope.label),
            selected: active,
            onSelected: (_) => onSelected(scope),
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.surface,
            labelStyle: TextStyle(
              color: active ? Colors.white : AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: BorderSide(
                color: active ? AppColors.primary : AppColors.border,
                width: 0.5,
              ),
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 4: Implement scoped item list widget**

Create `lib/widgets/group/group_scoped_item_list.dart`:

```dart
import 'package:flutter/material.dart';

import '../../services/group_items_store.dart';
import '../../theme/app_theme.dart';
import '../../screens/items_screen.dart';

class GroupScopedItemList extends StatelessWidget {
  const GroupScopedItemList({super.key, required this.state});

  final GroupItemsState state;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.errorMessage?.isNotEmpty == true) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Text(
          state.errorMessage!,
          style: const TextStyle(color: AppColors.danger, fontSize: 13),
        ),
      );
    }

    if (state.items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Text(
          '표시할 물품이 없습니다.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        children: [
          for (final item in state.items) ...[
            ItemRow(item: item),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run widget tests**

Run:

```powershell
flutter test test/widgets/group/item_scope_tabs_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add lib/widgets/group/item_scope_tabs.dart lib/widgets/group/group_scoped_item_list.dart test/widgets/group/item_scope_tabs_test.dart
git commit -m "feat: add group scope tab widgets"
```

---

### Task 7: Wire Tabs into GroupScreen

**Files:**
- Modify: `lib/screens/group_screen.dart`
- Test: `test/screens/group_screen_test.dart`

- [ ] **Step 1: Write GroupScreen tab switching test**

Add this widget test to `test/screens/group_screen_test.dart`:

```dart
testWidgets('renders scope tabs and switches selected group tab', (tester) async {
  GroupStore.instance.value = GroupState(
    groups: <BuylogGroup>[
      _group(id: 'group-1', name: '우리 가족'),
      _group(id: 'group-2', name: '사무실'),
    ],
  );

  await tester.pumpWidget(_wrap());

  expect(find.text('내 물품'), findsOneWidget);
  expect(find.text('우리 가족'), findsOneWidget);
  expect(find.text('사무실'), findsOneWidget);

  await tester.tap(find.text('사무실'));
  await tester.pump();

  expect(GroupStore.instance.value.selectedScope, const ItemScope.group(id: 'group-2', label: '사무실'));
});
```

Update the test helper `_group` to accept arguments:

```dart
BuylogGroup _group({
  String id = 'group-1',
  String name = '우리 가족',
}) {
  return BuylogGroup(
    id: id,
    name: name,
    inviteCode: 'BUY-ABC123',
    createdBy: 'user-1',
    createdAt: DateTime.parse('2026-05-26T00:00:00.000Z'),
    members: [
      BuylogGroupMember(
        id: 'member-1',
        userId: 'user-1',
        displayName: '소유자',
        role: GroupRole.owner,
        joinedAt: DateTime.parse('2026-05-26T00:00:00.000Z'),
      ),
    ],
  );
}
```

- [ ] **Step 2: Run GroupScreen test and confirm it fails**

Run:

```powershell
flutter test test/screens/group_screen_test.dart --plain-name "renders scope tabs"
```

Expected: FAIL because `GroupScreen` does not render scope tabs yet.

- [ ] **Step 3: Convert GroupScreen to a stateful screen with scoped item store**

Change `GroupScreen` to own a `GroupItemsStore`:

```dart
class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  late final GroupItemsStore _itemsStore;

  @override
  void initState() {
    super.initState();
    _itemsStore = GroupItemsStore();
    _itemsStore.load(GroupStore.instance.value.selectedScope);
  }

  @override
  void dispose() {
    _itemsStore.dispose();
    super.dispose();
  }

  void _selectScope(ItemScope scope) {
    GroupStore.instance.selectScope(scope);
    _itemsStore.load(scope);
  }
```

- [ ] **Step 4: Render tabs and scoped items**

Inside the `ValueListenableBuilder<GroupState>` body in `group_screen.dart`, use this layout:

```dart
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
      ItemScopeTabs(
        scopes: state.availableScopes,
        selectedScope: state.selectedScope,
        onSelected: _selectScope,
      ),
      const SizedBox(height: 16),
      if (state.selectedScope.isGroup && state.group != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _GroupCard(
            group: state.groups.firstWhere(
              (group) => group.id == state.selectedScope.id,
              orElse: () => state.group!,
            ),
            isRefreshingMembers: state.isRefreshingMembers,
          ),
        )
      else if (state.groups.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _EmptyGroupState(errorMessage: state.errorMessage),
        ),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          '${state.selectedScope.label} 목록',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      ValueListenableBuilder<GroupItemsState>(
        valueListenable: _itemsStore,
        builder: (context, itemState, _) {
          return GroupScopedItemList(state: itemState);
        },
      ),
    ],
  ),
);
```

Add imports:

```dart
import '../models/item_scope.dart';
import '../services/group_items_store.dart';
import '../widgets/group/group_scoped_item_list.dart';
import '../widgets/group/item_scope_tabs.dart';
```

- [ ] **Step 5: Run GroupScreen tests**

Run:

```powershell
flutter test test/screens/group_screen_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add lib/screens/group_screen.dart test/screens/group_screen_test.dart
git commit -m "feat: add group tab switching UI"
```

---

### Task 8: Full Verification and Cleanup

**Files:**
- No new files.

- [ ] **Step 1: Run analyzer**

Run:

```powershell
flutter analyze --no-fatal-infos
```

Expected: exit code 0.

- [ ] **Step 2: Run tests**

Run:

```powershell
flutter test
```

Expected: all tests pass.

- [ ] **Step 3: Check worktree scope**

Run:

```powershell
git status --short
```

Expected: only files from this plan are modified or untracked. Do not stage `.claude/`, `.mcp.json`, `.omx/`, `.omc/`, or unrelated docs.

- [ ] **Step 4: Final commit**

If Task 1-7 commits were squashed or skipped during execution, create one scoped commit:

```powershell
git add lib/models/item_scope.dart lib/models/item.dart lib/services/supabase_service.dart lib/services/group_store.dart lib/services/group_items_store.dart lib/screens/group_screen.dart lib/widgets/group/item_scope_tabs.dart lib/widgets/group/group_scoped_item_list.dart test/services/group_store_test.dart test/services/group_items_store_test.dart test/services/supabase_service_test.dart test/screens/group_screen_test.dart test/widgets/group/item_scope_tabs_test.dart
git commit -m "feat: implement group item tab switching"
```

Expected: commit contains only the group tab switching feature.

---

## Self-Review

- Spec coverage: The requested `내 물품 | 그룹1 | 그룹2 | ...` tab UI is covered by `ItemScopeTabs`, `GroupStore.availableScopes`, and `GroupScreen` wiring.
- Business logic boundary: Item scope construction, selected scope state, and scoped item loading live in models/services, not widget classes.
- Data correctness: `loadItemsForScope` reads personal rows through `user_id` and group rows through `group_id`, matching the existing schema constraint.
- Existing screen stability: `HomeScreen` and `ItemsScreen` continue using `ItemStore.instance`; the new scoped store is isolated to `GroupScreen`.
- Tests: Model, service, store, widget, and screen tests are included before implementation steps.
- Verification: `flutter analyze --no-fatal-infos` and `flutter test` are the required final checks.
