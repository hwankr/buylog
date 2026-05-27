# Group Leave Owner Delegation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 그룹 멤버가 그룹을 탈퇴할 수 있고, 현재 사용자가 `owner`이면 다른 멤버에게 owner 권한을 위임한 뒤 탈퇴하게 만든다.

**Architecture:** 권한 변경과 탈퇴는 Supabase RPC 하나에서 트랜잭션처럼 처리해 중간 상태를 남기지 않는다. Flutter 쪽은 `SupabaseService`와 `GroupStore`에 비즈니스 로직을 두고, `GroupScreen`은 현재 상태에 맞는 탈퇴/위임 확인 UI만 렌더링한다.

**Tech Stack:** Flutter, Dart, `ValueNotifier`, `supabase_flutter`, Supabase Postgres RPC/RLS, `flutter_test`.

---

## Current Repo Context

- 그룹 모델은 `lib/models/group.dart`의 `BuylogGroup`, `BuylogGroupMember`, `GroupRole`에 있다.
- 현재 사용자 ID는 `SupabaseService.currentUserId`로 제공된다. 실제 Auth 도입 전까지 하드코딩된 dev UUID를 사용한다.
- 그룹 목록/선택 상태는 `lib/services/group_store.dart`의 `GroupStore.instance`가 관리한다.
- Supabase 그룹 gateway 계약은 `lib/services/supabase_service.dart`의 `GroupDatabaseGateway`와 `SupabaseGroupDatabaseGateway`에 있다.
- 그룹 UI는 `lib/screens/group_screen.dart`의 `_GroupCard`, `_MemberRow`, `_CreateGroupDialog`에 모여 있다.
- 기존 RLS 마이그레이션은 `private.is_group_owner()`를 제공하지만 `group_members`에 `delete`/`update` 정책은 없다. 그래서 탈퇴와 owner 위임은 직접 테이블 조작이 아니라 검증된 RPC로 처리한다.
- AGENTS.md 기준상 새 비즈니스 로직 테스트 누락은 `[P1]`이므로 모델, 서비스, store, widget 테스트를 먼저 추가한다. Flutter 위젯에 탈퇴 가능 여부 판단 같은 비즈니스 로직을 직접 넣지 않는다.

## File Structure

- Modify: `lib/models/group.dart`
  - 현재 사용자 멤버 조회, owner 여부, 위임 후보 목록을 모델 helper로 제공한다.
- Modify: `test/services/group_store_test.dart`
  - 모델 helper와 `GroupStore.leaveGroup()` 성공/실패/owner 위임 시나리오를 검증한다.
- Modify: `lib/services/supabase_service.dart`
  - `SupabaseService.leaveGroup()`와 `GroupDatabaseGateway.leaveGroup()`을 추가한다.
  - `SupabaseGroupDatabaseGateway`는 `leave_group` RPC를 호출한다.
- Modify: `test/services/supabase_service_test.dart`
  - group id trim, blank validation, delegation user id trim, gateway 호출 payload를 검증한다.
- Create: `supabase/migrations/20260527103000_add_group_leave_rpc.sql`
  - `public.leave_group(target_group_id uuid, new_owner_user_id uuid default null)` RPC를 추가한다.
  - 멤버 여부, owner 단독 탈퇴 차단, owner 위임 대상 검증, `users.default_group_id` 정리를 서버에서 처리한다.
- Modify: `lib/services/group_store.dart`
  - `GroupState.isLeavingGroup`을 추가한다.
  - `GroupStore.leaveGroup()`이 RPC 성공 후 가입 그룹 목록을 다시 로드하고 선택 scope를 안정적으로 갱신한다.
- Modify: `lib/screens/group_screen.dart`
  - 그룹 카드에 탈퇴 액션을 추가한다.
  - owner가 탈퇴할 때 위임 후보를 선택하는 dialog를 표시한다.
  - 마지막 owner가 혼자 남은 그룹에서는 탈퇴 실행을 막고 안내 문구를 보여준다.
- Modify: `test/screens/group_screen_test.dart`
  - 일반 멤버 탈퇴 dialog, owner 위임 dropdown, 단독 owner 차단, 성공 후 그룹 카드 제거를 검증한다.

