# Group Item Auto Group ID Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 그룹 탭에서 물품을 등록하거나 OCR 등록을 진행할 때 선택된 그룹의 `group_id`가 `product_items.group_id`에 자동 저장되도록 만든다.

**Architecture:** `AddItemScreen`은 대상 범위(`ItemScope`)를 전달만 하고, `user_id`와 `group_id` 결정은 `SupabaseService.saveItem` 내부에서 처리한다. `ItemStore`는 기존 개인 물품 저장 API를 유지하되 그룹 스코프 저장을 받을 수 있게 확장하고, 그룹 물품은 개인 홈 목록 상태에 섞지 않는다. 카테고리도 같은 스코프 기준으로 조회/생성해 그룹 물품이 개인 카테고리에 묶이지 않게 한다.

**Tech Stack:** Flutter, Dart, `ValueNotifier`, `supabase_flutter`, `flutter_test`.

---

## Current Repo Context

- 그룹 선택 상태는 `lib/services/group_store.dart`의 `GroupStore.instance.value.selectedScope`가 갖고 있다.
- 그룹 물품 목록 로드는 `lib/services/group_items_store.dart`가 `SupabaseService.loadItemsForScope(scope)`로 수행한다.
- 등록 화면은 `lib/screens/add_item_screen.dart`이고 현재 `ItemStore.instance.add(item)` 또는 `update(item)`만 호출한다.
- 실제 저장은 `lib/services/supabase_service.dart`의 `saveItem(ConsumableItem item)`이 담당하지만 현재 항상 `user_id = currentUserId`, `group_id = null` 형태로 저장된다.
- `product_items` 스키마는 `user_id` 또는 `group_id` 중 정확히 하나만 있어야 하는 `chk_product_owner` 제약을 갖고 있다.
- `categories`도 `user_id`와 `group_id`를 갖고 있으므로 그룹 물품 저장 시 카테고리 조회/생성도 그룹 스코프를 따라야 한다.
- 저장 관련 비즈니스 로직은 Flutter 위젯이 아니라 서비스/스토어에 둔다.

## File Structure

- Modify: `lib/services/supabase_service.dart`
  - `saveItem`에 `ItemScope scope` 파라미터를 추가한다.
  - `scope` 기준으로 `product_items.user_id`, `product_items.group_id`, `registered_by`를 만든다.
  - `_ensureCategory`를 스코프 인자로 확장해 개인/그룹 카테고리를 분리한다.
  - `ItemDatabaseGateway`를 저장 테스트가 가능한 형태로 확장한다.
- Modify: `lib/services/item_store.dart`
  - `add`/`update`에 `ItemScope scope` 선택 파라미터를 추가한다.
  - 개인 스코프는 기존처럼 낙관적 상태 업데이트와 롤백을 유지한다.
  - 그룹 스코프는 개인 목록(`ItemStore.value`)에 섞지 않고 저장만 수행한다.
  - 중복 후보 탐색이 스코프를 고려하도록 한다.
- Modify: `lib/screens/add_item_screen.dart`
  - `targetScope`를 받아 저장 시 `ItemStore`로 전달한다.
  - 편집 모드에서 `editItem.groupId`가 있으면 그룹 스코프를 기본값으로 사용한다.
  - 중복 병합 확인은 스코프에 맞는 후보만 대상으로 한다.
  - 저장 성공 시 `Navigator.pop(context, true)`를 반환한다.
- Modify: `lib/screens/scan_screen.dart`
  - `targetScope`를 받아 OCR 결과 검토용 `AddItemScreen`에 전달한다.
- Modify: `lib/main.dart`
  - 그룹 탭에서도 FAB를 표시한다.
  - 그룹 탭에서 등록을 열 때 현재 선택된 그룹 스코프를 `AddItemScreen`/`ScanScreen`에 전달한다.
  - 선택된 그룹이 없으면 개인 스코프로 등록한다.
- Modify: `lib/screens/group_screen.dart`
  - 기존 하단 FAB를 살리기 위해 `MainNavigation`에서 스코프를 전달한다.
  - 목록 갱신은 그룹 탭 재진입 또는 수동 새로고침 없이도 확인되도록 `GroupScreen`이 `ItemStore` 저장 이벤트를 구독하는 방식으로 처리한다.
