# Report Scope Tabs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 리포트 페이지에서 `내 물품 / 그룹명1 / 그룹명2` 토글로 리포트 집계 대상을 전환할 수 있게 만든다.

**Architecture:** 리포트 집계 로직은 기존 `ReportService`에 그대로 두고, `ReportsScreen`은 선택된 `ItemScope`의 물품 목록을 `ReportService.fromItems(...)`에 넣어 기존 섹션을 재사용한다. 개인 물품은 앱의 단일 소스인 `ItemStore`, 그룹 물품은 리포트 전용 `ReportItemsStore`가 `SupabaseService.loadItemsForScope()`로 로드한다. 그룹 목록과 선택 가능한 토글은 `GroupStore`의 `visibleGroups`에서 파생하며, 그룹이 삭제되거나 이름이 바뀌면 선택 scope를 보정한다.

**Tech Stack:** Flutter, Dart, Material 3, `ValueNotifier`, existing Supabase gateway seams, `flutter_test`.

---

## Current Context

- `lib/screens/reports_screen.dart`는 현재 `ReportService.fromItems(SampleData.items)`로만 집계해서 실제 `ItemStore`와 그룹 물품을 보지 않는다.
- `lib/services/report_service.dart`는 이미 `List<ConsumableItem>` 기반으로 월간, 연간, 카테고리, 인사이트, 재구매 예측, 가격 변동을 계산한다. scope 개념을 넣을 필요가 없다.
- `lib/models/item_scope.dart`는 `ItemScope.personal()`의 label을 `내 물품`로 가지고 있고, 그룹 scope는 `ItemScope.group(id, label)`로 표현한다.
- `lib/services/group_store.dart`는 가입 그룹 목록을 `visibleGroups`로 제공한다.
- `lib/services/supabase_service.dart`는 `loadItemsForScope(ItemScope scope)`를 이미 제공하고, 테스트에서는 `SupabaseService.debugItemDatabaseGateway`로 로드 결과를 제어할 수 있다.
- 루트 `AGENTS.md` 기준상 새 비즈니스 로직에는 테스트가 필요하고, 위젯에 비즈니스 로직을 직접 넣으면 안 된다.

## Scope

In scope:

1. 리포트 상단에 `내 물품`과 가입 그룹 이름을 가로 토글로 표시한다.
2. 기본 선택은 `내 물품`이다.
3. 그룹 토글을 누르면 해당 그룹 물품을 로드하고 모든 리포트 섹션을 그 그룹 데이터로 다시 집계한다.
4. 그룹 로딩 중에는 리포트 본문 상단에 작은 로딩 상태를 표시한다.
5. 그룹 로드 실패 시 현재 선택된 그룹 label은 유지하고, 리포트 본문 상단에 한국어 에러 메시지를 표시한다.
6. 그룹 목록이 변경되어 선택된 그룹이 사라지면 `내 물품`으로 되돌린다.
7. 그룹 이름이 변경되면 토글 label과 선택 scope label을 새 이름으로 보정한다.
8. scope를 바꾸면 월 선택 상세 상태(`_selectedMonth`)는 초기화한다.
9. 그룹 물품 추가/수정 저장 이벤트가 현재 선택된 그룹과 일치하면 리포트를 다시 로드한다.

Out of scope:

1. DB schema, RLS, Supabase migration 변경.
2. 그룹 페이지 UI 변경.
3. 리포트 집계 공식 변경.
4. 멤버별 리포트, 담당자별 리포트, 그룹 전체와 개인 합산 리포트.
5. 신규 패키지 추가.

## File Structure

- Create: `lib/services/report_items_store.dart`
  - 리포트 화면에서 그룹 scope 물품을 비동기로 로드한다.
  - stale request, 중복 로드, 에러 메시지를 처리한다.
- Create: `test/services/report_items_store_test.dart`
  - personal/group scope 로드, stale result 무시, 같은 scope 중복 로드 방지, 에러 상태를 검증한다.
- Create: `lib/widgets/reports/report_scope_tabs.dart`
  - `ItemScope` 목록을 `ChoiceChip` 가로 토글로 보여준다.
  - 선택/콜백만 담당하고 scope 목록 생성 로직은 갖지 않는다.
- Create: `test/widgets/reports/report_scope_tabs_test.dart`
  - `내 물품`과 그룹 label 렌더링, 탭 선택 콜백을 검증한다.
- Modify: `lib/screens/reports_screen.dart`
  - `SampleData.items` 직접 사용을 제거하고 `ItemStore`, `GroupStore`, `ReportItemsStore`를 조합한다.
  - 테스트용 `ValueListenable`/store factory 주입 파라미터를 추가한다.
  - 기존 월간/연간/차트/카테고리 섹션은 선택 scope의 item list로 만든 `ReportService`를 그대로 사용한다.
