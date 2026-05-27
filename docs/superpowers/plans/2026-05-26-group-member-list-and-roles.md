# Group Member List and Roles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 그룹 화면에서 현재 그룹의 멤버 목록을 Supabase에서 조회하고 각 멤버의 역할을 `owner`/`member` 기준으로 명확히 표시한다.

**Architecture:** 멤버 조회와 역할 해석은 `SupabaseService`와 `GroupStore`에 둔다. `GroupScreen`은 `GroupState`를 렌더링하고 새로고침 액션만 전달한다. Supabase 조회는 기존 `GroupDatabaseGateway` 테스트 seam을 확장해서 위젯에 비즈니스 로직을 넣지 않는다.

**Tech Stack:** Flutter, Dart, `ValueNotifier`, `supabase_flutter`, Supabase Postgres RLS, `flutter_test`.

---

## Current Repo Context

- 현재 그룹 모델은 `lib/models/group.dart`에 있으며 `BuylogGroup.members`와 `BuylogGroupMember.role`을 이미 가진다.
- 현재 기본 그룹 로드는 `lib/services/supabase_service.dart`의 `loadDefaultGroup()`이 `groups`와 중첩 `group_members`를 함께 조회한다.
- 현재 그룹 상태는 `lib/services/group_store.dart`의 singleton `GroupStore.instance`가 관리한다.
- 현재 그룹 화면은 `lib/screens/group_screen.dart`의 `_GroupCard`와 `_MemberRow`에서 멤버명을 렌더링한다.
- 현재 Supabase RLS 마이그레이션 `supabase/migrations/20260526193000_add_group_rls_policies.sql`은 그룹 멤버가 같은 그룹의 `group_members` row를 볼 수 있게 허용한다.
- 이 repo의 검증 명령은 `flutter analyze --no-fatal-infos`와 `flutter test`다.

## File Structure

- Modify: `lib/models/group.dart`
  - `GroupRole.displayLabel`을 추가해 역할 표시 문자열을 위젯 밖으로 분리한다.
  - `BuylogGroup.copyWith()`를 추가해 멤버 새로고침 결과를 기존 그룹에 안전하게 반영한다.
- Modify: `lib/services/supabase_service.dart`
  - `SupabaseService.loadGroupMembers({required String groupId})`를 추가한다.
  - `GroupDatabaseGateway.loadGroupMembers({required String groupId})`를 추가한다.
  - `SupabaseGroupDatabaseGateway`에서 `group_members`를 직접 조회하고 `users(display_name,email)`을 포함한다.
- Modify: `lib/services/group_store.dart`
  - `GroupState.isRefreshingMembers`를 추가한다.
  - `GroupStore.refreshMembers()`를 추가해 현재 그룹의 멤버 목록만 다시 조회한다.
- Modify: `lib/screens/group_screen.dart`
  - 멤버 섹션에 인원수, 새로고침 버튼, 역할 badge를 렌더링한다.
  - 역할 텍스트는 `member.role.displayLabel`을 사용한다.
- Modify: `test/services/group_store_test.dart`
  - 역할 label, `BuylogGroup.copyWith()`, `GroupStore.refreshMembers()` 성공/실패 테스트를 추가한다.
- Modify: `test/services/supabase_service_test.dart`
  - `SupabaseService.loadGroupMembers()`가 gateway 결과를 `BuylogGroupMember` 목록으로 변환하는지 테스트한다.
- Modify: `test/screens/group_screen_test.dart`
  - owner/member 역할 badge 렌더링과 멤버 새로고침 액션을 테스트한다.

---

### Task 1: Add Role Display and Immutable Group Update Helpers

**Files:**
- Modify: `lib/models/group.dart:1-83`
- Modify: `test/services/group_store_test.dart`

- [ ] **Step 1: Write the failing model tests**

Add these tests inside the existing `GroupRole database value` and `BuylogGroup Supabase parsing` groups in `test/services/group_store_test.dart`:

