# Group Page Dashboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 현재 그룹 탭을 단순 그룹 카드와 목록에서, 그룹 현황을 한눈에 보고 바로 행동할 수 있는 협업 대시보드로 확장한다.

**Architecture:** 1차 범위는 새 Supabase 테이블 없이 기존 `BuylogGroup`, `BuylogGroupMember`, `ConsumableItem`, `ItemScope` 데이터만 사용한다. D-day 집계와 필터링은 Flutter 위젯이 아니라 별도 서비스/모델 helper에 두고, `GroupScreen`은 상태를 조합해 순수 UI 위젯에 전달한다.

**Tech Stack:** Flutter, Dart, `ValueNotifier`, `flutter/services` Clipboard, existing Supabase gateway seams, `flutter_test`.

---

## 기능 방향

1. **그룹 현황 요약**
   - 그룹 물품 총 개수, 7일 이내 교체, 30일 이내 교체, 여유 물품 수를 보여준다.
   - 선택 scope가 개인이면 개인 물품 요약, 그룹이면 해당 그룹 요약을 보여준다.

2. **그룹 액션 강화**
   - 그룹 카드에 초대 코드 복사 버튼을 추가한다.
   - 새로고침, 그룹 탈퇴는 기존 로직을 유지하되 액션 영역으로 정리한다.
   - 그룹 물품이 비어 있으면 “그룹에 제품 추가” CTA를 보여준다.

3. **공유 물품 탐색성 강화**
   - `전체`, `긴급`, `곧`, `여유` 필터 칩을 그룹 탭 목록에도 적용한다.
   - 필터 count는 현재 로드된 scope items 기준으로 계산한다.

4. **멤버 영역 밀도 개선**
   - 멤버 수, owner 표시, 멤버 아바타/이름 목록을 카드 안에서 더 작고 스캔하기 좋게 정리한다.
   - 멤버 새로고침은 유지한다.

5. **후속 후보로 분리**
   - 초대 코드로 그룹 참여, 멤버별 담당 물품, 활동 로그, 그룹 리포트, 교체 요청/알림은 DB/RLS 설계가 필요하므로 별도 PR로 뺀다.

## Current Repo Context

- Root `AGENTS.md` 기준상 새 비즈니스 로직은 테스트가 없으면 `[P1]`이다.
- Flutter 위젯에 비즈니스 로직을 직접 넣으면 `[P1]`이다. 집계와 필터링은 `lib/services` 또는 모델 helper에 둔다.
- 그룹 화면은 `lib/screens/group_screen.dart`에 있고, 현재 `ItemScopeTabs`, `_GroupCard`, `_MemberRow`, `GroupScopedItemList`를 조합한다.
- 그룹 목록/선택 상태는 `lib/services/group_store.dart`의 `GroupStore`가 관리한다.
- 선택 scope의 물품은 `lib/services/group_items_store.dart`의 `GroupItemsStore`가 로드한다.
- 물품 row UI는 `lib/screens/items_screen.dart`의 `ItemRow`를 재사용하고 있다.
- 기존 widget tests는 `test/screens/group_screen_test.dart`, store tests는 `test/services/group_items_store_test.dart`와 `test/services/group_store_test.dart`에 있다.

## File Structure

- Create: `lib/services/group_dashboard_summary.dart`
  - `GroupItemFilter`, `GroupDashboardSummary`, `GroupDashboardSummaryBuilder`를 둔다.
  - items 기반 count, 필터링, empty CTA 조건을 계산한다.
- Modify: `lib/services/group_items_store.dart`
  - 선택 filter를 state에 포함한다.
  - `selectFilter(...)`를 추가하고 items 자체는 다시 로드하지 않는다.
- Create: `test/services/group_dashboard_summary_test.dart`
  - D-day bucket, 필터 결과, personal/group label 독립성을 검증한다.
- Modify: `test/services/group_items_store_test.dart`
  - filter 변경이 items reload 없이 state만 바꾸는지 검증한다.
- Create: `lib/widgets/group/group_status_summary.dart`
  - summary metric strip UI.
- Create: `lib/widgets/group/group_item_filter_chips.dart`
  - filter chip UI.
- Modify: `lib/widgets/group/group_scoped_item_list.dart`
  - 필터링된 items와 empty CTA copy를 받도록 변경한다.