- Modify: `lib/services/item_store.dart`
  - 저장 성공 이벤트를 발행해 현재 선택된 그룹 목록이 자동 재조회되게 한다.
- Test: `test/services/supabase_service_test.dart`
  - 그룹 스코프 저장 payload와 그룹 카테고리 소유자 값을 검증한다.
  - 개인 스코프 저장 payload가 기존 동작을 유지하는지 검증한다.
- Test: `test/services/group_items_store_test.dart`
  - `ItemDatabaseGateway` 인터페이스 확장에 맞춰 기존 fake를 갱신한다.
- Test: `test/services/item_store_test.dart`
  - 그룹 저장이 개인 목록에 섞이지 않는지 검증한다.
  - 개인 저장 롤백이 기존처럼 동작하는지 유지 검증한다.
  - 중복 후보 탐색이 스코프를 섞지 않는지 검증한다.
- Test: `test/screens/add_item_screen_test.dart`
  - 그룹 스코프 등록 화면이 저장 시 `group_id` 경로를 사용하는지 fake gateway로 검증한다.

---

### Task 1: Supabase 저장 로직을 ItemScope 기반으로 확장

**Files:**
- Modify: `lib/services/supabase_service.dart`
- Test: `test/services/supabase_service_test.dart`
- Test: `test/services/group_items_store_test.dart`

- [ ] **Step 1: 저장 gateway fake에 기록 필드를 추가한다**

`test/services/supabase_service_test.dart`의 `_RecordingItemDatabaseGateway`를 아래 형태로 확장한다. 기존 `loadItems` 테스트에서 쓰는 필드는 유지한다.

```dart
class _RecordingItemDatabaseGateway implements ItemDatabaseGateway {
  String? lastUserId;
  String? lastGroupId;
  List<Map<String, dynamic>> loadItemsResult = const [];

  String? ensureCategoryName;
  String? ensureCategoryUserId;
  String? ensureCategoryGroupId;
  Map<String, dynamic>? upsertedItemPayload;
  final List<Map<String, dynamic>> insertedPurchasePayloads = [];
  String ensuredCategoryId = 'category-1';

  @override
  Future<List<Map<String, dynamic>>> loadItems({
    required String? userId,
    required String? groupId,
  }) async {
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
    ensureCategoryName = name;
    ensureCategoryUserId = userId;
    ensureCategoryGroupId = groupId;
    return ensuredCategoryId;
  }

  @override
  Future<void> upsertItem(Map<String, dynamic> payload) async {
    upsertedItemPayload = Map<String, dynamic>.from(payload);
  }

  @override
  Future<void> insertPurchase(Map<String, dynamic> payload) async {
    insertedPurchasePayloads.add(Map<String, dynamic>.from(payload));
  }
}
```

- [ ] **Step 2: 그룹 스코프 저장 실패 테스트를 작성한다**

`test/services/supabase_service_test.dart`의 `SupabaseService.loadItemsForScope` group 뒤에 새 group을 추가한다.

```dart
group('SupabaseService.saveItem scoped ownership', () {
  tearDown(() {
    SupabaseService.debugItemDatabaseGateway = null;
  });

  test('saves group items with group_id and null user_id', () async {
    final gateway = _RecordingItemDatabaseGateway();
    SupabaseService.debugItemDatabaseGateway = gateway;

    await SupabaseService.saveItem(
      ConsumableItem(
        id: 'item-1',
        name: '세제',
        brand: '브랜드',
        category: '주방/세제',
        icon: ConsumableItem.iconForCategory('주방/세제'),
        daysRemaining: 30,
        cycleDays: 30,
        progress: 0,
        purchaseHistory: [
          PurchaseRecord(
            date: DateTime(2026, 5, 27),
            price: 8900,
            store: '마트',
          ),
        ],
      ),
      scope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
    );

    expect(gateway.ensureCategoryName, '주방/세제');
    expect(gateway.ensureCategoryUserId, isNull);
    expect(gateway.ensureCategoryGroupId, 'group-1');
    expect(gateway.upsertedItemPayload?['id'], 'item-1');
    expect(gateway.upsertedItemPayload?['user_id'], isNull);
    expect(gateway.upsertedItemPayload?['group_id'], 'group-1');
    expect(
      gateway.upsertedItemPayload?['registered_by'],
      SupabaseService.currentUserId,
    );
    expect(gateway.insertedPurchasePayloads.single['product_item_id'], 'item-1');
  });

  test('saves personal items with user_id and null group_id', () async {
    final gateway = _RecordingItemDatabaseGateway();
    SupabaseService.debugItemDatabaseGateway = gateway;

    await SupabaseService.saveItem(
      ConsumableItem(
        id: 'item-1',
        name: '샴푸',
        brand: '브랜드',
        category: '헤어/바디',
        icon: ConsumableItem.iconForCategory('헤어/바디'),
        daysRemaining: 30,
        cycleDays: 30,
        progress: 0,
      ),
    );

    expect(gateway.ensureCategoryUserId, SupabaseService.currentUserId);
    expect(gateway.ensureCategoryGroupId, isNull);
    expect(gateway.upsertedItemPayload?['user_id'], SupabaseService.currentUserId);
    expect(gateway.upsertedItemPayload?['group_id'], isNull);
  });
});
```