```dart
test('exposes Korean display labels for member role badges', () {
  expect(GroupRole.owner.displayLabel, '관리자');
  expect(GroupRole.member.displayLabel, '멤버');
});
```

```dart
test('copyWith replaces members without mutating the original group', () {
  final original = BuylogGroup.fromSupabase({
    'id': 'group-1',
    'name': '우리 가족',
    'invite_code': 'ABC123',
    'created_by': 'user-1',
    'created_at': '2026-05-26T10:20:30.000Z',
    'group_members': [
      {
        'id': 'member-1',
        'user_id': 'user-1',
        'role': 'owner',
        'joined_at': '2026-05-26T10:21:30.000Z',
        'users': {'display_name': '소유자', 'email': 'owner@example.com'},
      },
    ],
  });
  final nextMember = BuylogGroupMember.fromSupabase({
    'id': 'member-2',
    'user_id': 'user-2',
    'role': 'member',
    'joined_at': '2026-05-26T10:22:30.000Z',
    'users': {'display_name': '멤버', 'email': 'member@example.com'},
  });

  final updated = original.copyWith(members: [nextMember]);

  expect(original.members.single.userId, 'user-1');
  expect(updated.members.single.userId, 'user-2');
  expect(() => updated.members.add(nextMember), throwsUnsupportedError);
});
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run:

```powershell
flutter test test/services/group_store_test.dart
```

Expected: FAIL with a compile error that `displayLabel` and `copyWith` are not defined.

- [ ] **Step 3: Implement role label and `BuylogGroup.copyWith()`**

Update `lib/models/group.dart`:

```dart
enum GroupRole {
  owner,
  member;

  static GroupRole fromDatabase(String? value) {
    return value == 'owner' ? GroupRole.owner : GroupRole.member;
  }

  String get databaseValue {
    return switch (this) {
      GroupRole.owner => 'owner',
      GroupRole.member => 'member',
    };
  }

  String get displayLabel {
    return switch (this) {
      GroupRole.owner => '관리자',
      GroupRole.member => '멤버',
    };
  }
}
```

Add this method inside `class BuylogGroup` after the constructor:

```dart
  BuylogGroup copyWith({
    String? id,
    String? name,
    String? inviteCode,
    String? createdBy,
    DateTime? createdAt,
    List<BuylogGroupMember>? members,
  }) {
    return BuylogGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      inviteCode: inviteCode ?? this.inviteCode,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      members: members == null
          ? this.members
          : List<BuylogGroupMember>.unmodifiable(members),
    );
  }
```

- [ ] **Step 4: Run the focused test and verify it passes**

Run:

```powershell
flutter test test/services/group_store_test.dart
```

Expected: PASS for all `group_store_test.dart` tests.

- [ ] **Step 5: Commit the model helper change**

Run:

```powershell
git add lib/models/group.dart test/services/group_store_test.dart
git commit -m "feat: add group member role helpers"
```

Expected: commit succeeds with only those two files staged.

---

### Task 2: Add Supabase Member List Query

**Files:**
- Modify: `lib/services/supabase_service.dart:46-66`
- Modify: `lib/services/supabase_service.dart:315-379`
- Modify: `test/services/supabase_service_test.dart`

- [ ] **Step 1: Write the failing service test**

Extend `_RecordingGroupDatabaseGateway` in `test/services/supabase_service_test.dart` with these fields and method:

```dart
  int loadGroupMembersCalls = 0;
  String? loadGroupMembersGroupId;
  List<Map<String, dynamic>> loadGroupMembersResult = const [];

  @override
  Future<List<Map<String, dynamic>>> loadGroupMembers({
    required String groupId,
  }) async {
    loadGroupMembersCalls += 1;
    loadGroupMembersGroupId = groupId;
    return loadGroupMembersResult;
  }