- Modify: `test/screens/reports_screen_year_view_test.dart`
  - `ReportsScreen`에 개인 fixture를 주입하도록 변경해 기존 연간 모드 회귀 테스트를 유지한다.
- Modify: `test/screens/reports_screen_month_filter_test.dart`
  - `ReportsScreen`에 개인 fixture를 주입하도록 변경해 기존 월 선택 회귀 테스트를 유지한다.
- Create: `test/screens/reports_screen_scope_test.dart`
  - scope 토글 표시, 그룹 선택 후 로드/집계 전환, 그룹 삭제 fallback, 그룹명 변경 반영, 저장 이벤트 reload를 검증한다.

---

### Task 1: Add Report Items Store

**Files:**
- Create: `lib/services/report_items_store.dart`
- Create: `test/services/report_items_store_test.dart`

- [ ] **Step 1: Write failing tests for scoped report item loading**

Create `test/services/report_items_store_test.dart`:

```dart
import 'dart:async';

import 'package:buylog/models/item_scope.dart';
import 'package:buylog/services/report_items_store.dart';
import 'package:buylog/services/supabase_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _RecordingItemDatabaseGateway gateway;
  late ReportItemsStore store;

  setUp(() {
    gateway = _RecordingItemDatabaseGateway();
    SupabaseService.debugItemDatabaseGateway = gateway;
    store = ReportItemsStore();
  });

  tearDown(() {
    SupabaseService.debugItemDatabaseGateway = null;
    store.dispose();
  });

  test('loads personal items for personal report scope', () async {
    gateway.loadItemsResult = <Map<String, dynamic>>[
      _itemRow(id: 'personal-1', userId: SupabaseService.currentUserId),
    ];

    await store.load(const ItemScope.personal());

    expect(store.value.scope, const ItemScope.personal());
    expect(store.value.items.single.id, 'personal-1');
    expect(store.value.isLoading, isFalse);
    expect(store.value.errorMessage, isNull);
    expect(gateway.lastUserId, SupabaseService.currentUserId);
    expect(gateway.lastGroupId, isNull);
  });

  test('loads group items for group report scope', () async {
    gateway.loadItemsResult = <Map<String, dynamic>>[
      _itemRow(id: 'group-item-1', groupId: 'group-1'),
    ];

    await store.load(const ItemScope.group(id: 'group-1', label: '우리 가족'));

    expect(store.value.scope, const ItemScope.group(id: 'group-1', label: '우리 가족'));
    expect(store.value.items.single.groupId, 'group-1');
    expect(gateway.lastUserId, isNull);
    expect(gateway.lastGroupId, 'group-1');
  });

  test('ignores stale result when a newer scope finishes first', () async {
    final first = Completer<List<Map<String, dynamic>>>();
    final second = Completer<List<Map<String, dynamic>>>();
    gateway.pendingResults
      ..add(first)
      ..add(second);

    final firstLoad = store.load(const ItemScope.personal());
    await Future<void>.delayed(Duration.zero);
    final secondLoad = store.load(
      const ItemScope.group(id: 'group-1', label: '우리 가족'),
    );
    await Future<void>.delayed(Duration.zero);

    second.complete(<Map<String, dynamic>>[
      _itemRow(id: 'group-item-1', groupId: 'group-1'),
    ]);
    await secondLoad;

    first.complete(<Map<String, dynamic>>[
      _itemRow(id: 'personal-1', userId: SupabaseService.currentUserId),
    ]);
    await firstLoad;

    expect(store.value.scope.label, '우리 가족');
    expect(store.value.items.single.id, 'group-item-1');
  });

  test('does not start duplicate load while same scope is loading', () async {
    final pending = Completer<List<Map<String, dynamic>>>();
    gateway.pendingResults.add(pending);

    final firstLoad = store.load(const ItemScope.group(id: 'group-1', label: '우리 가족'));
    await Future<void>.delayed(Duration.zero);
    await store.load(const ItemScope.group(id: 'group-1', label: '우리 가족'));

    expect(gateway.loadItemsCalls, 1);

    pending.complete(<Map<String, dynamic>>[
      _itemRow(id: 'group-item-1', groupId: 'group-1'),
    ]);
    await firstLoad;
  });

  test('sets Korean error message when scoped load throws', () async {
    gateway.error = StateError('network failed');

    await store.load(const ItemScope.group(id: 'group-1', label: '우리 가족'));

    expect(store.value.scope.label, '우리 가족');
    expect(store.value.items, isEmpty);
    expect(store.value.isLoading, isFalse);
    expect(store.value.errorMessage, '리포트 데이터를 불러오지 못했습니다.');
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
        'id': 'purchase-$id',
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
  int loadItemsCalls = 0;
  String? lastUserId;
  String? lastGroupId;
  List<Map<String, dynamic>> loadItemsResult = const [];
  final List<Completer<List<Map<String, dynamic>>>> pendingResults = [];

  @override
  Future<List<Map<String, dynamic>>> loadItems({
    required String? userId,
    required String? groupId,
  }) async {
    loadItemsCalls += 1;
    lastUserId = userId;
    lastGroupId = groupId;
    if (error != null) throw error!;
    if (pendingResults.isNotEmpty) {
      return pendingResults.removeAt(0).future;
    }
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

- [ ] **Step 2: Run the new failing service tests**

Run:

```bash
flutter test test/services/report_items_store_test.dart
```

Expected: FAIL because `package:buylog/services/report_items_store.dart` does not exist.

- [ ] **Step 3: Implement `ReportItemsStore`**

Create `lib/services/report_items_store.dart`:

```dart
import 'package:flutter/foundation.dart';