- Modify: `lib/screens/group_screen.dart`
  - summary, filter chips, quick action card를 조합한다.
  - 초대 코드 복사는 `Clipboard.setData`를 사용한다.
- Modify: `test/screens/group_screen_test.dart`
  - summary counts, filter chip, invite copy SnackBar, empty CTA를 검증한다.

---

### Task 1: Add Dashboard Summary Logic

**Files:**
- Create: `lib/services/group_dashboard_summary.dart`
- Create: `test/services/group_dashboard_summary_test.dart`

- [ ] **Step 1: Write failing summary tests**

Create `test/services/group_dashboard_summary_test.dart`:

```dart
import 'package:buylog/models/item.dart';
import 'package:buylog/models/item_scope.dart';
import 'package:buylog/services/group_dashboard_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GroupDashboardSummaryBuilder', () {
    test('counts items by replacement urgency', () {
      final summary = GroupDashboardSummaryBuilder.build(
        scope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
        items: [
          _item('expired', daysRemaining: -1),
          _item('urgent', daysRemaining: 7),
          _item('soon', daysRemaining: 30),
          _item('fresh', daysRemaining: 31),
        ],
        selectedFilter: GroupItemFilter.all,
      );

      expect(summary.totalCount, 4);
      expect(summary.urgentCount, 2);
      expect(summary.soonCount, 1);
      expect(summary.freshCount, 1);
      expect(summary.scopeTitle, '우리 가족 물품');
    });

    test('filters items without changing summary totals', () {
      final summary = GroupDashboardSummaryBuilder.build(
        scope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
        items: [
          _item('urgent', daysRemaining: 3),
          _item('soon', daysRemaining: 20),
          _item('fresh', daysRemaining: 45),
        ],
        selectedFilter: GroupItemFilter.soon,
      );

      expect(summary.totalCount, 3);
      expect(summary.filteredItems.map((item) => item.id), ['soon']);
      expect(summary.countFor(GroupItemFilter.all), 3);
      expect(summary.countFor(GroupItemFilter.urgent), 1);
      expect(summary.countFor(GroupItemFilter.soon), 1);
      expect(summary.countFor(GroupItemFilter.fresh), 1);
    });
  });
}

ConsumableItem _item(String id, {required int daysRemaining}) {
  return ConsumableItem(
    id: id,
    name: id,
    brand: '브랜드',
    category: '주방/세제',
    icon: ConsumableItem.iconForCategory('주방/세제'),
    daysRemaining: daysRemaining,
    cycleDays: 30,
    progress: 0.5,
  );
}
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run:

```powershell
flutter test test/services/group_dashboard_summary_test.dart
```

Expected: FAIL because `group_dashboard_summary.dart` does not exist.

- [ ] **Step 3: Implement the summary service**

Create `lib/services/group_dashboard_summary.dart`:

```dart
import '../models/item.dart';
import '../models/item_scope.dart';

enum GroupItemFilter {
  all('전체'),
  urgent('긴급'),
  soon('곧'),
  fresh('여유');

  const GroupItemFilter(this.label);

  final String label;
}

class GroupDashboardSummary {
  const GroupDashboardSummary({
    required this.scope,
    required this.selectedFilter,
    required this.totalCount,
    required this.urgentCount,
    required this.soonCount,
    required this.freshCount,
    required this.filteredItems,
  });

  final ItemScope scope;
  final GroupItemFilter selectedFilter;
  final int totalCount;
  final int urgentCount;
  final int soonCount;
  final int freshCount;
  final List<ConsumableItem> filteredItems;

  String get scopeTitle => scope.isGroup ? '${scope.label} 물품' : '내 물품';

  int countFor(GroupItemFilter filter) {
    return switch (filter) {
      GroupItemFilter.all => totalCount,
      GroupItemFilter.urgent => urgentCount,
      GroupItemFilter.soon => soonCount,
      GroupItemFilter.fresh => freshCount,
    };
  }
}

class GroupDashboardSummaryBuilder {
  const GroupDashboardSummaryBuilder._();