```

Add this test group after the existing `SupabaseService.createGroup` group:

```dart
  group('SupabaseService.loadGroupMembers', () {
    tearDown(() {
      SupabaseService.debugGroupDatabaseGateway = null;
    });

    test('loads group members through the gateway and maps roles', () async {
      final gateway = _RecordingGroupDatabaseGateway()
        ..loadGroupMembersResult = <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'member-1',
            'user_id': 'user-1',
            'role': 'owner',
            'joined_at': '2026-05-26T10:00:00.000Z',
            'users': <String, dynamic>{
              'display_name': '소유자',
              'email': 'owner@example.com',
            },
          },
          <String, dynamic>{
            'id': 'member-2',
            'user_id': 'user-2',
            'role': 'member',
            'joined_at': '2026-05-26T10:01:00.000Z',
            'users': <String, dynamic>{
              'display_name': '멤버',
              'email': 'member@example.com',
            },
          },
        ];
      SupabaseService.debugGroupDatabaseGateway = gateway;

      final members = await SupabaseService.loadGroupMembers(
        groupId: ' group-1 ',
      );

      expect(gateway.loadGroupMembersCalls, 1);
      expect(gateway.loadGroupMembersGroupId, 'group-1');
      expect(members, hasLength(2));
      expect(members.first.displayName, '소유자');
      expect(members.first.role, GroupRole.owner);
      expect(members.last.displayName, '멤버');
      expect(members.last.role, GroupRole.member);
    });

    test('rejects blank group ids without calling the gateway', () async {
      final gateway = _RecordingGroupDatabaseGateway();
      SupabaseService.debugGroupDatabaseGateway = gateway;

      await expectLater(
        SupabaseService.loadGroupMembers(groupId: '   '),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'Group id is required.',
          ),
        ),
      );

      expect(gateway.loadGroupMembersCalls, 0);
    });
  });
```

- [ ] **Step 2: Run the focused service test and verify it fails**

Run:

```powershell
flutter test test/services/supabase_service_test.dart
```

Expected: FAIL because `loadGroupMembers` is not defined on `SupabaseService` and `GroupDatabaseGateway`.

- [ ] **Step 3: Implement the service method and gateway contract**

Add this method after `SupabaseService.createGroup()` in `lib/services/supabase_service.dart`:

```dart
  static Future<List<BuylogGroupMember>> loadGroupMembers({
    required String groupId,
  }) async {
    final trimmedGroupId = groupId.trim();
    if (trimmedGroupId.isEmpty) {
      throw ArgumentError.value(groupId, 'groupId', 'Group id is required.');
    }

    final rows = await _groupDatabaseGateway.loadGroupMembers(
      groupId: trimmedGroupId,
    );
    return List<BuylogGroupMember>.unmodifiable(
      rows.map(BuylogGroupMember.fromSupabase),
    );
  }
```

Add this method to `abstract class GroupDatabaseGateway`:

```dart
  Future<List<Map<String, dynamic>>> loadGroupMembers({
    required String groupId,
  });
```

Replace the group projection constants inside `SupabaseGroupDatabaseGateway` with a reusable member projection:

```dart
  static const _memberProjection = '''
          id,
          user_id,
          role,
          joined_at,
          users (
            display_name,
            email
          )
      ''';

  static const _groupProjection = '''
        id,
        name,
        invite_code,
        created_by,
        created_at,
        group_members (
          $_memberProjection
        )
      ''';
```

Add this method to `SupabaseGroupDatabaseGateway`:

```dart
  @override
  Future<List<Map<String, dynamic>>> loadGroupMembers({
    required String groupId,
  }) async {
    final rows = await _client
        .from('group_members')
        .select(_memberProjection)
        .eq('group_id', groupId)
        .order('joined_at', ascending: true);
    return rows
        .whereType<Map<String, dynamic>>()
        .map(Map<String, dynamic>.from)
        .toList(growable: false);
  }