---

### Task 1: Add Group Membership Helper Methods

**Files:**
- Modify: `lib/models/group.dart`
- Modify: `test/services/group_store_test.dart`

- [ ] **Step 1: Write failing model helper tests**

Add this group after the existing `BuylogGroup Supabase parsing` group in `test/services/group_store_test.dart`:

```dart
  group('BuylogGroup membership helpers', () {
    test('finds the current user member and owner status', () {
      final group = _groupWithMembers();

      expect(group.memberForUser('owner-user')?.role, GroupRole.owner);
      expect(group.memberForUser('member-user')?.role, GroupRole.member);
      expect(group.memberForUser('missing-user'), isNull);
      expect(group.isOwner('owner-user'), isTrue);
      expect(group.isOwner('member-user'), isFalse);
    });

    test('returns delegation candidates excluding current user', () {
      final group = _groupWithMembers();

      final candidates = group.delegationCandidates('owner-user');

      expect(candidates.map((member) => member.userId), ['member-user']);
      expect(candidates.single.displayName, '멤버');
    });
  });
```

Add this helper near the existing `_member()` helper in the same test file:

```dart
BuylogGroup _groupWithMembers() {
  return BuylogGroup(
    id: 'group-1',
    name: '우리 가족',
    inviteCode: 'BUY-ABC123',
    createdBy: 'owner-user',
    createdAt: DateTime.parse('2026-05-27T00:00:00.000Z'),
    members: [
      BuylogGroupMember(
        id: 'member-1',
        userId: 'owner-user',
        displayName: '소유자',
        role: GroupRole.owner,
        joinedAt: DateTime.parse('2026-05-27T00:00:00.000Z'),
      ),
      BuylogGroupMember(
        id: 'member-2',
        userId: 'member-user',
        displayName: '멤버',
        role: GroupRole.member,
        joinedAt: DateTime.parse('2026-05-27T00:01:00.000Z'),
      ),
    ],
  );
}
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run:

```powershell
flutter test test/services/group_store_test.dart
```

Expected: FAIL with compile errors for `memberForUser`, `isOwner`, and `delegationCandidates`.

- [ ] **Step 3: Add model helper methods**

Add these methods inside `class BuylogGroup` in `lib/models/group.dart`, after `copyWith()`:

```dart
  BuylogGroupMember? memberForUser(String userId) {
    final trimmedUserId = userId.trim();
    if (trimmedUserId.isEmpty) return null;

    for (final member in members) {
      if (member.userId == trimmedUserId) {
        return member;
      }
    }
    return null;
  }

  bool isOwner(String userId) {
    return memberForUser(userId)?.role == GroupRole.owner;
  }

  List<BuylogGroupMember> delegationCandidates(String currentUserId) {
    final trimmedUserId = currentUserId.trim();
    return List<BuylogGroupMember>.unmodifiable(
      members.where((member) => member.userId != trimmedUserId),
    );
  }
```

- [ ] **Step 4: Run the focused test and verify it passes**

Run:

```powershell
flutter test test/services/group_store_test.dart
```

Expected: PASS for all tests in `group_store_test.dart`.

- [ ] **Step 5: Commit**

Run:

```powershell
git add lib/models/group.dart test/services/group_store_test.dart
git commit -m "feat: add group membership helpers"
```

Expected: commit succeeds with only model helper and test changes staged.

---

### Task 2: Add Supabase Leave Group Service Contract

**Files:**
- Modify: `lib/services/supabase_service.dart`
- Modify: `test/services/supabase_service_test.dart`
- Modify: `test/services/group_store_test.dart`
- Modify: `test/screens/group_screen_test.dart`

- [ ] **Step 1: Write failing service tests**

Add fields to `_RecordingGroupDatabaseGateway` in `test/services/supabase_service_test.dart`:

```dart
  int leaveGroupCalls = 0;
  String? leaveGroupGroupId;
  String? leaveGroupNewOwnerUserId;