import '../models/item.dart';
import '../models/item_scope.dart';
import 'supabase_service.dart';

class ReportItemsState {
  const ReportItemsState({
    this.scope = const ItemScope.personal(),
    this.items = const <ConsumableItem>[],
    this.isLoading = false,
    this.errorMessage,
  });

  final ItemScope scope;
  final List<ConsumableItem> items;
  final bool isLoading;
  final String? errorMessage;
}

class ReportItemsStore extends ValueNotifier<ReportItemsState> {
  ReportItemsStore() : super(const ReportItemsState());

  int _requestSerial = 0;

  Future<void> load(ItemScope scope) async {
    if (value.isLoading && value.scope.storageKey == scope.storageKey) {
      return;
    }

    final request = ++_requestSerial;
    value = ReportItemsState(
      scope: scope,
      items: value.scope.storageKey == scope.storageKey
          ? value.items
          : const <ConsumableItem>[],
      isLoading: true,
    );

    try {
      final items = await SupabaseService.loadItemsForScope(scope);
      if (request != _requestSerial) return;
      value = ReportItemsState(scope: scope, items: items);
    } catch (_) {
      if (request != _requestSerial) return;
      value = ReportItemsState(
        scope: scope,
        items: const <ConsumableItem>[],
        errorMessage: '리포트 데이터를 불러오지 못했습니다.',
      );
    }
  }
}
```

- [ ] **Step 4: Run service tests and commit**

Run:

```bash
flutter test test/services/report_items_store_test.dart
```

Expected: PASS.

Commit:

```bash
git add lib/services/report_items_store.dart test/services/report_items_store_test.dart
git commit -m "feat: add scoped report item store"
```

---

### Task 2: Add Report Scope Tabs Widget

**Files:**
- Create: `lib/widgets/reports/report_scope_tabs.dart`
- Create: `test/widgets/reports/report_scope_tabs_test.dart`

- [ ] **Step 1: Write failing widget tests**

Create `test/widgets/reports/report_scope_tabs_test.dart`:

```dart
import 'package:buylog/models/item_scope.dart';
import 'package:buylog/theme/app_theme.dart';
import 'package:buylog/widgets/reports/report_scope_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders personal and group report scopes', (tester) async {
    ItemScope? selected;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ReportScopeTabs(
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

    await tester.tap(find.text('우리 가족'));

    expect(selected, const ItemScope.group(id: 'group-1', label: '우리 가족'));
  });

  testWidgets('marks the selected group scope as active', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ReportScopeTabs(
            scopes: const <ItemScope>[
              ItemScope.personal(),
              ItemScope.group(id: 'group-1', label: '우리 가족'),
            ],
            selectedScope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
            onSelected: (_) {},
          ),
        ),
      ),
    );

    final personalChip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, '내 물품'),
    );
    final groupChip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, '우리 가족'),
    );

    expect(personalChip.selected, isFalse);
    expect(groupChip.selected, isTrue);
  });
}
```

- [ ] **Step 2: Run the new failing widget tests**

Run:

```bash
flutter test test/widgets/reports/report_scope_tabs_test.dart
```

Expected: FAIL because `ReportScopeTabs` does not exist.

- [ ] **Step 3: Implement the tabs widget**

Create `lib/widgets/reports/report_scope_tabs.dart`:

```dart
import 'package:flutter/material.dart';

import '../../models/item_scope.dart';
import '../../theme/app_theme.dart';