```

- [ ] **Step 4: Update every fake gateway to satisfy the new interface**

In `test/services/group_store_test.dart`, add this method to `_RecordingGroupDatabaseGateway`:

```dart
  @override
  Future<List<Map<String, dynamic>>> loadGroupMembers({
    required String groupId,
  }) async {
    return const <Map<String, dynamic>>[];
  }
```

In `test/screens/group_screen_test.dart`, add this method to `_FakeGroupDatabaseGateway`:

```dart
  @override
  Future<List<Map<String, dynamic>>> loadGroupMembers({
    required String groupId,
  }) async {
    return _currentGroup == null
        ? const <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            (_currentGroup!['group_members'] as List<dynamic>)
                .whereType<Map<String, dynamic>>(),
          );
  }
```

- [ ] **Step 5: Run the service test and verify it passes**

Run:

```powershell
flutter test test/services/supabase_service_test.dart
```

Expected: PASS for all `supabase_service_test.dart` tests.

- [ ] **Step 6: Commit the service query change**

Run:

```powershell
git add lib/services/supabase_service.dart test/services/supabase_service_test.dart test/services/group_store_test.dart test/screens/group_screen_test.dart
git commit -m "feat: load group members from supabase"
```

Expected: commit succeeds with the service and test fake updates staged.

---

### Task 3: Add GroupStore Member Refresh State

**Files:**
- Modify: `lib/services/group_store.dart:6-90`
- Modify: `test/services/group_store_test.dart`

- [ ] **Step 1: Write the failing store tests**

Add these fields to `_RecordingGroupDatabaseGateway` in `test/services/group_store_test.dart`:

```dart
  int loadGroupMembersCalls = 0;
  String? loadGroupMembersGroupId;
  Object? loadGroupMembersError;
  List<Map<String, dynamic>> loadGroupMembersResult = const [];
```

Replace the `loadGroupMembers` fake method from Task 2 with:

```dart
  @override
  Future<List<Map<String, dynamic>>> loadGroupMembers({
    required String groupId,
  }) async {
    loadGroupMembersCalls += 1;
    loadGroupMembersGroupId = groupId;
    if (loadGroupMembersError != null) {
      throw loadGroupMembersError!;
    }
    return loadGroupMembersResult;
  }
```

Add these tests inside the existing `GroupStore` group:

```dart
    test('refreshes members for the current group', () async {
      gateway.loadDefaultGroupResult = _groupRow(name: 'Existing Group');
      await GroupStore.instance.initialize();
      gateway.loadGroupMembersResult = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'member-2',
          'user_id': 'user-2',
          'role': 'member',
          'joined_at': '2026-05-26T10:22:30.000Z',
          'users': <String, dynamic>{
            'display_name': '새 멤버',
            'email': 'member@example.com',
          },
        },
      ];

      await GroupStore.instance.refreshMembers();

      expect(gateway.loadGroupMembersCalls, 1);
      expect(gateway.loadGroupMembersGroupId, 'group-1');
      expect(GroupStore.instance.value.group?.members, hasLength(1));
      expect(GroupStore.instance.value.group?.members.single.displayName, '새 멤버');
      expect(GroupStore.instance.value.group?.members.single.role, GroupRole.member);
      expect(GroupStore.instance.value.isRefreshingMembers, isFalse);
      expect(GroupStore.instance.value.errorMessage, isNull);
    });

    test('sets an error and keeps previous members when refresh fails', () async {
      gateway.loadDefaultGroupResult = _groupRow(name: 'Existing Group');
      await GroupStore.instance.initialize();
      gateway.loadGroupMembersError = StateError('refresh failed');

      await expectLater(
        GroupStore.instance.refreshMembers(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'refresh failed',
          ),
        ),
      );

      expect(gateway.loadGroupMembersCalls, 1);
      expect(GroupStore.instance.value.group?.members.single.displayName, 'Owner');
      expect(GroupStore.instance.value.isRefreshingMembers, isFalse);
      expect(
        GroupStore.instance.value.errorMessage,
        '멤버 목록을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.',
      );
    });