```

Add this method to the same fake gateway:

```dart
  @override
  Future<void> leaveGroup({
    required String groupId,
    required String? newOwnerUserId,
  }) async {
    leaveGroupCalls += 1;
    leaveGroupGroupId = groupId;
    leaveGroupNewOwnerUserId = newOwnerUserId;
  }
```

Add this test group after `SupabaseService.loadGroupMembers`:

```dart
  group('SupabaseService.leaveGroup', () {
    tearDown(() {
      SupabaseService.debugGroupDatabaseGateway = null;
    });

    test('trims ids and delegates to the group gateway', () async {
      final gateway = _RecordingGroupDatabaseGateway();
      SupabaseService.debugGroupDatabaseGateway = gateway;

      await SupabaseService.leaveGroup(
        groupId: ' group-1 ',
        newOwnerUserId: ' member-user ',
      );

      expect(gateway.leaveGroupCalls, 1);
      expect(gateway.leaveGroupGroupId, 'group-1');
      expect(gateway.leaveGroupNewOwnerUserId, 'member-user');
    });

    test('passes null owner delegation for non-owner leave', () async {
      final gateway = _RecordingGroupDatabaseGateway();
      SupabaseService.debugGroupDatabaseGateway = gateway;

      await SupabaseService.leaveGroup(groupId: 'group-1');

      expect(gateway.leaveGroupCalls, 1);
      expect(gateway.leaveGroupGroupId, 'group-1');
      expect(gateway.leaveGroupNewOwnerUserId, isNull);
    });

    test('rejects blank group ids without calling the gateway', () async {
      final gateway = _RecordingGroupDatabaseGateway();
      SupabaseService.debugGroupDatabaseGateway = gateway;

      await expectLater(
        SupabaseService.leaveGroup(groupId: '   '),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'Group id is required.',
          ),
        ),
      );

      expect(gateway.leaveGroupCalls, 0);
    });
  });
```

- [ ] **Step 2: Run the service test and verify it fails**

Run:

```powershell
flutter test test/services/supabase_service_test.dart
```

Expected: FAIL because `SupabaseService.leaveGroup()` and `GroupDatabaseGateway.leaveGroup()` do not exist.

- [ ] **Step 3: Add the service method**

Add this method after `SupabaseService.loadGroupMembers()` in `lib/services/supabase_service.dart`:

```dart
  static Future<void> leaveGroup({
    required String groupId,
    String? newOwnerUserId,
  }) async {
    final trimmedGroupId = groupId.trim();
    if (trimmedGroupId.isEmpty) {
      throw ArgumentError.value(groupId, 'groupId', 'Group id is required.');
    }

    final trimmedOwnerUserId = newOwnerUserId?.trim();
    await _groupDatabaseGateway.leaveGroup(
      groupId: trimmedGroupId,
      newOwnerUserId: trimmedOwnerUserId?.isEmpty == true
          ? null
          : trimmedOwnerUserId,
    );
  }
```

- [ ] **Step 4: Extend the gateway interface and Supabase implementation**

Add this method to `abstract class GroupDatabaseGateway`:

```dart
  Future<void> leaveGroup({
    required String groupId,
    required String? newOwnerUserId,
  });
```

Add this method to `SupabaseGroupDatabaseGateway`:

```dart
  @override
  Future<void> leaveGroup({
    required String groupId,
    required String? newOwnerUserId,
  }) async {
    await _client.rpc(
      'leave_group',
      params: {
        'target_group_id': groupId,
        'new_owner_user_id': newOwnerUserId,
      },
    );
  }
```

- [ ] **Step 5: Update existing fake gateways**

Add a no-op implementation to `_RecordingGroupDatabaseGateway` in `test/services/group_store_test.dart`:

```dart
  @override
  Future<void> leaveGroup({
    required String groupId,
    required String? newOwnerUserId,
  }) async {}
```

Add a no-op implementation to `_FakeGroupDatabaseGateway` in `test/screens/group_screen_test.dart`:

```dart
  @override
  Future<void> leaveGroup({
    required String groupId,
    required String? newOwnerUserId,
  }) async {}