- [ ] **Step 3: focused test가 컴파일 실패하는지 확인한다**

Run:

```powershell
flutter test test/services/supabase_service_test.dart
```

Expected: FAIL because `ItemDatabaseGateway.ensureCategory`, `upsertItem`, `insertPurchase`, and `SupabaseService.saveItem(scope:)` do not exist.

- [ ] **Step 4: ItemDatabaseGateway 인터페이스를 확장한다**

`lib/services/supabase_service.dart`의 `ItemDatabaseGateway`를 아래처럼 바꾼다.

```dart
abstract class ItemDatabaseGateway {
  Future<List<Map<String, dynamic>>> loadItems({
    required String? userId,
    required String? groupId,
  });

  Future<String> ensureCategory({
    required String name,
    required String? userId,
    required String? groupId,
  });

  Future<void> upsertItem(Map<String, dynamic> payload);

  Future<void> insertPurchase(Map<String, dynamic> payload);
}
```

- [ ] **Step 5: SupabaseItemDatabaseGateway에 저장 메서드를 구현한다**

`SupabaseItemDatabaseGateway` 안에 아래 메서드를 추가한다.

```dart
@override
Future<String> ensureCategory({
  required String name,
  required String? userId,
  required String? groupId,
}) async {
  dynamic query = _client.from('categories').select('id').eq('name', name);
  if (groupId != null) {
    query = query.eq('group_id', groupId);
  } else {
    query = query.eq('user_id', userId!);
  }

  final existing = await query.maybeSingle();
  if (existing != null) {
    return existing['id'] as String;
  }

  final created = await _client
      .from('categories')
      .insert({
        'user_id': userId,
        'group_id': groupId,
        'name': name,
        'icon': SupabaseService._iconNameForCategory(name),
        'color': '#4F7FFF',
        'sort_order': 0,
      })
      .select('id')
      .single();

  return created['id'] as String;
}

@override
Future<void> upsertItem(Map<String, dynamic> payload) async {
  await _client.from('product_items').upsert(payload);
}

@override
Future<void> insertPurchase(Map<String, dynamic> payload) async {
  await _client.from('purchases').insert(payload);
}
```

`SupabaseItemDatabaseGateway`는 `SupabaseService`와 같은 Dart library 파일에 있으므로 private static인 `SupabaseService._iconNameForCategory(name)`를 직접 호출할 수 있다.

- [ ] **Step 6: saveItem에 scope를 전달하고 payload를 바꾼다**

`SupabaseService.saveItem` 시그니처와 본문을 아래 구조로 바꾼다.

```dart
static Future<void> saveItem(
  ConsumableItem item, {
  ItemScope scope = const ItemScope.personal(),
}) async {
  final uid = currentUserId;
  final userId = scope.isPersonal ? uid : null;
  final groupId = scope.isGroup ? scope.id : null;

  try {
    final categoryId = await _itemDatabaseGateway.ensureCategory(
      name: item.category,
      userId: userId,
      groupId: groupId,
    );

    await _itemDatabaseGateway.upsertItem({
      'id': item.id,
      'user_id': userId,
      'group_id': groupId,
      'registered_by': uid,
      'category_id': categoryId,
      'name': item.name,
      'brand': item.brand,
      'image_url': item.imageUrl,
      'replacement_cycle_days': item.cycleDays,
    });

    for (final record in item.purchaseHistory) {
      if (record.id == null) {
        await _itemDatabaseGateway.insertPurchase({
          'product_item_id': item.id,
          'purchased_by': uid,
          'purchase_date': record.date.toIso8601String().substring(0, 10),
          'price': record.price,
          'store_name': record.store,
          'quantity': 1,
        });
      }
    }

    debugPrint('[Supabase] saveItem 완료: ${item.name} (${item.id})');
  } catch (e) {
    debugPrint('[Supabase] saveItem 오류: $e');
    rethrow;
  }
}
```