```

- [ ] **Step 2: Run the store test and verify it fails**

Run:

```powershell
flutter test test/services/group_store_test.dart
```

Expected: FAIL because `isRefreshingMembers` and `refreshMembers()` are not defined.

- [ ] **Step 3: Add refresh state to `GroupState`**

Update `GroupState` in `lib/services/group_store.dart`:

```dart
class GroupState {
  const GroupState({
    this.group,
    this.isLoading = false,
    this.isSaving = false,
    this.isRefreshingMembers = false,
    this.errorMessage,
  });

  static const _unset = Object();

  final BuylogGroup? group;
  final bool isLoading;
  final bool isSaving;
  final bool isRefreshingMembers;
  final String? errorMessage;

  GroupState copyWith({
    Object? group = _unset,
    bool? isLoading,
    bool? isSaving,
    bool? isRefreshingMembers,
    Object? errorMessage = _unset,
  }) {
    return GroupState(
      group: identical(group, _unset) ? this.group : group as BuylogGroup?,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isRefreshingMembers:
          isRefreshingMembers ?? this.isRefreshingMembers,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}
```

- [ ] **Step 4: Add `GroupStore.refreshMembers()`**

Add this method inside `class GroupStore` after `createGroup()`:

```dart
  Future<void> refreshMembers() async {
    final currentGroup = value.group;
    if (currentGroup == null || value.isRefreshingMembers) {
      return;
    }

    final previousState = value;
    value = previousState.copyWith(
      isRefreshingMembers: true,
      errorMessage: null,
    );

    try {
      final members = await SupabaseService.loadGroupMembers(
        groupId: currentGroup.id,
      );
      value = value.copyWith(
        group: currentGroup.copyWith(members: members),
        isRefreshingMembers: false,
        errorMessage: null,
      );
    } catch (_) {
      value = previousState.copyWith(
        isRefreshingMembers: false,
        errorMessage: '멤버 목록을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.',
      );
      rethrow;
    }
  }
```

- [ ] **Step 5: Run the store test and verify it passes**

Run:

```powershell
flutter test test/services/group_store_test.dart
```

Expected: PASS for all `group_store_test.dart` tests.

- [ ] **Step 6: Commit the store refresh change**

Run:

```powershell
git add lib/services/group_store.dart test/services/group_store_test.dart
git commit -m "feat: refresh group member list"
```

Expected: commit succeeds with the store and store tests staged.

---

### Task 4: Render Member Count, Refresh Action, and Role Badges

**Files:**
- Modify: `lib/screens/group_screen.dart:27-30`
- Modify: `lib/screens/group_screen.dart:121-245`
- Modify: `test/screens/group_screen_test.dart`

- [ ] **Step 1: Write failing widget tests for role badges**

Update `_group()` in `test/screens/group_screen_test.dart` so it returns two members:

```dart
    members: [
      BuylogGroupMember(
        id: 'member-1',
        userId: 'user-1',
        displayName: '소유자',
        role: GroupRole.owner,
        joinedAt: DateTime.parse('2026-05-26T00:00:00.000Z'),
      ),
      BuylogGroupMember(
        id: 'member-2',
        userId: 'user-2',
        displayName: '멤버',
        role: GroupRole.member,
        joinedAt: DateTime.parse('2026-05-26T00:01:00.000Z'),
      ),
    ],
```

Replace the assertions in `saved group state renders group summary and member names` with:

```dart
    expect(find.text('우리 가족'), findsOneWidget);
    expect(find.text('초대 코드: BUY-ABC123'), findsOneWidget);
    expect(find.text('멤버 2명'), findsOneWidget);
    expect(find.text('소유자'), findsOneWidget);
    expect(find.text('멤버'), findsNWidgets(2));
    expect(find.text('관리자'), findsOneWidget);
```

- [ ] **Step 2: Write failing widget test for refresh action**

Add these fields to `_FakeGroupDatabaseGateway` in `test/screens/group_screen_test.dart`:

```dart
  int loadGroupMembersCalls = 0;
  List<Map<String, dynamic>> loadGroupMembersResult = const [];
```

Replace the `loadGroupMembers` fake method from Task 2 with:

```dart
  @override
  Future<List<Map<String, dynamic>>> loadGroupMembers({
    required String groupId,
  }) async {
    loadGroupMembersCalls += 1;
    return loadGroupMembersResult;
  }
```

Add this widget test:

```dart
  testWidgets('member refresh button reloads and renders latest members', (
    WidgetTester tester,
  ) async {
    final gateway = _FakeGroupDatabaseGateway()
      ..loadGroupMembersResult = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'member-2',
          'user_id': 'user-2',
          'role': 'member',
          'joined_at': '2026-05-26T00:01:00.000Z',
          'users': <String, dynamic>{
            'display_name': '새 멤버',
            'email': 'new@example.com',
          },
        },
      ];
    SupabaseService.debugGroupDatabaseGateway = gateway;
    GroupStore.instance.value = GroupState(group: _group());

    await tester.pumpWidget(_wrap());
    await tester.tap(find.byTooltip('멤버 새로고침'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(gateway.loadGroupMembersCalls, 1);
    expect(find.text('새 멤버'), findsOneWidget);
    expect(find.text('멤버 1명'), findsOneWidget);
  });
```

- [ ] **Step 3: Run the widget test and verify it fails**

Run:

```powershell
flutter test test/screens/group_screen_test.dart
```

Expected: FAIL because the member count, tooltip, refresh action, and role label getter are not wired into the UI.

- [ ] **Step 4: Pass refresh state into `_GroupCard`**

Update the `GroupScreen` builder in `lib/screens/group_screen.dart`:

```dart
                if (state.group == null)
                  _EmptyGroupState(errorMessage: state.errorMessage)
                else
                  _GroupCard(
                    group: state.group!,
                    isRefreshingMembers: state.isRefreshingMembers,
                  ),
```

Update `_GroupCard` fields:

```dart
class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.isRefreshingMembers,
  });

  final BuylogGroup group;
  final bool isRefreshingMembers;