```

- [ ] **Step 6: Run affected tests and verify they pass**

Run:

```powershell
flutter test test/services/supabase_service_test.dart test/services/group_store_test.dart test/screens/group_screen_test.dart
```

Expected: PASS for all three focused test files.

- [ ] **Step 7: Commit**

Run:

```powershell
git add lib/services/supabase_service.dart test/services/supabase_service_test.dart test/services/group_store_test.dart test/screens/group_screen_test.dart
git commit -m "feat: add group leave service contract"
```

Expected: commit succeeds with the service contract and fake gateway updates.

---

### Task 3: Add Supabase RPC for Atomic Leave and Delegation

**Files:**
- Create: `supabase/migrations/20260527103000_add_group_leave_rpc.sql`

- [ ] **Step 1: Create the migration**

Create `supabase/migrations/20260527103000_add_group_leave_rpc.sql` with this content:

```sql
-- Atomically leave a group. Owners must delegate to another member first.
-- The app still uses the dev UUID fallback until Supabase Auth is wired.

begin;

create or replace function public.leave_group(
  target_group_id uuid,
  new_owner_user_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := coalesce(
    auth.uid(),
    '08cccfe3-766f-43bd-b06c-8d909e0f9fe8'::uuid
  );
  current_role text;
  member_count int;
begin
  select gm.role
  into current_role
  from public.group_members as gm
  where gm.group_id = target_group_id
    and gm.user_id = current_user_id;

  if current_role is null then
    raise exception 'not_a_group_member'
      using errcode = 'P0001';
  end if;

  select count(*)
  into member_count
  from public.group_members as gm
  where gm.group_id = target_group_id;

  if current_role = 'owner' then
    if member_count <= 1 then
      raise exception 'last_owner_cannot_leave'
        using errcode = 'P0001';
    end if;

    if new_owner_user_id is null then
      raise exception 'new_owner_required'
        using errcode = 'P0001';
    end if;

    if new_owner_user_id = current_user_id then
      raise exception 'new_owner_must_be_different'
        using errcode = 'P0001';
    end if;

    update public.group_members
    set role = 'owner'
    where group_id = target_group_id
      and user_id = new_owner_user_id;

    if not found then
      raise exception 'new_owner_not_group_member'
        using errcode = 'P0001';
    end if;
  end if;

  delete from public.group_members
  where group_id = target_group_id
    and user_id = current_user_id;

  update public.users
  set default_group_id = (
    select gm.group_id
    from public.group_members as gm
    where gm.user_id = current_user_id
    order by gm.joined_at asc
    limit 1
  )
  where id = current_user_id
    and default_group_id = target_group_id;
end;
$$;

revoke all on function public.leave_group(uuid, uuid) from public, anon, authenticated;
grant execute on function public.leave_group(uuid, uuid) to anon, authenticated;

commit;
```

- [ ] **Step 2: Verify the migration contains expected safeguards**

Run:

```powershell
Select-String -Path supabase\migrations\20260527103000_add_group_leave_rpc.sql -Pattern 'last_owner_cannot_leave|new_owner_required|new_owner_not_group_member|delete from public.group_members|default_group_id'
```

Expected: output includes all five safeguards/operations.

- [ ] **Step 3: Commit**

Run:

```powershell
git add supabase/migrations/20260527103000_add_group_leave_rpc.sql
git commit -m "feat: add group leave rpc"
```

Expected: commit succeeds with only the new migration file.

---

### Task 4: Add GroupStore Leave State and Refresh Behavior

**Files:**
- Modify: `lib/services/group_store.dart`
- Modify: `test/services/group_store_test.dart`

- [ ] **Step 1: Write failing store tests**

Add fields to `_RecordingGroupDatabaseGateway` in `test/services/group_store_test.dart`:

```dart
  int leaveGroupCalls = 0;
  String? leaveGroupGroupId;
  String? leaveGroupNewOwnerUserId;
  Object? leaveGroupError;
```

Replace the no-op `leaveGroup` fake from Task 2 with:

```dart
  @override
  Future<void> leaveGroup({
    required String groupId,
    required String? newOwnerUserId,
  }) async {
    leaveGroupCalls += 1;
    leaveGroupGroupId = groupId;
    leaveGroupNewOwnerUserId = newOwnerUserId;
    if (leaveGroupError != null) {
      throw leaveGroupError!;
    }
  }
```

Add these tests inside the existing `GroupStore` group:

```dart
    test('leaves the selected group and reloads joined groups', () async {
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

      expect(gateway.leaveGroupCalls, 1);
      expect(gateway.leaveGroupGroupId, 'group-1');
      expect(gateway.leaveGroupNewOwnerUserId, isNull);
      expect(GroupStore.instance.value.groups.map((group) => group.id), [
        'group-2',
      ]);
      expect(GroupStore.instance.value.selectedScope, const ItemScope.personal());
      expect(GroupStore.instance.value.isLeavingGroup, isFalse);
      expect(GroupStore.instance.value.errorMessage, isNull);
    });

    test('passes owner delegation user id when leaving as owner', () async {
      gateway.loadGroupsForUserResult = <Map<String, dynamic>>[
        _groupRow(id: 'group-1', name: '우리 가족'),
      ];
      await GroupStore.instance.initialize();

      await GroupStore.instance.leaveGroup(
        groupId: 'group-1',
        newOwnerUserId: 'member-user',
      );

      expect(gateway.leaveGroupCalls, 1);
      expect(gateway.leaveGroupNewOwnerUserId, 'member-user');
    });

    test('restores previous state when leave fails', () async {
      gateway.loadGroupsForUserResult = <Map<String, dynamic>>[
        _groupRow(id: 'group-1', name: '우리 가족'),
      ];
      await GroupStore.instance.initialize();
      gateway.leaveGroupError = StateError('leave failed');

      await expectLater(
        GroupStore.instance.leaveGroup(groupId: 'group-1'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'leave failed',
          ),
        ),
      );

      expect(GroupStore.instance.value.groups.single.id, 'group-1');
      expect(GroupStore.instance.value.isLeavingGroup, isFalse);
      expect(
        GroupStore.instance.value.errorMessage,
        '그룹을 탈퇴하지 못했습니다. 잠시 후 다시 시도해 주세요.',
      );
    });