- [ ] **Step 7: 기존 `_categoryCache`와 `_ensureCategory`를 제거한다**

`SupabaseService`의 `_categoryCache` 필드와 private `_ensureCategory` 메서드는 gateway 구현으로 이동했으므로 삭제한다. 이때 다른 호출자가 없는지 확인한다.

Run:

```powershell
rg -n "_ensureCategory|_categoryCache" lib test
```

Expected: no matches.

- [ ] **Step 8: 다른 ItemDatabaseGateway fake도 새 인터페이스에 맞춘다**

`test/services/group_items_store_test.dart`의 `_RecordingItemDatabaseGateway`에 저장용 no-op 메서드를 추가한다. 이 테스트는 load만 검증하므로 기록 필드는 필요 없다.

```dart
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
```

- [ ] **Step 9: focused test 통과를 확인한다**

Run:

```powershell
flutter test test/services/supabase_service_test.dart test/services/group_items_store_test.dart
```

Expected: PASS.

- [ ] **Step 10: commit**

```powershell
git add lib/services/supabase_service.dart test/services/supabase_service_test.dart test/services/group_items_store_test.dart
git commit -m "feat: save items with scoped ownership"
```

---

### Task 2: ItemStore를 스코프 저장에 맞게 확장

**Files:**
- Modify: `lib/services/item_store.dart`
- Test: `test/services/item_store_test.dart`

- [ ] **Step 1: ItemStore 테스트에 fake gateway와 scope import를 추가한다**

`test/services/item_store_test.dart` 상단 import를 확장한다.

```dart
import 'package:buylog/models/item_scope.dart';
import 'package:buylog/services/supabase_service.dart';
```

파일 하단에 fake gateway를 추가한다.

```dart
class _RecordingItemDatabaseGateway implements ItemDatabaseGateway {
  Object? saveError;
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
    if (saveError != null) throw saveError!;
    upsertedItemPayload = Map<String, dynamic>.from(payload);
  }

  @override
  Future<void> insertPurchase(Map<String, dynamic> payload) async {}
}
```

- [ ] **Step 2: 그룹 저장이 개인 목록을 오염시키지 않는 실패 테스트를 추가한다**

`group('ItemStore rollback', ...)` 안에 테스트를 추가한다.

```dart
test('add: group scope saves without appending to personal list', () async {
  final gateway = _RecordingItemDatabaseGateway();
  SupabaseService.debugItemDatabaseGateway = gateway;
  addTearDown(() => SupabaseService.debugItemDatabaseGateway = null);

  ItemStore.instance.value = [_seed('personal')];

  await ItemStore.instance.add(
    _seed('group-item'),
    scope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
  );

  expect(ItemStore.instance.value.map((item) => item.id), ['personal']);
  expect(gateway.upsertedItemPayload?['group_id'], 'group-1');
  expect(gateway.upsertedItemPayload?['user_id'], isNull);
});
```

- [ ] **Step 3: 중복 후보가 스코프를 섞지 않는 실패 테스트를 추가한다**

```dart
test('findDuplicateByName only matches items in the requested scope', () {
  ItemStore.instance.value = [
    _seed('personal', name: '세제'),
    ConsumableItem(
      id: 'group-item',
      name: '세제',
      brand: 'B',
      category: '기타',
      icon: ConsumableItem.iconForCategory('기타'),
      daysRemaining: 10,
      cycleDays: 30,
      progress: 0.5,
      groupId: 'group-1',
    ),
  ];

  final personal = ItemStore.instance.findDuplicateByName(
    ' 세제 ',
    scope: const ItemScope.personal(),
  );
  final group = ItemStore.instance.findDuplicateByName(
    '세제',
    scope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
  );
  final otherGroup = ItemStore.instance.findDuplicateByName(
    '세제',
    scope: const ItemScope.group(id: 'group-2', label: '사무실'),
  );

  expect(personal?.id, 'personal');
  expect(group?.id, 'group-item');
  expect(otherGroup, isNull);
});
```