  static GroupDashboardSummary build({
    required ItemScope scope,
    required List<ConsumableItem> items,
    required GroupItemFilter selectedFilter,
  }) {
    final sorted = List<ConsumableItem>.of(items)
      ..sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));

    return GroupDashboardSummary(
      scope: scope,
      selectedFilter: selectedFilter,
      totalCount: sorted.length,
      urgentCount: sorted.where(_isUrgent).length,
      soonCount: sorted.where(_isSoon).length,
      freshCount: sorted.where(_isFresh).length,
      filteredItems: List<ConsumableItem>.unmodifiable(
        sorted.where((item) => _matches(item, selectedFilter)),
      ),
    );
  }

  static bool _matches(ConsumableItem item, GroupItemFilter filter) {
    return switch (filter) {
      GroupItemFilter.all => true,
      GroupItemFilter.urgent => _isUrgent(item),
      GroupItemFilter.soon => _isSoon(item),
      GroupItemFilter.fresh => _isFresh(item),
    };
  }

  static bool _isUrgent(ConsumableItem item) => item.daysRemaining <= 7;

  static bool _isSoon(ConsumableItem item) {
    return item.daysRemaining > 7 && item.daysRemaining <= 30;
  }

  static bool _isFresh(ConsumableItem item) => item.daysRemaining > 30;
}
```

- [ ] **Step 4: Run the focused test and verify it passes**

Run:

```powershell
flutter test test/services/group_dashboard_summary_test.dart
```

Expected: PASS.

### Task 2: Add Filter State to GroupItemsStore

**Files:**
- Modify: `lib/services/group_items_store.dart`
- Modify: `test/services/group_items_store_test.dart`

- [ ] **Step 1: Write failing filter state test**

Add this test to `test/services/group_items_store_test.dart`:

```dart
test('selectFilter updates filter without reloading items', () async {
  final gateway = _RecordingItemDatabaseGateway()
    ..loadItemsResult = <Map<String, dynamic>>[
      _itemRow(id: 'item-1', daysAgo: 1),
    ];
  SupabaseService.debugItemDatabaseGateway = gateway;
  final store = GroupItemsStore();

  await store.load(const ItemScope.group(id: 'group-1', label: '우리 가족'));
  store.selectFilter(GroupItemFilter.urgent);

  expect(store.value.selectedFilter, GroupItemFilter.urgent);
  expect(store.value.items.single.id, 'item-1');
  expect(gateway.loadItemsCalls, 1);
});
```

Also add:

```dart
import 'package:buylog/services/group_dashboard_summary.dart';
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run:

```powershell
flutter test test/services/group_items_store_test.dart
```

Expected: FAIL because `selectedFilter` and `selectFilter` do not exist.

- [ ] **Step 3: Implement filter state**

Update `lib/services/group_items_store.dart`:

```dart
import 'package:flutter/foundation.dart';

import '../models/item.dart';
import '../models/item_scope.dart';
import 'group_dashboard_summary.dart';
import 'supabase_service.dart';

class GroupItemsState {
  const GroupItemsState({
    this.scope = const ItemScope.personal(),
    this.items = const [],
    this.selectedFilter = GroupItemFilter.all,
    this.isLoading = false,
    this.errorMessage,
  });

  final ItemScope scope;
  final List<ConsumableItem> items;
  final GroupItemFilter selectedFilter;
  final bool isLoading;
  final String? errorMessage;

  GroupItemsState copyWith({
    ItemScope? scope,
    List<ConsumableItem>? items,
    GroupItemFilter? selectedFilter,
    bool? isLoading,
    String? errorMessage,
  }) {
    return GroupItemsState(
      scope: scope ?? this.scope,
      items: items ?? this.items,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class GroupItemsStore extends ValueNotifier<GroupItemsState> {
  GroupItemsStore() : super(const GroupItemsState());

  int _requestSerial = 0;

  Future<void> load(ItemScope scope) async {
    if (value.isLoading && value.scope == scope) {
      return;
    }

    final request = ++_requestSerial;
    final selectedFilter = value.scope == scope
        ? value.selectedFilter
        : GroupItemFilter.all;
    value = GroupItemsState(
      scope: scope,
      items: value.items,
      selectedFilter: selectedFilter,
      isLoading: true,
    );

    try {
      final items = await SupabaseService.loadItemsForScope(scope);
      if (request != _requestSerial) return;
      value = GroupItemsState(
        scope: scope,
        items: items,
        selectedFilter: selectedFilter,
      );
    } catch (_) {
      if (request != _requestSerial) return;
      value = GroupItemsState(
        scope: scope,
        selectedFilter: selectedFilter,
        errorMessage: '물품 목록을 불러오지 못했습니다.',
      );
    }
  }

  void selectFilter(GroupItemFilter filter) {
    if (value.selectedFilter == filter) return;
    value = value.copyWith(selectedFilter: filter, errorMessage: null);
  }
}
```