class ReportScopeTabs extends StatelessWidget {
  const ReportScopeTabs({
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
          final active = scope.storageKey == selectedScope.storageKey;
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

- [ ] **Step 4: Run widget tests and commit**

Run:

```bash
flutter test test/widgets/reports/report_scope_tabs_test.dart
```

Expected: PASS.

Commit:

```bash
git add lib/widgets/reports/report_scope_tabs.dart test/widgets/reports/report_scope_tabs_test.dart
git commit -m "feat: add report scope tabs"
```

---

### Task 3: Wire Scope State Into ReportsScreen

**Files:**
- Modify: `lib/screens/reports_screen.dart`
- Modify: `test/screens/reports_screen_year_view_test.dart`
- Modify: `test/screens/reports_screen_month_filter_test.dart`

- [ ] **Step 1: Update existing report screen tests to inject personal fixture data**

In both `test/screens/reports_screen_year_view_test.dart` and `test/screens/reports_screen_month_filter_test.dart`, replace the `_wrap()` helper with this pattern:

```dart
import 'package:buylog/data/sample_data.dart';
import 'package:buylog/models/item.dart';

Widget _wrap({List<ConsumableItem>? items}) {
  return MaterialApp(
    home: Scaffold(
      body: ReportsScreen(
        personalItemsListenable: ValueNotifier<List<ConsumableItem>>(
          items ?? SampleData.items,
        ),
      ),
    ),
  );
}
```

Add this import to each file because `_wrap` now uses `ValueNotifier`:

```dart
import 'package:flutter/foundation.dart';
```

Leave `_pumpReportsScreen(...)` and the current assertions unchanged.

- [ ] **Step 2: Run the updated existing tests to capture the constructor gap**

Run:

```bash
flutter test test/screens/reports_screen_year_view_test.dart test/screens/reports_screen_month_filter_test.dart
```

Expected: FAIL because `ReportsScreen` does not have `personalItemsListenable`.

- [ ] **Step 3: Add dependencies and scope state to `ReportsScreen`**

In `lib/screens/reports_screen.dart`, replace the imports at the top:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/item.dart';
import '../models/item_scope.dart';
import '../services/group_store.dart';
import '../services/item_store.dart';
import '../services/report_items_store.dart';
import '../services/report_service.dart';
import '../theme/app_theme.dart';
import '../widgets/reports/category_pie_chart.dart';
import '../widgets/reports/enhanced_category_breakdown_list.dart';
import '../widgets/reports/month_filter_list_view.dart';
import '../widgets/reports/monthly_bar_chart.dart';
import '../widgets/reports/price_movement_list.dart';
import '../widgets/reports/refill_forecast_card.dart';
import '../widgets/reports/report_hero_card.dart';
import '../widgets/reports/report_insight_strip.dart';
import '../widgets/reports/report_scope_tabs.dart';
import '../widgets/reports/share_action_button.dart';
```

Replace the `ReportsScreen` class with this constructor shape:

```dart
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({
    super.key,
    this.groupListenable,
    this.personalItemsListenable,
    this.saveEventListenable,
    this.createReportItemsStore,
  });

  final ValueListenable<GroupState>? groupListenable;
  final ValueListenable<List<ConsumableItem>>? personalItemsListenable;
  final ValueListenable<ItemSaveEvent?>? saveEventListenable;
  final ReportItemsStore Function()? createReportItemsStore;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}
```

Add these fields to `_ReportsScreenState`:

```dart
  late final ValueListenable<GroupState> _groupListenable;
  late final ValueListenable<List<ConsumableItem>> _personalItemsListenable;
  late final ValueListenable<ItemSaveEvent?> _saveEventListenable;
  late final ReportItemsStore _reportItemsStore;
  ItemScope _selectedScope = const ItemScope.personal();
```

Add these lifecycle and scope helper methods inside `_ReportsScreenState`:

```dart
  @override
  void initState() {
    super.initState();
    _groupListenable = widget.groupListenable ?? GroupStore.instance;
    _personalItemsListenable =
        widget.personalItemsListenable ?? ItemStore.instance;
    _saveEventListenable = widget.saveEventListenable ?? ItemStore.instance.lastSaveEvent;
    _reportItemsStore =
        widget.createReportItemsStore?.call() ?? ReportItemsStore();
    _selectedScope = _normalizedScope(
      _selectedScope,
      _reportScopes(_groupListenable.value),
    );
    _groupListenable.addListener(_handleGroupsChanged);
    _saveEventListenable.addListener(_reloadAfterScopedSave);
    if (_selectedScope.isGroup) {
      _reportItemsStore.load(_selectedScope);
    }
  }

  @override
  void dispose() {
    _groupListenable.removeListener(_handleGroupsChanged);
    _saveEventListenable.removeListener(_reloadAfterScopedSave);
    _reportItemsStore.dispose();
    super.dispose();
  }

  List<ItemScope> _reportScopes(GroupState state) {
    return <ItemScope>[
      const ItemScope.personal(),
      for (final group in state.visibleGroups)
        ItemScope.group(id: group.id, label: group.name),
    ];
  }

  ItemScope _normalizedScope(ItemScope current, List<ItemScope> scopes) {
    for (final scope in scopes) {
      if (scope.storageKey == current.storageKey) return scope;
    }
    return const ItemScope.personal();
  }

  void _handleGroupsChanged() {
    final scopes = _reportScopes(_groupListenable.value);
    final normalized = _normalizedScope(_selectedScope, scopes);
    if (normalized == _selectedScope) return;
    setState(() {
      _selectedScope = normalized;
      _selectedMonth = null;
    });
    if (normalized.isGroup) {
      _reportItemsStore.load(normalized);
    }
  }

  void _selectReportScope(ItemScope scope) {
    if (scope.storageKey == _selectedScope.storageKey) return;
    setState(() {
      _selectedScope = scope;
      _selectedMonth = null;
    });
    if (scope.isGroup) {
      _reportItemsStore.load(scope);
    }
  }

  void _reloadAfterScopedSave() {
    final event = _saveEventListenable.value;
    if (event == null || !_selectedScope.isGroup) return;
    if (event.scope.storageKey != _selectedScope.storageKey) return;
    _reportItemsStore.load(_selectedScope);
  }
```

- [ ] **Step 4: Replace the top of `build` with scoped data selection**

In `ReportsScreen.build`, replace this line:

```dart
final service = ReportService.fromItems(SampleData.items);
```

with a nested `ValueListenableBuilder` structure. The outer `build` should return this shape:

```dart
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GroupState>(
      valueListenable: _groupListenable,
      builder: (context, groupState, _) {
        final scopes = _reportScopes(groupState);
        final selectedScope = _normalizedScope(_selectedScope, scopes);
        if (selectedScope != _selectedScope) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _selectedScope = selectedScope;
              _selectedMonth = null;
            });
          });
        }

        return ValueListenableBuilder<List<ConsumableItem>>(
          valueListenable: _personalItemsListenable,
          builder: (context, personalItems, _) {
            return ValueListenableBuilder<ReportItemsState>(
              valueListenable: _reportItemsStore,
              builder: (context, reportItemState, _) {
                final groupStateMatches =
                    reportItemState.scope.storageKey == selectedScope.storageKey;
                final reportItems = selectedScope.isPersonal
                    ? personalItems
                    : groupStateMatches
                        ? reportItemState.items
                        : const <ConsumableItem>[];
                final isScopeLoading =
                    selectedScope.isGroup &&
                    groupStateMatches &&
                    reportItemState.isLoading;
                final scopeErrorMessage =
                    selectedScope.isGroup && groupStateMatches
                        ? reportItemState.errorMessage
                        : null;

                return _buildReportContent(
                  context: context,
                  scopes: scopes,
                  selectedScope: selectedScope,
                  items: reportItems,
                  isScopeLoading: isScopeLoading,
                  scopeErrorMessage: scopeErrorMessage,
                );
              },
            );
          },
        );
      },
    );
  }