- [ ] **Step 4: focused test가 실패하는지 확인한다**

Run:

```powershell
flutter test test/services/item_store_test.dart
```

Expected: FAIL because `ItemStore.add(scope:)` and `findDuplicateByName` do not exist.

- [ ] **Step 5: ItemStore에 ItemScope import와 중복 탐색 메서드를 추가한다**

`lib/services/item_store.dart` import를 추가한다.

```dart
import '../models/item_scope.dart';
```

`ItemStore` 클래스 안에 메서드를 추가한다.

```dart
ConsumableItem? findDuplicateByName(
  String name, {
  ItemScope scope = const ItemScope.personal(),
}) {
  final normalized = name.trim().toLowerCase();
  if (normalized.isEmpty) return null;

  final matches = value.where((item) {
    final sameName = item.name.trim().toLowerCase() == normalized;
    if (!sameName) return false;
    if (scope.isPersonal) return item.groupId == null;
    return item.groupId == scope.id;
  });

  return matches.isEmpty ? null : matches.first;
}
```

- [ ] **Step 6: add/update를 스코프 인자로 확장한다**

`add`와 `update`를 아래처럼 바꾼다.

```dart
Future<void> add(
  ConsumableItem item, {
  ItemScope scope = const ItemScope.personal(),
}) async {
  if (scope.isGroup) {
    await SupabaseService.saveItem(item, scope: scope);
    return;
  }

  final previous = List<ConsumableItem>.unmodifiable(value);
  value = [...value, item];
  try {
    await SupabaseService.saveItem(item, scope: scope);
  } catch (e) {
    value = List.of(previous);
    rethrow;
  }
}

Future<void> update(
  ConsumableItem updated, {
  ItemScope scope = const ItemScope.personal(),
}) async {
  if (scope.isGroup) {
    await SupabaseService.saveItem(updated, scope: scope);
    return;
  }

  final previous = List<ConsumableItem>.unmodifiable(value);
  value = value
      .map((item) => item.id == updated.id ? updated : item)
      .toList();
  try {
    await SupabaseService.saveItem(updated, scope: scope);
  } catch (e) {
    value = List.of(previous);
    rethrow;
  }
}
```

- [ ] **Step 7: focused test 통과를 확인한다**

Run:

```powershell
flutter test test/services/item_store_test.dart
```

Expected: PASS.

- [ ] **Step 8: commit**

```powershell
git add lib/services/item_store.dart test/services/item_store_test.dart
git commit -m "feat: keep group item saves scoped"
```

---

### Task 3: AddItemScreen과 ScanScreen에 targetScope를 전달

**Files:**
- Modify: `lib/screens/add_item_screen.dart`
- Modify: `lib/screens/scan_screen.dart`
- Test: `test/screens/add_item_screen_test.dart`

- [ ] **Step 1: AddItemScreen 위젯 테스트 파일을 만든다**

Create `test/screens/add_item_screen_test.dart`.

```dart
import 'package:buylog/models/item_scope.dart';
import 'package:buylog/screens/add_item_screen.dart';
import 'package:buylog/services/supabase_service.dart';
import 'package:buylog/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _RecordingItemDatabaseGateway gateway;

  setUp(() {
    gateway = _RecordingItemDatabaseGateway();
    SupabaseService.debugItemDatabaseGateway = gateway;
  });

  tearDown(() {
    SupabaseService.debugItemDatabaseGateway = null;
  });

  testWidgets('manual group registration saves with selected group id', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const AddItemScreen(
          targetScope: ItemScope.group(id: 'group-1', label: '우리 가족'),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), '세제');
    await tester.enterText(find.byType(TextFormField).at(1), '브랜드');
    await tester.enterText(find.byType(TextFormField).at(2), '30');
    await tester.enterText(find.byType(TextFormField).at(3), '8900');
    await tester.enterText(find.byType(TextFormField).at(4), '마트');

    await tester.tap(find.text('등록 완료'));
    await tester.pumpAndSettle();

    expect(gateway.upsertedItemPayload?['group_id'], 'group-1');
    expect(gateway.upsertedItemPayload?['user_id'], isNull);
  });
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

- [ ] **Step 2: focused test가 실패하는지 확인한다**

Run:

```powershell
flutter test test/screens/add_item_screen_test.dart
```

Expected: FAIL because `AddItemScreen.targetScope` does not exist.

- [ ] **Step 3: AddItemScreen에 targetScope를 추가한다**

`lib/screens/add_item_screen.dart`에 import를 추가한다.

```dart
import '../models/item_scope.dart';
```

`AddItemScreen` 필드와 생성자를 아래처럼 바꾼다.

```dart
class AddItemScreen extends StatefulWidget {
  final OcrPrefillData? prefillData;
  final ConsumableItem? editItem;
  final bool isOcrReview;
  final ItemScope? targetScope;