- [ ] **Step 4: Run the focused test and verify it passes**

Run:

```powershell
flutter test test/services/group_items_store_test.dart
```

Expected: PASS.

### Task 3: Add Dashboard UI Widgets

**Files:**
- Create: `lib/widgets/group/group_status_summary.dart`
- Create: `lib/widgets/group/group_item_filter_chips.dart`

- [ ] **Step 1: Create status summary widget**

Create `lib/widgets/group/group_status_summary.dart`:

```dart
import 'package:flutter/material.dart';

import '../../services/group_dashboard_summary.dart';
import '../../theme/app_theme.dart';

class GroupStatusSummary extends StatelessWidget {
  const GroupStatusSummary({super.key, required this.summary});

  final GroupDashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            label: '전체',
            value: summary.totalCount,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricTile(
            label: '긴급',
            value: summary.urgentCount,
            color: AppColors.danger,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricTile(
            label: '곧',
            value: summary.soonCount,
            color: AppColors.warning,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricTile(
            label: '여유',
            value: summary.freshCount,
            color: AppColors.success,
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Create filter chips widget**

Create `lib/widgets/group/group_item_filter_chips.dart`:

```dart
import 'package:flutter/material.dart';

import '../../services/group_dashboard_summary.dart';
import '../../theme/app_theme.dart';

class GroupItemFilterChips extends StatelessWidget {
  const GroupItemFilterChips({
    super.key,
    required this.summary,
    required this.onSelected,
  });

  final GroupDashboardSummary summary;
  final ValueChanged<GroupItemFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final filter in GroupItemFilter.values)
          ChoiceChip(
            label: Text('${filter.label} ${summary.countFor(filter)}'),
            selected: summary.selectedFilter == filter,
            onSelected: (_) => onSelected(filter),
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.surface,
            labelStyle: TextStyle(
              color: summary.selectedFilter == filter
                  ? Colors.white
                  : AppColors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: BorderSide(
                color: summary.selectedFilter == filter
                    ? AppColors.primary
                    : AppColors.border,
                width: 0.5,
              ),
            ),
          ),
      ],
    );
  }
}
```

### Task 4: Wire Dashboard Into GroupScreen

**Files:**
- Modify: `lib/widgets/group/group_scoped_item_list.dart`
- Modify: `lib/screens/group_screen.dart`
- Modify: `test/screens/group_screen_test.dart`

- [ ] **Step 1: Write failing screen tests**

Add tests to `test/screens/group_screen_test.dart`:

```dart
testWidgets('renders dashboard counts for selected group items', (tester) async {
  final itemGateway = _RecordingItemDatabaseGateway()
    ..loadItemsResult = <Map<String, dynamic>>[
      _itemRow(id: 'urgent', groupId: 'group-1', daysAgo: 29),
      _itemRow(id: 'fresh', groupId: 'group-1', daysAgo: 1),
    ];
  SupabaseService.debugItemDatabaseGateway = itemGateway;
  GroupStore.instance.value = GroupState(
    groups: <BuylogGroup>[_group()],
    selectedScope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
  );

  await tester.pumpWidget(_wrap());
  await tester.pump();

  expect(find.text('전체'), findsOneWidget);
  expect(find.text('긴급'), findsOneWidget);
  expect(find.text('곧'), findsOneWidget);
  expect(find.text('여유'), findsOneWidget);
  expect(find.text('전체 2'), findsOneWidget);
  expect(find.text('긴급 1'), findsOneWidget);
});