```

Add this helper method and move the report-section slivers from the current `build` into its `slivers` list after the scope/status block:

```dart
  Widget _buildReportContent({
    required BuildContext context,
    required List<ItemScope> scopes,
    required ItemScope selectedScope,
    required List<ConsumableItem> items,
    required bool isScopeLoading,
    required String? scopeErrorMessage,
  }) {
    final service = ReportService.fromItems(items);
    final now = DateTime.now();
    final months = service.aggregateRecentMonths();
    final yearly = service.aggregateYear(_selectedYear);
    final isYearly = _period == _ReportPeriod.yearly;
    final latest =
        service.latestMonthlyWithSpending() ??
        (months.isEmpty ? null : months.last);
    final activeMonth = latest?.month ?? DateTime(now.year, now.month, 1);

    final monthlyBreakdown = latest == null
        ? const <CategoryBreakdown>[]
        : service.categoryBreakdownFor(activeMonth);
    final yearlyBreakdown = service.categoryBreakdownForYear(_selectedYear);
    final chartData = isYearly ? yearly.months : months;
    final breakdown = isYearly ? yearlyBreakdown : monthlyBreakdown;
    final summary = isYearly
        ? service.yearlySummary(_selectedYear)
        : service.monthlySummary(activeMonth);
    final insights = service.smartInsights(month: activeMonth);
    final forecast = service.refillForecast();
    final priceMovements = service.priceMovements(limit: 4);
    final categoryRows = isYearly
        ? service.categoryComparisonForYear(_selectedYear)
        : service.categoryComparisonForMonth(activeMonth);

    final effectiveSelectedMonth =
        _selectedMonth != null &&
            chartData.any((m) => m.month == _selectedMonth)
        ? _selectedMonth
        : null;

    final heroTitle = isYearly ? '연간 지출 현황' : '${activeMonth.month}월 리포트';
    final chartTitle = isYearly ? '연간 월별 지출' : '월별 지출 추이';
    final detailTitle = isYearly ? '연간 카테고리 상세' : '카테고리별 상세';
    final pieTitle = isYearly
        ? '연간 카테고리 구성'
        : '${activeMonth.month}월 카테고리 구성';

    return SafeArea(
      child: CustomScrollView(
        slivers: [
```

Use this title/scope/status block as the first slivers:

```dart
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '리포트',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  ShareActionButton(service: service),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ReportScopeTabs(
                scopes: scopes,
                selectedScope: selectedScope,
                onSelected: _selectReportScope,
              ),
            ),
          ),
          if (isScopeLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: _ReportStatusMessage.loading(),
              ),
            ),
          if (scopeErrorMessage?.isNotEmpty == true)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: _ReportStatusMessage.error(scopeErrorMessage!),
              ),
            ),