  const AddItemScreen({
    super.key,
    this.prefillData,
    this.editItem,
    this.isOcrReview = false,
    this.targetScope,
  });
```

`_AddItemScreenState`에 effective scope getter를 추가한다.

```dart
ItemScope get _effectiveScope {
  final explicit = widget.targetScope;
  if (explicit != null) return explicit;

  final editGroupId = widget.editItem?.groupId;
  if (editGroupId != null && editGroupId.isNotEmpty) {
    return ItemScope.group(id: editGroupId, label: '그룹');
  }

  return const ItemScope.personal();
}
```

- [ ] **Step 4: 중복 후보 탐색을 scope-aware API로 바꾼다**

`_submit`의 duplicate 계산 부분을 아래처럼 바꾼다.

```dart
final duplicate = ItemStore.instance.findDuplicateByName(
  _nameCtrl.text,
  scope: _effectiveScope,
);
```

기존 `.cast<ConsumableItem?>().firstWhere(...)` 블록은 제거한다.

- [ ] **Step 5: 저장 호출에 scope를 전달하고 성공 결과를 반환한다**

`_submit` 하단 저장 호출을 아래처럼 바꾼다.

```dart
if (_isEditing) {
  await ItemStore.instance.update(item, scope: _effectiveScope);
} else {
  await ItemStore.instance.add(item, scope: _effectiveScope);
}
```

저장 성공 후 pop을 아래처럼 바꾼다.

```dart
Navigator.pop(context, true);
```

중복 병합 경로의 `ItemStore.instance.update(merged)`도 아래처럼 바꾼다.

```dart
await ItemStore.instance.update(merged, scope: _effectiveScope);
```

중복 병합 성공 pop도 아래처럼 바꾼다.

```dart
Navigator.pop(context, true);
```

- [ ] **Step 6: ScanScreen에 targetScope를 추가하고 전달한다**

`lib/screens/scan_screen.dart`에 import를 추가한다.

```dart
import '../models/item_scope.dart';
```

`ScanScreen`을 아래처럼 바꾼다.

```dart
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, this.targetScope = const ItemScope.personal()});

  final ItemScope targetScope;
```

OCR 결과에서 `AddItemScreen`을 열 때 scope를 전달한다.

```dart
builder: (_) => AddItemScreen(
  targetScope: widget.targetScope,
  prefillData: OcrPrefillData(
    productName: ocrItem.nameCtrl.text.trim(),
    price: price,
    storeName: _storeCtrl.text.trim(),
    purchaseDate: _scanDate,
  ),
  isOcrReview: true,
),
```

- [ ] **Step 7: focused screen test 통과를 확인한다**

Run:

```powershell
flutter test test/screens/add_item_screen_test.dart
```

Expected: PASS.

- [ ] **Step 8: commit**

```powershell
git add lib/screens/add_item_screen.dart lib/screens/scan_screen.dart test/screens/add_item_screen_test.dart
git commit -m "feat: pass item registration scope"
```

---

### Task 4: 그룹 탭 등록 진입점에 현재 그룹 스코프 연결

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/screens/group_screen.dart`
- Modify: `lib/services/item_store.dart`
- Test: `test/screens/group_screen_test.dart`

- [ ] **Step 1: MainNavigation에 현재 등록 scope helper를 추가한다**

`lib/main.dart`의 `MainNavigationState` 안에 helper를 추가한다.

```dart
ItemScope _currentAddScope() {
  if (_currentIndex != 1) {
    return const ItemScope.personal();
  }

  final state = GroupStore.instance.value;
  final scope = state.selectedScope;
  if (scope.isGroup) {
    return scope;
  }

  return const ItemScope.personal();
}
```