testWidgets('copies group invite code from group card', (tester) async {
  GroupStore.instance.value = GroupState(
    groups: <BuylogGroup>[_group()],
    selectedScope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
  );

  await tester.pumpWidget(_wrap());
  await tester.tap(find.byTooltip('초대 코드 복사'));
  await tester.pump();

  expect(find.text('초대 코드가 복사되었습니다.'), findsOneWidget);
});
```

Update `_itemRow` helper in the same test file to accept `daysAgo`:

```dart
Map<String, dynamic> _itemRow({
  required String id,
  String? groupId,
  int daysAgo = 0,
}) {
  final purchaseDate = DateTime.now()
      .subtract(Duration(days: daysAgo))
      .toIso8601String()
      .substring(0, 10);
  return <String, dynamic>{
    'id': id,
    'user_id': null,
    'group_id': groupId,
    'registered_by': SupabaseService.currentUserId,
    'name': id,
    'brand': '브랜드',
    'image_url': null,
    'replacement_cycle_days': 30,
    'created_at': '2026-05-27T00:00:00.000Z',
    'categories': <String, dynamic>{'id': 'category-1', 'name': '주방/세제'},
    'purchases': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'purchase-$id',
        'purchase_date': purchaseDate,
        'price': 1000,
        'store_name': '마트',
      },
    ],
    'ai_predictions': <Map<String, dynamic>>[],
  };
}
```

- [ ] **Step 2: Run the focused screen tests and verify they fail**

Run:

```powershell
flutter test test/screens/group_screen_test.dart
```

Expected: FAIL because dashboard widgets and copy action are not wired.

- [ ] **Step 3: Update item list widget contract**

Change `GroupScopedItemList` to accept `items`, `isLoading`, `errorMessage`, and `emptyMessage` rather than the whole store state:

```dart
class GroupScopedItemList extends StatelessWidget {
  const GroupScopedItemList({
    super.key,
    required this.items,
    required this.isLoading,
    this.errorMessage,
    required this.emptyMessage,
  });

  final List<ConsumableItem> items;
  final bool isLoading;
  final String? errorMessage;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage?.isNotEmpty == true) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Text(
          errorMessage!,
          style: const TextStyle(color: AppColors.danger, fontSize: 13),
        ),
      );
    }

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Text(
          emptyMessage,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        children: [
          for (final item in items) ...[
            ItemRow(item: item),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
```

Add missing import:

```dart
import '../../models/item.dart';
```

- [ ] **Step 4: Wire summary and copy action in GroupScreen**

In `lib/screens/group_screen.dart`, add imports:

```dart
import 'package:flutter/services.dart';

import '../services/group_dashboard_summary.dart';
import '../widgets/group/group_item_filter_chips.dart';
import '../widgets/group/group_status_summary.dart';
```

Add method inside `_GroupScreenState`:

```dart
Future<void> _copyInviteCode(String inviteCode) async {
  await Clipboard.setData(ClipboardData(text: inviteCode));
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('초대 코드가 복사되었습니다.')),
  );
}
```

Pass `onCopyInviteCode` to `_GroupCard`, add the callback field, and place this button near the invite code:

```dart
IconButton(
  tooltip: '초대 코드 복사',
  onPressed: () => onCopyInviteCode(group.inviteCode),
  icon: const Icon(Icons.copy, size: 18),
)
```

Replace the current `ValueListenableBuilder<GroupItemsState>` body with:

```dart
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
          emptyMessage: summary.scope.isGroup
              ? '아직 이 그룹에 등록된 물품이 없습니다.'
              : '표시할 내 물품이 없습니다.',
        ),
      ],
    );
  },
),
```

- [ ] **Step 5: Run the focused screen tests and verify they pass**

Run:

```powershell
flutter test test/screens/group_screen_test.dart
```

Expected: PASS.

### Task 5: Full Verification

**Files:**
- No new files.

- [ ] **Step 1: Run analyzer**

Run:

```powershell
flutter analyze --no-fatal-infos
```

Expected: PASS with no errors.

- [ ] **Step 2: Run full tests**

Run:

```powershell
flutter test
```

Expected: PASS.

- [ ] **Step 3: Manual smoke check**

Run the app and check:

```powershell
flutter run -d chrome
```

Expected:
- 그룹 탭에서 `내 물품`과 그룹 scope 전환이 유지된다.
- 그룹 scope에서 summary counts가 목록과 일치한다.
- filter chip을 눌러도 네트워크 reload 없이 목록만 바뀐다.
- 초대 코드 복사 버튼을 누르면 SnackBar가 표시된다.
- 빈 그룹은 빈 상태 문구가 자연스럽게 보인다.