```

Add this private widget near `_ReportSectionCard`:

```dart
class _ReportStatusMessage extends StatelessWidget {
  const _ReportStatusMessage.loading()
    : message = '리포트 데이터를 불러오는 중입니다.',
      icon = Icons.sync,
      color = AppColors.textSecondary;

  const _ReportStatusMessage.error(this.message)
    : icon = Icons.error_outline,
      color = AppColors.danger;

  final String message;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

Remove this import because the screen no longer reads sample data directly:

```dart
import '../data/sample_data.dart';
```

- [ ] **Step 5: Run existing report screen tests and commit**

Run:

```bash
flutter test test/screens/reports_screen_year_view_test.dart test/screens/reports_screen_month_filter_test.dart
```

Expected: PASS.

Commit:

```bash
git add lib/screens/reports_screen.dart test/screens/reports_screen_year_view_test.dart test/screens/reports_screen_month_filter_test.dart
git commit -m "feat: prepare reports screen for scoped data"
```

---

### Task 4: Add Report Scope Screen Tests

**Files:**
- Create: `test/screens/reports_screen_scope_test.dart`
- Modify: `lib/screens/reports_screen.dart`

- [ ] **Step 1: Write scope behavior tests**

Create `test/screens/reports_screen_scope_test.dart`:

```dart
import 'dart:async';

import 'package:buylog/models/group.dart';
import 'package:buylog/models/item.dart';
import 'package:buylog/models/item_scope.dart';
import 'package:buylog/screens/reports_screen.dart';
import 'package:buylog/services/group_store.dart';
import 'package:buylog/services/item_store.dart';
import 'package:buylog/services/supabase_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ValueNotifier<GroupState> groupState;
  late ValueNotifier<List<ConsumableItem>> personalItems;
  late ValueNotifier<ItemSaveEvent?> saveEvents;
  late _RecordingItemDatabaseGateway gateway;

  setUp(() {
    groupState = ValueNotifier<GroupState>(
      GroupState(
        groups: <BuylogGroup>[
          _group(id: 'group-1', name: '우리 가족'),
          _group(id: 'group-2', name: '사무실'),
        ],
      ),
    );
    personalItems = ValueNotifier<List<ConsumableItem>>(<ConsumableItem>[
      _item(id: 'personal-filter', name: '개인 필터', price: 30000),
    ]);
    saveEvents = ValueNotifier<ItemSaveEvent?>(null);
    gateway = _RecordingItemDatabaseGateway();
    SupabaseService.debugItemDatabaseGateway = gateway;
  });

  tearDown(() {
    SupabaseService.debugItemDatabaseGateway = null;
    groupState.dispose();
    personalItems.dispose();
    saveEvents.dispose();
  });

  testWidgets('renders personal and joined group report scope tabs', (tester) async {
    await _pump(
      tester,
      groupState: groupState,
      personalItems: personalItems,
      saveEvents: saveEvents,
    );

    expect(find.text('내 물품'), findsOneWidget);
    expect(find.text('우리 가족'), findsOneWidget);
    expect(find.text('사무실'), findsOneWidget);
    expect(find.text('리포트'), findsOneWidget);
  });

  testWidgets('defaults to personal items and switches report totals after group tap', (tester) async {
    gateway.resultsByGroupId['group-1'] = <Map<String, dynamic>>[
      _itemRow(id: 'group-filter', groupId: 'group-1', price: 12000),
    ];

    await _pump(
      tester,
      groupState: groupState,
      personalItems: personalItems,
      saveEvents: saveEvents,
    );

    expect(find.textContaining('30,000'), findsWidgets);

    await tester.tap(find.text('우리 가족'));
    await tester.pump();
    await tester.pump();

    expect(gateway.lastGroupId, 'group-1');
    expect(find.textContaining('12,000'), findsWidgets);
  });

  testWidgets('falls back to personal scope when selected group disappears', (tester) async {
    gateway.resultsByGroupId['group-1'] = <Map<String, dynamic>>[
      _itemRow(id: 'group-filter', groupId: 'group-1', price: 12000),
    ];

    await _pump(
      tester,
      groupState: groupState,
      personalItems: personalItems,
      saveEvents: saveEvents,
    );

    await tester.tap(find.text('우리 가족'));
    await tester.pump();
    await tester.pump();

    groupState.value = const GroupState(groups: <BuylogGroup>[]);
    await tester.pump();

    final personalChip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, '내 물품'),
    );
    expect(personalChip.selected, isTrue);
    expect(find.text('우리 가족'), findsNothing);
  });

  testWidgets('updates selected group label when group is renamed', (tester) async {
    gateway.resultsByGroupId['group-1'] = <Map<String, dynamic>>[
      _itemRow(id: 'group-filter', groupId: 'group-1', price: 12000),
    ];

    await _pump(
      tester,
      groupState: groupState,
      personalItems: personalItems,
      saveEvents: saveEvents,
    );

    await tester.tap(find.text('우리 가족'));
    await tester.pump();
    await tester.pump();

    groupState.value = GroupState(
      groups: <BuylogGroup>[
        _group(id: 'group-1', name: '새 가족'),
        _group(id: 'group-2', name: '사무실'),
      ],
    );
    await tester.pump();

    expect(find.text('새 가족'), findsOneWidget);
    final groupChip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, '새 가족'),
    );
    expect(groupChip.selected, isTrue);
  });

  testWidgets('reloads selected group report after matching save event', (tester) async {
    gateway.resultsByGroupId['group-1'] = <Map<String, dynamic>>[
      _itemRow(id: 'group-filter', groupId: 'group-1', price: 12000),
    ];

    await _pump(
      tester,
      groupState: groupState,
      personalItems: personalItems,
      saveEvents: saveEvents,
    );

    await tester.tap(find.text('우리 가족'));
    await tester.pump();
    await tester.pump();
    expect(gateway.loadItemsCalls, 1);

    saveEvents.value = const ItemSaveEvent(
      scope: ItemScope.group(id: 'group-1', label: '우리 가족'),
      serial: 1,
    );
    await tester.pump();
    await tester.pump();

    expect(gateway.loadItemsCalls, 2);
  });

  testWidgets('shows Korean error message when group report load fails', (tester) async {
    gateway.error = StateError('network failed');

    await _pump(
      tester,
      groupState: groupState,
      personalItems: personalItems,
      saveEvents: saveEvents,
    );

    await tester.tap(find.text('우리 가족'));
    await tester.pump();
    await tester.pump();

    expect(find.text('리포트 데이터를 불러오지 못했습니다.'), findsOneWidget);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required ValueListenable<GroupState> groupState,
  required ValueListenable<List<ConsumableItem>> personalItems,
  required ValueListenable<ItemSaveEvent?> saveEvents,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 3200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ReportsScreen(
          groupListenable: groupState,
          personalItemsListenable: personalItems,
          saveEventListenable: saveEvents,
        ),
      ),
    ),
  );
}

ConsumableItem _item({
  required String id,
  required String name,
  required int price,
  String? groupId,
}) {
  return ConsumableItem(
    id: id,
    name: name,
    brand: '브랜드',
    category: '가전/필터',
    icon: Icons.circle,
    daysRemaining: 10,
    cycleDays: 30,
    progress: 0.5,
    groupId: groupId,
    purchaseHistory: <PurchaseRecord>[
      PurchaseRecord(
        date: DateTime(DateTime.now().year, DateTime.now().month, 10),
        price: price,
        store: '마트',
      ),
    ],
  );
}

Map<String, dynamic> _itemRow({
  required String id,
  required String groupId,
  required int price,
}) {
  final now = DateTime.now();
  final month = now.month.toString().padLeft(2, '0');
  return <String, dynamic>{
    'id': id,
    'user_id': null,
    'group_id': groupId,
    'registered_by': SupabaseService.currentUserId,
    'name': '그룹 필터',
    'brand': '브랜드',
    'image_url': null,
    'replacement_cycle_days': 30,
    'created_at': '2026-05-26T00:00:00.000Z',
    'categories': <String, dynamic>{'id': 'category-1', 'name': '가전/필터'},
    'purchases': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'purchase-$id',
        'purchase_date': '${now.year}-$month-10',
        'price': price,
        'store_name': '마트',
      },
    ],
    'ai_predictions': <Map<String, dynamic>>[],
  };
}

BuylogGroup _group({required String id, required String name}) {
  return BuylogGroup(
    id: id,
    name: name,
    inviteCode: 'BUY-${id.toUpperCase()}',
    createdBy: SupabaseService.currentUserId,
    createdAt: DateTime.parse('2026-05-26T00:00:00.000Z'),
  );
}

class _RecordingItemDatabaseGateway implements ItemDatabaseGateway {
  Object? error;
  int loadItemsCalls = 0;
  String? lastGroupId;
  final Map<String, List<Map<String, dynamic>>> resultsByGroupId =
      <String, List<Map<String, dynamic>>>{};

  @override
  Future<List<Map<String, dynamic>>> loadItems({
    required String? userId,
    required String? groupId,
  }) async {
    loadItemsCalls += 1;
    lastGroupId = groupId;
    if (error != null) throw error!;
    return resultsByGroupId[groupId] ?? const <Map<String, dynamic>>[];
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

- [ ] **Step 2: Run the new failing screen tests**

Run:

```bash
flutter test test/screens/reports_screen_scope_test.dart
```

Expected: FAIL on at least one behavior until the `ReportsScreen` wiring from Task 3 is complete and the UI status widget is present.

- [ ] **Step 3: Fix implementation against the screen tests**

Make these concrete checks in `lib/screens/reports_screen.dart`:

```dart
// In _handleGroupsChanged:
if (normalized.storageKey != _selectedScope.storageKey ||
    normalized.label != _selectedScope.label) {
  setState(() {
    _selectedScope = normalized;
    _selectedMonth = null;
  });
}
```

```dart
// In the loading/error derivation:
final groupStateMatches =
    reportItemState.scope.storageKey == selectedScope.storageKey;
final reportItems = selectedScope.isPersonal
    ? personalItems
    : groupStateMatches
        ? reportItemState.items
        : const <ConsumableItem>[];
```

```dart
// In _selectReportScope:
if (scope.storageKey == _selectedScope.storageKey) return;
setState(() {
  _selectedScope = scope;
  _selectedMonth = null;
});
if (scope.isGroup) {
  _reportItemsStore.load(scope);
}
```

- [ ] **Step 4: Run focused screen tests and commit**

Run:

```bash
flutter test test/screens/reports_screen_scope_test.dart
```

Expected: PASS.

Commit:

```bash
git add lib/screens/reports_screen.dart test/screens/reports_screen_scope_test.dart
git commit -m "feat: switch reports by item scope"
```

---

### Task 5: Full Regression Verification

**Files:**
- Verify only.

- [ ] **Step 1: Run service and widget tests affected by this change**

Run:

```bash
flutter test test/services/report_items_store_test.dart test/services/report_service_test.dart test/widgets/reports/report_scope_tabs_test.dart test/screens/reports_screen_scope_test.dart test/screens/reports_screen_year_view_test.dart test/screens/reports_screen_month_filter_test.dart
```

Expected: PASS.

- [ ] **Step 2: Run analyzer**

Run:

```bash
flutter analyze
```

Expected: PASS with no new issues.

- [ ] **Step 3: Run the full test suite**

Run:

```bash
flutter test
```

Expected: PASS.

- [ ] **Step 4: Manual smoke check**

Run the app:

```bash
flutter run -d chrome
```

Manual checks:

1. Open the `리포트` tab.
2. Confirm the top toggles show `내 물품` and each joined group name.
3. Confirm `내 물품` shows personal report totals.
4. Tap a group name and confirm loading state appears briefly.
5. Confirm the hero total, monthly bar chart, category chart, price movement, and detail list are based on that group's items.
6. Tap `월간` and `연간`; confirm both modes stay scoped to the selected group.
7. Add a group item from the group tab and return to `리포트`; confirm the selected group report refreshes.

- [ ] **Step 5: Final commit if verification required additional fixes**

If verification required code changes, commit them:

```bash
git add lib test
git commit -m "test: cover report scope switching"
```

If no changes were needed, do not create an empty commit.

---

## Implementation Notes

- Do not add scope filtering to `ReportService`; it should stay a pure `List<ConsumableItem>` aggregation service.
- Do not use `GroupItemsStore` in `ReportsScreen`. It has filter state that belongs to the group page and would couple unrelated screens.
- Keep `ReportScopeTabs` UI-only. Scope derivation belongs in `ReportsScreen` because it combines `GroupStore` state with report selection state.
- Keep `ShareActionButton(service: service)` scoped by passing the already scoped `ReportService`. No extra share code is needed unless share output currently assumes sample data text.
- `ReportsScreen` is inside `IndexedStack`, so keep stale selection guards. Scope changes should null out `_selectedMonth` to avoid showing a month detail header from a previous scope.
- The default app path should use `ItemStore.instance` for personal reports. Tests can inject `ValueNotifier<List<ConsumableItem>>` to avoid Supabase initialization and date-cliff fixture failures.

## Self-Review

- Spec coverage: The plan covers `내 물품 / 그룹명1 / 그룹명2` report toggles, group report loading, default personal scope, group rename/delete changes, save-event refresh, and existing monthly/yearly report modes.
- Placeholder scan: The plan contains concrete file paths, commands, expected results, and code snippets for every code-producing task.
- Type consistency: `ItemScope`, `GroupState`, `ItemSaveEvent`, `ReportItemsStore`, and `ReportItemsState` names are defined before they are used by later tasks.