`main.dart` 상단에는 이미 `GroupStore`가 import되어 있다. `ItemScope` import를 추가한다.

```dart
import 'models/item_scope.dart';
```

- [ ] **Step 2: 그룹 탭에서도 FAB를 노출한다**

`build`의 `showFab` 계산을 아래처럼 바꾼다.

```dart
final showFab = _currentIndex == 0 || _currentIndex == 1 || _currentIndex == 2;
```

- [ ] **Step 3: scan/manual 등록에 scope를 전달한다**

`_openAddSheet`의 switch 시작 전에 scope를 계산한다.

```dart
final targetScope = _currentAddScope();
```

`ScanScreen` 생성자를 바꾼다.

```dart
ScanScreen(targetScope: targetScope),
```

`AddItemScreen` 생성자를 바꾼다.

```dart
AddItemScreen(targetScope: targetScope),
```

- [ ] **Step 4: 그룹 목록 갱신 이벤트를 추가한다**

`lib/services/item_store.dart`의 `ItemStore` 위쪽에 저장 이벤트 타입을 추가한다. 같은 스코프에 연속 저장해도 매번 listener가 호출되도록 `serial`을 포함한다.

```dart
class ItemSaveEvent {
  const ItemSaveEvent({required this.scope, required this.serial});

  final ItemScope scope;
  final int serial;
}
```

`ItemStore` 안에 필드와 getter를 추가한다.

```dart
int _saveEventSerial = 0;
final ValueNotifier<ItemSaveEvent?> _lastSaveEvent =
    ValueNotifier<ItemSaveEvent?>(null);

ValueListenable<ItemSaveEvent?> get lastSaveEvent => _lastSaveEvent;
```

`ItemStore` 안에 private helper를 추가한다.

```dart
void _notifySaved(ItemScope scope) {
  _saveEventSerial += 1;
  _lastSaveEvent.value = ItemSaveEvent(
    scope: scope,
    serial: _saveEventSerial,
  );
}
```

`add`와 `update`에서 `SupabaseService.saveItem` 성공 직후 `_notifySaved(scope);`를 호출한다. 개인/그룹 모두 호출한다.

`GroupScreen`의 `initState`에 listener를 추가한다.

```dart
ItemStore.instance.lastSaveEvent.addListener(_reloadAfterScopedSave);
```

`dispose`에서 제거한다.

```dart
ItemStore.instance.lastSaveEvent.removeListener(_reloadAfterScopedSave);
```

`_GroupScreenState`에 메서드를 추가한다.

```dart
void _reloadAfterScopedSave() {
  final event = ItemStore.instance.lastSaveEvent.value;
  if (event == null || event.scope != GroupStore.instance.value.selectedScope) {
    return;
  }
  _itemsStore.load(event.scope);
}
```

`group_screen.dart`에 import를 추가한다.

```dart
import '../services/item_store.dart';
```

- [ ] **Step 5: group screen test를 확장한다**

`test/screens/group_screen_test.dart`에 필요한 import를 추가한다.

```dart
import 'package:buylog/models/item.dart';
import 'package:buylog/services/item_store.dart';
import 'package:buylog/services/supabase_service.dart';
```

테스트 파일 하단에 helper를 추가한다.