```

- [ ] **Step 5: Replace the member section header**

Replace the existing member title block in `_GroupCard.build()`:

```dart
          const SizedBox(height: 20),
          Text('멤버', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
```

with:

```dart
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  '멤버 ${group.members.length}명',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: '멤버 새로고침',
                onPressed: isRefreshingMembers
                    ? null
                    : () => GroupStore.instance.refreshMembers(),
                icon: isRefreshingMembers
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
```

- [ ] **Step 6: Replace inline role text with a role badge**

Replace the final `Text` widget in `_MemberRow.build()`:

```dart
        Text(
          member.role == GroupRole.owner ? '관리자' : '멤버',
          style: Theme.of(context).textTheme.bodySmall,
        ),
```

with:

```dart
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: member.role == GroupRole.owner
                ? AppColors.primaryLight2
                : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Text(
            member.role.displayLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: member.role == GroupRole.owner
                      ? AppColors.primaryDark
                      : AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
```

- [ ] **Step 7: Run the widget test and verify it passes**

Run:

```powershell
flutter test test/screens/group_screen_test.dart
```

Expected: PASS for all `group_screen_test.dart` tests.

- [ ] **Step 8: Commit the UI rendering change**

Run:

```powershell
git add lib/screens/group_screen.dart test/screens/group_screen_test.dart
git commit -m "feat: show group member roles"
```

Expected: commit succeeds with the screen and widget tests staged.

---

### Task 5: Verify Supabase RLS Supports Member List Reads

**Files:**
- Inspect: `supabase/migrations/20260526193000_add_group_rls_policies.sql:142-159`

- [ ] **Step 1: Confirm the existing policy allows group member list reads**

Run:

```powershell
Select-String -Path supabase\migrations\20260526193000_add_group_rls_policies.sql -Pattern 'Users can view relevant group memberships|private.is_group_member|for select' -Context 2,6
```

Expected: output includes a `public.group_members` `for select` policy whose `using` clause allows the current user when `private.is_group_member(group_id, current_user_id)` is true.

- [ ] **Step 2: Confirm no migration file is needed for this feature**

Run:

```powershell
git status --short supabase
```

Expected: no new Supabase migration is required for member list reads because the existing policy already permits the scoped select.

- [ ] **Step 3: Commit nothing for RLS verification**

Run:

```powershell
git status --short
```

Expected: no Supabase files are staged or committed by this task.

---

### Task 6: Full Verification and Final Commit Check

**Files:**
- Verify: `lib/models/group.dart`
- Verify: `lib/services/supabase_service.dart`
- Verify: `lib/services/group_store.dart`
- Verify: `lib/screens/group_screen.dart`
- Verify: `test/services/group_store_test.dart`
- Verify: `test/services/supabase_service_test.dart`
- Verify: `test/screens/group_screen_test.dart`

- [ ] **Step 1: Run format**

Run:

```powershell
dart format lib\models\group.dart lib\services\supabase_service.dart lib\services\group_store.dart lib\screens\group_screen.dart test\services\group_store_test.dart test\services\supabase_service_test.dart test\screens\group_screen_test.dart
```

Expected: formatter completes successfully and reports only those files if it changes formatting.

- [ ] **Step 2: Run focused tests**

Run:

```powershell
flutter test test/services/group_store_test.dart test/services/supabase_service_test.dart test/screens/group_screen_test.dart
```

Expected: PASS for all focused group/member tests.

- [ ] **Step 3: Run analyzer using this repo's CI-aligned command**

Run:

```powershell
flutter analyze --no-fatal-infos
```

Expected: exits 0. Info-level lint output is acceptable only if the command exits 0.

- [ ] **Step 4: Run the full test suite**

Run:

```powershell
flutter test
```

Expected: PASS for the full Flutter test suite.

- [ ] **Step 5: Review the final diff**

Run:

```powershell
git diff -- lib\models\group.dart lib\services\supabase_service.dart lib\services\group_store.dart lib\screens\group_screen.dart test\services\group_store_test.dart test\services\supabase_service_test.dart test\screens\group_screen_test.dart
```

Expected: diff only contains group member list retrieval, store refresh state, role display labels, role badge UI, and tests.

- [ ] **Step 6: Commit verification cleanup if formatting changed files**

Run:

```powershell
git status --short
git add lib/models/group.dart lib/services/supabase_service.dart lib/services/group_store.dart lib/screens/group_screen.dart test/services/group_store_test.dart test/services/supabase_service_test.dart test/screens/group_screen_test.dart
git commit -m "test: verify group member list display"
```

Expected: create this commit only if Step 1 produced formatting-only changes after the previous feature commits. If there are no staged changes, do not create an empty commit.

---

## Self-Review

- Spec coverage: The plan covers member list retrieval from Supabase, owner/member role mapping, UI role display, refresh behavior, RLS read-policy verification, and focused/full tests.
- Placeholder scan: The plan contains exact file paths, commands, expected outputs, and code snippets for each implementation step.
- Type consistency: `GroupRole.displayLabel`, `BuylogGroup.copyWith`, `SupabaseService.loadGroupMembers`, `GroupDatabaseGateway.loadGroupMembers`, `GroupState.isRefreshingMembers`, and `GroupStore.refreshMembers` use the same names across tests, implementation, and UI steps.