```

- [ ] **Step 2: Run the store test and verify it fails**

Run:

```powershell
flutter test test/services/group_store_test.dart
```

Expected: FAIL because `isLeavingGroup` and `leaveGroup()` do not exist.

- [ ] **Step 3: Add `isLeavingGroup` to `GroupState`**

Update `GroupState` constructor, field list, and `copyWith()` in `lib/services/group_store.dart`:

```dart
  const GroupState({
    this.group,
    this.groups = const [],
    this.selectedScope = const ItemScope.personal(),
    this.isLoading = false,
    this.isSaving = false,
    this.isRefreshingMembers = false,
    this.isLeavingGroup = false,
    this.errorMessage,
  });
```

```dart
  final bool isLeavingGroup;
```

```dart
    bool? isLeavingGroup,
```

```dart
      isLeavingGroup: isLeavingGroup ?? this.isLeavingGroup,
```

- [ ] **Step 4: Add `GroupStore.leaveGroup()`**

Add this method after `refreshMembers()` in `lib/services/group_store.dart`:

```dart
  Future<void> leaveGroup({
    required String groupId,
    String? newOwnerUserId,
  }) async {
    final trimmedGroupId = groupId.trim();
    if (trimmedGroupId.isEmpty || value.isLeavingGroup) {
      return;
    }

    final previousState = value;
    value = previousState.copyWith(isLeavingGroup: true, errorMessage: null);

    try {
      await SupabaseService.leaveGroup(
        groupId: trimmedGroupId,
        newOwnerUserId: newOwnerUserId,
      );
      final groups = await SupabaseService.loadGroupsForUser();
      final selectedScope =
          previousState.selectedScope.isGroup &&
              previousState.selectedScope.id == trimmedGroupId
          ? const ItemScope.personal()
          : previousState.selectedScope;
      final selectedStillAvailable = <ItemScope>[
        const ItemScope.personal(),
        for (final group in groups) ItemScope.group(id: group.id, label: group.name),
      ].contains(selectedScope);

      value = GroupState(
        group: groups.isEmpty ? null : groups.first,
        groups: groups,
        selectedScope: selectedStillAvailable
            ? selectedScope
            : const ItemScope.personal(),
      );
    } catch (_) {
      value = previousState.copyWith(
        isLeavingGroup: false,
        errorMessage: '그룹을 탈퇴하지 못했습니다. 잠시 후 다시 시도해 주세요.',
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

Expected: PASS for all tests in `group_store_test.dart`.

- [ ] **Step 6: Commit**

Run:

```powershell
git add lib/services/group_store.dart test/services/group_store_test.dart
git commit -m "feat: leave group from store"
```

Expected: commit succeeds with store state and tests.

---

### Task 5: Add Group Leave and Owner Delegation UI

**Files:**
- Modify: `lib/screens/group_screen.dart`
- Modify: `test/screens/group_screen_test.dart`

- [ ] **Step 1: Write failing widget tests**

Add fields to `_FakeGroupDatabaseGateway` in `test/screens/group_screen_test.dart`:

```dart
  int leaveGroupCalls = 0;
  String? leaveGroupGroupId;
  String? leaveGroupNewOwnerUserId;
```

Replace the no-op `leaveGroup` fake from Task 2 with:

```dart
  @override
  Future<void> leaveGroup({
    required String groupId,
    required String? newOwnerUserId,
  }) async {
    leaveGroupCalls += 1;
    leaveGroupGroupId = groupId;
    leaveGroupNewOwnerUserId = newOwnerUserId;
    _currentGroup = null;
  }
```

Add this helper near `_group()`:

```dart
BuylogGroup _singleOwnerGroup() {
  return BuylogGroup(
    id: 'group-1',
    name: '우리 가족',
    inviteCode: 'BUY-ABC123',
    createdBy: SupabaseService.currentUserId,
    createdAt: DateTime.parse('2026-05-26T00:00:00.000Z'),
    members: [
      BuylogGroupMember(
        id: 'member-1',
        userId: SupabaseService.currentUserId,
        displayName: '소유자',
        role: GroupRole.owner,
        joinedAt: DateTime.parse('2026-05-26T00:00:00.000Z'),
      ),
    ],
  );
}
```

Add these widget tests:

```dart
  testWidgets('member can confirm leaving a group', (tester) async {
    final gateway = _FakeGroupDatabaseGateway();
    SupabaseService.debugGroupDatabaseGateway = gateway;
    GroupStore.instance.value = GroupState(
      groups: <BuylogGroup>[
        _group().copyWith(
          members: [
            BuylogGroupMember(
              id: 'member-current',
              userId: SupabaseService.currentUserId,
              displayName: '나',
              role: GroupRole.member,
              joinedAt: DateTime.parse('2026-05-26T00:00:00.000Z'),
            ),
          ],
        ),
      ],
      selectedScope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
    );

    await tester.pumpWidget(_wrap());
    await tester.tap(find.text('그룹 탈퇴'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('탈퇴'),
    ));
    await tester.pumpAndSettle();

    expect(gateway.leaveGroupCalls, 1);
    expect(gateway.leaveGroupGroupId, 'group-1');
    expect(gateway.leaveGroupNewOwnerUserId, isNull);
  });

  testWidgets('owner selects a new owner before leaving', (tester) async {
    final gateway = _FakeGroupDatabaseGateway();
    SupabaseService.debugGroupDatabaseGateway = gateway;
    GroupStore.instance.value = GroupState(
      groups: <BuylogGroup>[_group()],
      selectedScope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
    );

    await tester.pumpWidget(_wrap());
    await tester.tap(find.text('그룹 탈퇴'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('멤버').last);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('위임 후 탈퇴'),
    ));
    await tester.pumpAndSettle();

    expect(gateway.leaveGroupCalls, 1);
    expect(gateway.leaveGroupNewOwnerUserId, 'user-2');
  });

  testWidgets('single owner cannot leave without another member', (tester) async {
    GroupStore.instance.value = GroupState(
      groups: <BuylogGroup>[_singleOwnerGroup()],
      selectedScope: const ItemScope.group(id: 'group-1', label: '우리 가족'),
    );

    await tester.pumpWidget(_wrap());
    await tester.tap(find.text('그룹 탈퇴'));
    await tester.pumpAndSettle();

    expect(find.text('마지막 관리자는 그룹을 탈퇴할 수 없습니다.'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '탈퇴').last,
      ).onPressed,
      isNull,
    );
  });
```

- [ ] **Step 2: Run the widget test and verify it fails**

Run:

```powershell
flutter test test/screens/group_screen_test.dart
```

Expected: FAIL because the leave button, dialog, and delegation dropdown do not exist.

- [ ] **Step 3: Pass leave state and action into `_GroupCard`**

Update the `_GroupCard` call in `GroupScreen.build()`:

```dart
                    child: _GroupCard(
                      group: selectedGroup,
                      isRefreshingMembers: state.isRefreshingMembers,
                      isLeavingGroup: state.isLeavingGroup,
                      onRefreshMembers: () => GroupStore.instance
                          .refreshMembers(groupId: selectedGroup.id),
                    ),
```

Update `_GroupCard` constructor and fields:

```dart
  const _GroupCard({
    required this.group,
    required this.isRefreshingMembers,
    required this.isLeavingGroup,
    required this.onRefreshMembers,
  });

  final BuylogGroup group;
  final bool isRefreshingMembers;
  final bool isLeavingGroup;
  final VoidCallback onRefreshMembers;
```

- [ ] **Step 4: Add the leave action button to `_GroupCard`**

Add this block after the invite code container and before the member header in `_GroupCard.build()`:

```dart
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: isLeavingGroup
                  ? null
                  : () => showDialog<void>(
                        context: context,
                        builder: (_) => _LeaveGroupDialog(group: group),
                      ),
              icon: isLeavingGroup
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout, size: 18),
              label: const Text('그룹 탈퇴'),
            ),
          ),
```

- [ ] **Step 5: Add the leave/delegation dialog widget**

Add this widget before `_CreateGroupDialog` in `lib/screens/group_screen.dart`:

```dart
class _LeaveGroupDialog extends StatefulWidget {
  const _LeaveGroupDialog({required this.group});

  final BuylogGroup group;

  @override
  State<_LeaveGroupDialog> createState() => _LeaveGroupDialogState();
}

class _LeaveGroupDialogState extends State<_LeaveGroupDialog> {
  String? _selectedNewOwnerUserId;

  @override
  void initState() {
    super.initState();
    final candidates = widget.group.delegationCandidates(
      SupabaseService.currentUserId,
    );
    _selectedNewOwnerUserId = candidates.isEmpty ? null : candidates.first.userId;
  }

  Future<void> _submit() async {
    final isOwner = widget.group.isOwner(SupabaseService.currentUserId);
    final candidates = widget.group.delegationCandidates(
      SupabaseService.currentUserId,
    );
    if (isOwner && candidates.isEmpty) {
      return;
    }

    await GroupStore.instance.leaveGroup(
      groupId: widget.group.id,
      newOwnerUserId: isOwner ? _selectedNewOwnerUserId : null,
    );

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = widget.group.isOwner(SupabaseService.currentUserId);
    final candidates = widget.group.delegationCandidates(
      SupabaseService.currentUserId,
    );
    final cannotLeave = isOwner && candidates.isEmpty;

    return ValueListenableBuilder<GroupState>(
      valueListenable: GroupStore.instance,
      builder: (context, state, _) {
        return AlertDialog(
          title: Text(isOwner ? '관리자 위임 후 탈퇴' : '그룹 탈퇴'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cannotLeave
                    ? '마지막 관리자는 그룹을 탈퇴할 수 없습니다.'
                    : '이 그룹에서 나가면 그룹 물품과 멤버 목록을 볼 수 없습니다.',
              ),
              if (isOwner && candidates.isNotEmpty) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedNewOwnerUserId,
                  decoration: const InputDecoration(labelText: '새 관리자'),
                  items: [
                    for (final member in candidates)
                      DropdownMenuItem<String>(
                        value: member.userId,
                        child: Text(member.displayName),
                      ),
                  ],
                  onChanged: state.isLeavingGroup
                      ? null
                      : (value) {
                          setState(() {
                            _selectedNewOwnerUserId = value;
                          });
                        },
                ),
              ],
              if (state.errorMessage?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Text(
                  state.errorMessage!,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: state.isLeavingGroup
                  ? null
                  : () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: state.isLeavingGroup || cannotLeave ? null : _submit,
              child: state.isLeavingGroup
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isOwner ? '위임 후 탈퇴' : '탈퇴'),
            ),
          ],
        );
      },
    );
  }
}
```

- [ ] **Step 6: Add the required import**

Add this import at the top of `lib/screens/group_screen.dart`:

```dart
import '../services/supabase_service.dart';
```

- [ ] **Step 7: Run the widget test and verify it passes**

Run:

```powershell
flutter test test/screens/group_screen_test.dart
```

Expected: PASS for all tests in `group_screen_test.dart`.

- [ ] **Step 8: Commit**

Run:

```powershell
git add lib/screens/group_screen.dart test/screens/group_screen_test.dart
git commit -m "feat: add group leave dialog"
```

Expected: commit succeeds with UI and widget tests.

---

### Task 6: Verification

**Files:**
- Verify: `lib/models/group.dart`
- Verify: `lib/services/supabase_service.dart`
- Verify: `lib/services/group_store.dart`
- Verify: `lib/screens/group_screen.dart`
- Verify: `test/services/group_store_test.dart`
- Verify: `test/services/supabase_service_test.dart`
- Verify: `test/screens/group_screen_test.dart`
- Verify: `supabase/migrations/20260527103000_add_group_leave_rpc.sql`

- [ ] **Step 1: Format changed Dart files**

Run:

```powershell
dart format lib\models\group.dart lib\services\supabase_service.dart lib\services\group_store.dart lib\screens\group_screen.dart test\services\group_store_test.dart test\services\supabase_service_test.dart test\screens\group_screen_test.dart
```

Expected: formatter completes without parse errors.

- [ ] **Step 2: Run focused tests**

Run:

```powershell
flutter test test/services/group_store_test.dart test/services/supabase_service_test.dart test/screens/group_screen_test.dart
```

Expected: PASS for all group leave/delegation tests and existing group tests.

- [ ] **Step 3: Run analyzer**

Run:

```powershell
flutter analyze --no-fatal-infos
```

Expected: exits 0. Info-level output is acceptable only if the command exits 0.

- [ ] **Step 4: Run the full test suite**

Run:

```powershell
flutter test
```

Expected: PASS for the full Flutter test suite.

- [ ] **Step 5: Review final diff**

Run:

```powershell
git diff -- lib\models\group.dart lib\services\supabase_service.dart lib\services\group_store.dart lib\screens\group_screen.dart test\services\group_store_test.dart test\services\supabase_service_test.dart test\screens\group_screen_test.dart supabase\migrations\20260527103000_add_group_leave_rpc.sql
```

Expected: diff only contains membership helpers, group leave service/store logic, group leave/delegation UI, tests, and the Supabase RPC migration.

---

## Self-Review

- Spec coverage: 그룹 탈퇴는 `SupabaseService.leaveGroup()`, `GroupStore.leaveGroup()`, `_LeaveGroupDialog`가 담당한다. owner 권한 위임은 RPC의 `new_owner_user_id` 검증과 UI dropdown으로 처리한다. 마지막 owner 단독 탈퇴는 RPC와 UI 양쪽에서 차단한다.
- Placeholder scan: 이 계획은 파일 경로, 테스트 코드, 구현 코드, SQL migration, 명령어, expected result를 포함한다.
- Type consistency: `memberForUser`, `isOwner`, `delegationCandidates`, `leaveGroup`, `isLeavingGroup`, `newOwnerUserId` 이름을 테스트, 구현, UI에서 동일하게 사용한다.
- Boundary check: 탈퇴 가능 여부와 위임 후보 계산은 모델/store/server에 두고, widget에는 상태 렌더링과 확인 입력만 둔다.