```dart
ConsumableItem _seedItem(String id) {
  return ConsumableItem(
    id: id,
    name: '세제',
    brand: '브랜드',
    category: '주방/세제',
    icon: ConsumableItem.iconForCategory('주방/세제'),
    daysRemaining: 30,
    cycleDays: 30,
    progress: 0,
  );
}

Map<String, dynamic> _itemRow({required String id, String? groupId}) {
  return <String, dynamic>{
    'id': id,
    'user_id': null,
    'group_id': groupId,
    'registered_by': SupabaseService.currentUserId,
    'name': '세제',
    'brand': '브랜드',
    'image_url': null,
    'replacement_cycle_days': 30,
    'created_at': '2026-05-27T00:00:00.000Z',
    'categories': <String, dynamic>{'id': 'category-1', 'name': '주방/세제'},
    'purchases': <Map<String, dynamic>>[],
    'ai_predictions': <Map<String, dynamic>>[],
  };
}

class _RecordingItemDatabaseGateway implements ItemDatabaseGateway {
  int loadItemsCalls = 0;
  List<Map<String, dynamic>> loadItemsResult = const [];

  @override
  Future<List<Map<String, dynamic>>> loadItems({
    required String? userId,
    required String? groupId,
  }) async {
    loadItemsCalls += 1;
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

그 다음 "저장 이벤트가 선택 그룹 목록을 다시 로드한다" 테스트를 추가한다.

```dart
testWidgets('reloads selected group items after a scoped save event', (
  tester,
) async {
  final itemGateway = _RecordingItemDatabaseGateway()
    ..loadItemsResult = <Map<String, dynamic>>[
      _itemRow(id: 'group-item-1', groupId: 'group-1'),
    ];
  SupabaseService.debugItemDatabaseGateway = itemGateway;
  addTearDown(() => SupabaseService.debugItemDatabaseGateway = null);

  GroupStore.instance.value = GroupState(
    groups: <BuylogGroup>[_group(id: 'group-1', name: '우리 가족')],
    selectedScope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
  );

  await tester.pumpWidget(const MaterialApp(home: GroupScreen()));
  await tester.pump();

  await ItemStore.instance.add(
    _seedItem('new-group-item'),
    scope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
  );
  await tester.pump();

  expect(itemGateway.loadItemsCalls, greaterThanOrEqualTo(2));
});
```

- [ ] **Step 6: focused tests를 확인한다**

Run:

```powershell
flutter test test/screens/group_screen_test.dart
```

Expected: PASS.

- [ ] **Step 7: commit**

```powershell
git add lib/main.dart lib/screens/group_screen.dart lib/services/item_store.dart test/screens/group_screen_test.dart
git commit -m "feat: open group item registration from group tab"
```

---

### Task 5: 전체 회귀 확인

**Files:**
- Verify only.

- [ ] **Step 1: formatting 적용**

Run:

```powershell
dart format lib/services/supabase_service.dart lib/services/item_store.dart lib/screens/add_item_screen.dart lib/screens/scan_screen.dart lib/main.dart lib/screens/group_screen.dart test/services/supabase_service_test.dart test/services/item_store_test.dart test/screens/add_item_screen_test.dart test/screens/group_screen_test.dart
```

Expected: files formatted without parse errors.

- [ ] **Step 2: analyzer 실행**

Run:

```powershell
flutter analyze --no-fatal-infos
```

Expected: no errors.

- [ ] **Step 3: full test suite 실행**

Run:

```powershell
flutter test
```

Expected: PASS.

- [ ] **Step 4: manual smoke test**

Run the app:

```powershell
flutter run -d windows
```

Manual checks:

1. 그룹 탭으로 이동한다.
2. 그룹 탭에서 그룹 스코프가 선택된 상태로 FAB를 누른다.
3. 수동 등록으로 물품을 저장한다.
4. Supabase `product_items`에서 새 row가 `user_id = null`, `group_id = 선택 그룹 id`, `registered_by = currentUserId`인지 확인한다.
5. 같은 그룹 목록에 새 물품이 표시되는지 확인한다.
6. 홈 또는 모든 제품 탭의 개인 목록에 그룹 물품이 섞이지 않는지 확인한다.

- [ ] **Step 5: final commit**

```powershell
git status --short
git commit --allow-empty -m "test: verify scoped group item registration"
```

---

## Self-Review

- Spec coverage: 그룹 물품 등록 시 `group_id` 자동 할당은 Task 1과 Task 3에서 저장 경로에 반영된다. 그룹 탭에서 선택된 그룹을 등록 화면으로 전달하는 흐름은 Task 4가 담당한다.
- Tests: 신규 비즈니스 로직은 `supabase_service_test.dart`, `item_store_test.dart`, `add_item_screen_test.dart`, `group_screen_test.dart`에서 보호한다.
- Null safety: `ItemScope? targetScope`는 `_effectiveScope`에서 항상 non-null `ItemScope`로 정규화한다.
- Widget boundary: `user_id/group_id` 결정은 위젯이 아니라 `SupabaseService.saveItem`에서 처리한다.
- Scope risk: 그룹 저장 시 개인 `ItemStore.value`를 갱신하지 않아 홈/모든 제품 개인 목록 오염을 막는다.
