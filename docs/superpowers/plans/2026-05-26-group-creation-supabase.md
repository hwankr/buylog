# Group Creation Supabase Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a real group creation flow in the Group tab and persist created groups to Supabase `groups`, `group_members`, and `users.default_group_id`.

**Architecture:** Keep business logic out of Flutter widgets by introducing a focused group model, a testable `GroupStore`, and a Supabase gateway seam. `GroupScreen` becomes a renderer/controller for user input only; persistence and rollback live in services. The database change adds explicit RLS policies for group/member access before the Flutter client starts writing to public tables.

**Tech Stack:** Flutter, Dart, `ValueNotifier`, `supabase_flutter`, Supabase Postgres migrations, `flutter_test`.

---

## Current Repo Context

- Existing group UI is in `lib/screens/group_screen.dart` and currently uses `SampleData.groupMembers`.
- Existing Supabase access is centralized in `lib/services/supabase_service.dart`.
- Existing app state pattern uses `ItemStore.instance` as a singleton `ValueNotifier`.
- Existing DB schema already has `public.groups`, `public.group_members`, and `users.default_group_id` in `supabase/migrations/20260424000100_initial_schema.sql`.
- Current hard-coded user identity is `SupabaseService.currentUserId`, so this feature should use that same contract until real auth replaces it.
- Required verification pair for this repo is `flutter analyze --no-fatal-infos` and `flutter test`.

## File Structure

- Create: `lib/models/group.dart`
  - `BuylogGroup` and `BuylogGroupMember` immutable data models.
  - JSON mapping from Supabase rows.
- Create: `lib/services/group_store.dart`
  - Singleton `ValueNotifier<GroupState>`.
  - Loads current/default group.
  - Creates group with optimistic loading state and rollback/error state.
- Modify: `lib/services/supabase_service.dart`
  - Add a `GroupDatabaseGateway` seam for tests.
  - Add `loadDefaultGroup()` and `createGroup()` methods.
  - Keep all Supabase query details here.
- Modify: `lib/screens/group_screen.dart`
  - Replace sample group card with `GroupStore` backed rendering.
  - Add "그룹 만들기" empty state and dialog/sheet.
  - Show created group name, invite code, and current members from Supabase-backed state.
- Create: `test/services/group_store_test.dart`
  - Covers successful creation, validation delegation, and rollback/error behavior.
- Extend: `test/services/supabase_service_test.dart`
  - Covers the Supabase payload shape for group creation without live network calls.
- Create: `test/screens/group_screen_test.dart`
  - Covers empty state, form validation, loading state, and created group rendering.
- Create: `supabase/migrations/<generated>_add_group_rls_policies.sql`
  - Must be generated with `supabase migration new add_group_rls_policies`.
  - Enables RLS and adds policies for `groups`, `group_members`, and `users.default_group_id` access.

---

### Task 1: Add Group Models

**Files:**
- Create: `lib/models/group.dart`
- Test: `test/services/group_store_test.dart`

- [ ] **Step 1: Write the model parsing tests**

Add the first tests to `test/services/group_store_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:buylog/models/group.dart';

void main() {
  group('BuylogGroup', () {
    test('parses a Supabase group row with members', () {
      final group = BuylogGroup.fromSupabase({
        'id': 'group-1',
        'name': '우리 가족',
        'invite_code': 'BUY-ABC123',
        'created_by': 'user-1',
        'created_at': '2026-05-26T10:00:00.000Z',
        'group_members': [
          {
            'id': 'member-1',
            'user_id': 'user-1',
            'role': 'owner',
            'joined_at': '2026-05-26T10:00:00.000Z',
            'users': {
              'display_name': '사용자',
              'email': 'user@example.com',
              'avatar_url': null,
            },
          },
        ],
      });

      expect(group.id, 'group-1');
      expect(group.name, '우리 가족');
      expect(group.inviteCode, 'BUY-ABC123');
      expect(group.members.single.role, GroupRole.owner);
      expect(group.members.single.displayName, '사용자');
    });

    test('falls back to email when display_name is missing', () {
      final member = BuylogGroupMember.fromSupabase({
        'id': 'member-1',
        'user_id': 'user-1',
        'role': 'member',
        'joined_at': '2026-05-26T10:00:00.000Z',
        'users': {'display_name': null, 'email': 'user@example.com'},
      });

      expect(member.displayName, 'user@example.com');
      expect(member.role, GroupRole.member);
    });
  });
}
```

- [ ] **Step 2: Run the focused test and confirm it fails**

Run:

```powershell
flutter test test/services/group_store_test.dart
```

Expected: FAIL because `package:buylog/models/group.dart` does not exist.

- [ ] **Step 3: Implement the group models**

Create `lib/models/group.dart`:

```dart
enum GroupRole {
  owner,
  member;

  static GroupRole fromDatabase(String? value) {
    return switch (value) {
      'owner' => GroupRole.owner,
      _ => GroupRole.member,
    };
  }

  String get databaseValue => switch (this) {
    GroupRole.owner => 'owner',
    GroupRole.member => 'member',
  };
}

class BuylogGroup {
  const BuylogGroup({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.createdBy,
    required this.createdAt,
    required this.members,
  });

  final String id;
  final String name;
  final String inviteCode;
  final String? createdBy;
  final DateTime createdAt;
  final List<BuylogGroupMember> members;

  factory BuylogGroup.fromSupabase(Map<String, dynamic> row) {
    final members =
        (row['group_members'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>()
            .map(BuylogGroupMember.fromSupabase)
            .toList() ??
        const <BuylogGroupMember>[];

    return BuylogGroup(
      id: row['id'] as String,
      name: row['name'] as String? ?? '',
      inviteCode: row['invite_code'] as String? ?? '',
      createdBy: row['created_by'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      members: List.unmodifiable(members),
    );
  }
}

class BuylogGroupMember {
  const BuylogGroupMember({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.role,
    required this.joinedAt,
  });

  final String id;
  final String userId;
  final String displayName;
  final GroupRole role;
  final DateTime joinedAt;

  factory BuylogGroupMember.fromSupabase(Map<String, dynamic> row) {
    final user = row['users'] as Map<String, dynamic>?;
    final displayName = user?['display_name'] as String?;
    final email = user?['email'] as String?;

    return BuylogGroupMember(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      displayName: displayName?.trim().isNotEmpty == true
          ? displayName!.trim()
          : (email ?? '사용자'),
      role: GroupRole.fromDatabase(row['role'] as String?),
      joinedAt: DateTime.parse(row['joined_at'] as String),
    );
  }
}
```

- [ ] **Step 4: Run the focused test and confirm it passes**

Run:

```powershell
flutter test test/services/group_store_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add lib/models/group.dart test/services/group_store_test.dart
git commit -m "feat: add group models"
```

---

### Task 2: Add Testable Supabase Group Persistence

**Files:**
- Modify: `lib/services/supabase_service.dart`
- Modify: `test/services/supabase_service_test.dart`

- [ ] **Step 1: Add Supabase service tests for group creation payloads**

Append to `test/services/supabase_service_test.dart`:

```dart
class _RecordingGroupDatabaseGateway implements GroupDatabaseGateway {
  String? updatedDefaultGroupId;
  final insertedGroups = <Map<String, dynamic>>[];
  final insertedMembers = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>?> loadDefaultGroup(String userId) async => null;

  @override
  Future<Map<String, dynamic>> insertGroup(Map<String, dynamic> values) async {
    insertedGroups.add(values);
    return {
      'id': 'group-1',
      'name': values['name'],
      'invite_code': values['invite_code'],
      'created_by': values['created_by'],
      'created_at': '2026-05-26T10:00:00.000Z',
      'group_members': <Map<String, dynamic>>[],
    };
  }

  @override
  Future<void> insertGroupMember(Map<String, dynamic> values) async {
    insertedMembers.add(values);
  }

  @override
  Future<void> updateDefaultGroup({
    required String userId,
    required String groupId,
  }) async {
    updatedDefaultGroupId = groupId;
  }
}

group('SupabaseService.createGroup', () {
  tearDown(() {
    SupabaseService.debugGroupDatabaseGateway = null;
  });

  test('creates a group, owner membership, and default group link', () async {
    final gateway = _RecordingGroupDatabaseGateway();
    SupabaseService.debugGroupDatabaseGateway = gateway;

    final group = await SupabaseService.createGroup(name: '우리 가족');

    expect(group.id, 'group-1');
    expect(gateway.insertedGroups.single['name'], '우리 가족');
    expect(gateway.insertedGroups.single['created_by'], SupabaseService.currentUserId);
    expect(gateway.insertedGroups.single['invite_code'], startsWith('BUY-'));
    expect(gateway.insertedMembers.single, {
      'group_id': 'group-1',
      'user_id': SupabaseService.currentUserId,
      'role': 'owner',
    });
    expect(gateway.updatedDefaultGroupId, 'group-1');
  });
});
```

- [ ] **Step 2: Run the focused Supabase service test and confirm it fails**

Run:

```powershell
flutter test test/services/supabase_service_test.dart
```

Expected: FAIL because `GroupDatabaseGateway`, `debugGroupDatabaseGateway`, and `createGroup()` do not exist.

- [ ] **Step 3: Add group persistence methods and gateway seam**

Modify `lib/services/supabase_service.dart`:

```dart
import '../models/group.dart';
```

Add these members inside `SupabaseService`:

```dart
  @visibleForTesting
  static GroupDatabaseGateway? debugGroupDatabaseGateway;

  static GroupDatabaseGateway get _groupGateway =>
      debugGroupDatabaseGateway ?? SupabaseGroupDatabaseGateway(_db);

  static Future<BuylogGroup?> loadDefaultGroup() async {
    final uid = currentUserId;
    final row = await _groupGateway.loadDefaultGroup(uid);
    if (row == null) return null;
    return BuylogGroup.fromSupabase(row);
  }

  static Future<BuylogGroup> createGroup({required String name}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Group name is required.');
    }

    final uid = currentUserId;
    final groupRow = await _groupGateway.insertGroup({
      'name': trimmed,
      'invite_code': _generateInviteCode(),
      'created_by': uid,
    });
    final groupId = groupRow['id'] as String;

    await _groupGateway.insertGroupMember({
      'group_id': groupId,
      'user_id': uid,
      'role': GroupRole.owner.databaseValue,
    });
    await _groupGateway.updateDefaultGroup(userId: uid, groupId: groupId);

    final reloaded = await _groupGateway.loadDefaultGroup(uid);
    return BuylogGroup.fromSupabase(reloaded ?? groupRow);
  }

  static String _generateInviteCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final suffix = List.generate(
      6,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
    return 'BUY-$suffix';
  }
```

Add these types after `ProductImageStorageGateway` implementations:

```dart
abstract class GroupDatabaseGateway {
  Future<Map<String, dynamic>?> loadDefaultGroup(String userId);
  Future<Map<String, dynamic>> insertGroup(Map<String, dynamic> values);
  Future<void> insertGroupMember(Map<String, dynamic> values);
  Future<void> updateDefaultGroup({
    required String userId,
    required String groupId,
  });
}

class SupabaseGroupDatabaseGateway implements GroupDatabaseGateway {
  const SupabaseGroupDatabaseGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<Map<String, dynamic>?> loadDefaultGroup(String userId) async {
    final userRow = await _client
        .from('users')
        .select('default_group_id')
        .eq('id', userId)
        .maybeSingle();

    final groupId = userRow?['default_group_id'] as String?;
    if (groupId == null) return null;

    return _client
        .from('groups')
        .select('''
          id,
          name,
          invite_code,
          created_by,
          created_at,
          group_members (
            id,
            user_id,
            role,
            joined_at,
            users (
              display_name,
              email,
              avatar_url
            )
          )
        ''')
        .eq('id', groupId)
        .single();
  }

  @override
  Future<Map<String, dynamic>> insertGroup(Map<String, dynamic> values) {
    return _client.from('groups').insert(values).select('''
      id,
      name,
      invite_code,
      created_by,
      created_at,
      group_members (
        id,
        user_id,
        role,
        joined_at,
        users (
          display_name,
          email,
          avatar_url
        )
      )
    ''').single();
  }

  @override
  Future<void> insertGroupMember(Map<String, dynamic> values) async {
    await _client.from('group_members').insert(values);
  }

  @override
  Future<void> updateDefaultGroup({
    required String userId,
    required String groupId,
  }) async {
    await _client
        .from('users')
        .update({'default_group_id': groupId})
        .eq('id', userId);
  }
}
```

- [ ] **Step 4: Run the Supabase service tests**

Run:

```powershell
flutter test test/services/supabase_service_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add lib/services/supabase_service.dart test/services/supabase_service_test.dart
git commit -m "feat: persist groups through Supabase service"
```

---

### Task 3: Add GroupStore State and Rollback/Error Handling

**Files:**
- Create: `lib/services/group_store.dart`
- Modify: `test/services/group_store_test.dart`

- [ ] **Step 1: Add GroupStore behavior tests**

Append to `test/services/group_store_test.dart`:

```dart
import 'package:buylog/services/group_store.dart';
import 'package:buylog/services/supabase_service.dart';

class _SuccessfulGroupGateway implements GroupDatabaseGateway {
  Map<String, dynamic>? storedGroup;

  @override
  Future<Map<String, dynamic>?> loadDefaultGroup(String userId) async {
    return storedGroup;
  }

  @override
  Future<Map<String, dynamic>> insertGroup(Map<String, dynamic> values) async {
    storedGroup = {
      'id': 'group-1',
      'name': values['name'],
      'invite_code': values['invite_code'],
      'created_by': values['created_by'],
      'created_at': '2026-05-26T10:00:00.000Z',
      'group_members': [
        {
          'id': 'member-1',
          'user_id': SupabaseService.currentUserId,
          'role': 'owner',
          'joined_at': '2026-05-26T10:00:00.000Z',
          'users': {'display_name': '사용자', 'email': null},
        },
      ],
    };
    return storedGroup!;
  }

  @override
  Future<void> insertGroupMember(Map<String, dynamic> values) async {}

  @override
  Future<void> updateDefaultGroup({
    required String userId,
    required String groupId,
  }) async {}
}

class _FailingGroupGateway extends _SuccessfulGroupGateway {
  @override
  Future<Map<String, dynamic>> insertGroup(Map<String, dynamic> values) {
    throw StateError('network failed');
  }
}

group('GroupStore', () {
  setUp(() {
    GroupStore.instance.resetForTesting();
  });

  tearDown(() {
    SupabaseService.debugGroupDatabaseGateway = null;
    GroupStore.instance.resetForTesting();
  });

  test('loads an empty state when the user has no default group', () async {
    SupabaseService.debugGroupDatabaseGateway = _SuccessfulGroupGateway();

    await GroupStore.instance.initialize();

    expect(GroupStore.instance.value.group, isNull);
    expect(GroupStore.instance.value.isLoading, isFalse);
    expect(GroupStore.instance.value.errorMessage, isNull);
  });

  test('creates a group and exposes it through state', () async {
    SupabaseService.debugGroupDatabaseGateway = _SuccessfulGroupGateway();

    await GroupStore.instance.createGroup('우리 가족');

    expect(GroupStore.instance.value.group?.name, '우리 가족');
    expect(GroupStore.instance.value.group?.members.single.displayName, '사용자');
    expect(GroupStore.instance.value.isSaving, isFalse);
  });

  test('restores previous state when group creation fails', () async {
    final previous = BuylogGroup(
      id: 'previous',
      name: '기존 그룹',
      inviteCode: 'BUY-OLD123',
      createdBy: 'user-1',
      createdAt: DateTime(2026, 5, 1),
      members: const [],
    );
    GroupStore.instance.value = GroupState(group: previous);
    SupabaseService.debugGroupDatabaseGateway = _FailingGroupGateway();

    await expectLater(
      GroupStore.instance.createGroup('새 그룹'),
      throwsA(isA<StateError>()),
    );

    expect(GroupStore.instance.value.group?.id, 'previous');
    expect(GroupStore.instance.value.errorMessage, contains('그룹을 만들지 못했습니다'));
  });
});
```

- [ ] **Step 2: Run the focused test and confirm it fails**

Run:

```powershell
flutter test test/services/group_store_test.dart
```

Expected: FAIL because `GroupStore` and `GroupState` do not exist.

- [ ] **Step 3: Implement GroupStore**

Create `lib/services/group_store.dart`:

```dart
import 'package:flutter/foundation.dart';

import '../models/group.dart';
import 'supabase_service.dart';

class GroupState {
  const GroupState({
    this.group,
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
  });

  final BuylogGroup? group;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  GroupState copyWith({
    BuylogGroup? group,
    bool? clearGroup,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) {
    return GroupState(
      group: clearGroup == true ? null : (group ?? this.group),
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class GroupStore extends ValueNotifier<GroupState> {
  static final GroupStore instance = GroupStore._();

  GroupStore._() : super(const GroupState());

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    value = value.copyWith(isLoading: true, clearError: true);

    try {
      final group = await SupabaseService.loadDefaultGroup();
      value = GroupState(group: group);
    } catch (error) {
      value = const GroupState(errorMessage: '그룹 정보를 불러오지 못했습니다.');
      rethrow;
    }
  }

  Future<void> createGroup(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Group name is required.');
    }

    final previous = value;
    value = value.copyWith(isSaving: true, clearError: true);

    try {
      final group = await SupabaseService.createGroup(name: trimmed);
      value = GroupState(group: group);
    } catch (error) {
      value = previous.copyWith(
        isSaving: false,
        errorMessage: '그룹을 만들지 못했습니다. 잠시 후 다시 시도해 주세요.',
      );
      rethrow;
    }
  }

  @visibleForTesting
  void resetForTesting() {
    _initialized = false;
    value = const GroupState();
  }
}
```

- [ ] **Step 4: Run GroupStore tests**

Run:

```powershell
flutter test test/services/group_store_test.dart
```

Expected: PASS.

- [ ] **Step 5: Initialize GroupStore at app startup**

Modify `lib/main.dart` after `ItemStore.instance.initialize()`:

```dart
  await GroupStore.instance.initialize();
```

Add import:

```dart
import 'services/group_store.dart';
```

- [ ] **Step 6: Run app render smoke test**

Run:

```powershell
flutter test test/widget_test.dart
```

Expected: PASS. If this test starts touching live Supabase initialization too early, keep the `GroupStore.initialize()` call but add test gateway setup in `test/widget_test.dart` instead of bypassing app initialization in production code.

- [ ] **Step 7: Commit**

```powershell
git add lib/services/group_store.dart lib/main.dart test/services/group_store_test.dart test/widget_test.dart
git commit -m "feat: add group state store"
```

---

### Task 4: Replace GroupScreen Sample UI With Real Creation Flow

**Files:**
- Modify: `lib/screens/group_screen.dart`
- Create: `test/screens/group_screen_test.dart`

- [ ] **Step 1: Write UI tests for empty state and creation**

Create `test/screens/group_screen_test.dart`:

```dart
import 'package:buylog/models/group.dart';
import 'package:buylog/screens/group_screen.dart';
import 'package:buylog/services/group_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap() {
  return const MaterialApp(home: Scaffold(body: GroupScreen()));
}

void main() {
  setUp(() {
    GroupStore.instance.resetForTesting();
  });

  tearDown(() {
    GroupStore.instance.resetForTesting();
  });

  testWidgets('shows group creation empty state when no group exists', (tester) async {
    GroupStore.instance.value = const GroupState();

    await tester.pumpWidget(_wrap());

    expect(find.text('그룹'), findsOneWidget);
    expect(find.text('아직 연결된 그룹이 없습니다.'), findsOneWidget);
    expect(find.text('그룹 만들기'), findsOneWidget);
  });

  testWidgets('validates group name before submitting', (tester) async {
    GroupStore.instance.value = const GroupState();

    await tester.pumpWidget(_wrap());
    await tester.tap(find.text('그룹 만들기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('만들기'));
    await tester.pump();

    expect(find.text('그룹 이름을 입력해 주세요.'), findsOneWidget);
  });

  testWidgets('renders the saved group card', (tester) async {
    GroupStore.instance.value = GroupState(
      group: BuylogGroup(
        id: 'group-1',
        name: '우리 가족',
        inviteCode: 'BUY-ABC123',
        createdBy: 'user-1',
        createdAt: DateTime(2026, 5, 26),
        members: [
          BuylogGroupMember(
            id: 'member-1',
            userId: 'user-1',
            displayName: '사용자',
            role: GroupRole.owner,
            joinedAt: DateTime(2026, 5, 26),
          ),
        ],
      ),
    );

    await tester.pumpWidget(_wrap());

    expect(find.text('우리 가족'), findsOneWidget);
    expect(find.text('초대 코드: BUY-ABC123'), findsOneWidget);
    expect(find.text('사용자'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the UI tests and confirm they fail**

Run:

```powershell
flutter test test/screens/group_screen_test.dart
```

Expected: FAIL because `GroupScreen` still renders sample data and has no creation dialog.

- [ ] **Step 3: Replace `GroupScreen` with GroupStore-backed UI**

Modify `lib/screens/group_screen.dart` to:

```dart
import 'package:flutter/material.dart';

import '../models/group.dart';
import '../services/group_store.dart';
import '../theme/app_theme.dart';

class GroupScreen extends StatelessWidget {
  const GroupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ValueListenableBuilder<GroupState>(
        valueListenable: GroupStore.instance,
        builder: (context, state, _) {
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Text('그룹', style: Theme.of(context).textTheme.headlineMedium),
                ),
              ),
              if (state.isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (state.group == null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyGroupState(
                    isSaving: state.isSaving,
                    errorMessage: state.errorMessage,
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: _GroupCard(group: state.group!),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyGroupState extends StatelessWidget {
  const _EmptyGroupState({
    required this.isSaving,
    required this.errorMessage,
  });

  final bool isSaving;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.group_add_outlined,
                color: AppColors.primary,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '아직 연결된 그룹이 없습니다.',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '가족이나 함께 관리할 사람들과 같은 소모품 목록을 공유할 수 있습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.danger),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: isSaving ? null : () => _showCreateGroupDialog(context),
              icon: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: const Text('그룹 만들기'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});

  final BuylogGroup group;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.home_outlined, size: 22, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  group.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final member in group.members) _MemberAvatar(member: member),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.link, size: 18, color: AppColors.textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '초대 코드: ${group.inviteCode}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '초대 코드 복사',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('초대 코드가 복사되었습니다.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({required this.member});

  final BuylogGroupMember member;

  @override
  Widget build(BuildContext context) {
    final initial = member.displayName.characters.firstOrNull ?? '?';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.primary,
          child: Text(
            initial,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          member.displayName,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

Future<void> _showCreateGroupDialog(BuildContext context) async {
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('그룹 만들기'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: '그룹 이름'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '그룹 이름을 입력해 주세요.';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              await GroupStore.instance.createGroup(controller.text);
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            child: const Text('만들기'),
          ),
        ],
      );
    },
  );
}
```

- [ ] **Step 4: Run UI tests**

Run:

```powershell
flutter test test/screens/group_screen_test.dart
```

Expected: PASS.

- [ ] **Step 5: Run broader widget tests**

Run:

```powershell
flutter test test/widget_test.dart test/screens/group_screen_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add lib/screens/group_screen.dart test/screens/group_screen_test.dart
git commit -m "feat: add group creation UI"
```

---

### Task 5: Add Supabase RLS Policies for Groups

**Files:**
- Create: `supabase/migrations/<generated>_add_group_rls_policies.sql`

- [ ] **Step 1: Check Supabase CLI help before creating the migration**

Run:

```powershell
supabase --help
supabase migration --help
supabase migration new --help
```

Expected: CLI help prints available commands and confirms `migration new` syntax.

- [ ] **Step 2: Generate the migration file**

Run:

```powershell
supabase migration new add_group_rls_policies
```

Expected: A new file appears under `supabase/migrations/` with a timestamped name ending in `_add_group_rls_policies.sql`.

- [ ] **Step 3: Add RLS SQL**

Paste this SQL into the generated migration file:

```sql
begin;

alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.users enable row level security;

drop policy if exists "Group members can view their groups" on public.groups;
drop policy if exists "Users can create groups" on public.groups;
drop policy if exists "Group owners can update their groups" on public.groups;

create policy "Group members can view their groups"
on public.groups
for select
to authenticated
using (
  exists (
    select 1
    from public.group_members gm
    where gm.group_id = groups.id
      and gm.user_id = (select auth.uid())
  )
);

create policy "Users can create groups"
on public.groups
for insert
to authenticated
with check (
  created_by = (select auth.uid())
);

create policy "Group owners can update their groups"
on public.groups
for update
to authenticated
using (
  exists (
    select 1
    from public.group_members gm
    where gm.group_id = groups.id
      and gm.user_id = (select auth.uid())
      and gm.role = 'owner'
  )
)
with check (
  exists (
    select 1
    from public.group_members gm
    where gm.group_id = groups.id
      and gm.user_id = (select auth.uid())
      and gm.role = 'owner'
  )
);

drop policy if exists "Users can view memberships for their groups" on public.group_members;
drop policy if exists "Users can create their owner membership" on public.group_members;
drop policy if exists "Group owners can add members" on public.group_members;

create policy "Users can view memberships for their groups"
on public.group_members
for select
to authenticated
using (
  user_id = (select auth.uid())
  or exists (
    select 1
    from public.group_members own_membership
    where own_membership.group_id = group_members.group_id
      and own_membership.user_id = (select auth.uid())
  )
);

create policy "Users can create their owner membership"
on public.group_members
for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and role = 'owner'
  and exists (
    select 1
    from public.groups g
    where g.id = group_members.group_id
      and g.created_by = (select auth.uid())
  )
);

create policy "Group owners can add members"
on public.group_members
for insert
to authenticated
with check (
  exists (
    select 1
    from public.group_members owner_membership
    where owner_membership.group_id = group_members.group_id
      and owner_membership.user_id = (select auth.uid())
      and owner_membership.role = 'owner'
  )
);

drop policy if exists "Users can view their own profile row" on public.users;
drop policy if exists "Users can update their own default group" on public.users;

create policy "Users can view their own profile row"
on public.users
for select
to authenticated
using (
  id = (select auth.uid())
);

create policy "Users can update their own default group"
on public.users
for update
to authenticated
using (
  id = (select auth.uid())
)
with check (
  id = (select auth.uid())
  and (
    default_group_id is null
    or exists (
      select 1
      from public.group_members gm
      where gm.group_id = users.default_group_id
        and gm.user_id = (select auth.uid())
    )
  )
);

commit;
```

Important execution note: the current app uses a hard-coded dev UUID, not real Supabase Auth. If local/remote data is still accessed through anon context, this authenticated-only RLS will block writes until real auth or a development-specific policy is introduced. Do not add service-role keys to Flutter. For the current app, either execute with an authenticated session whose `auth.uid()` matches `SupabaseService.currentUserId`, or explicitly document a temporary dev-only policy before merging.

- [ ] **Step 4: Apply locally and run advisors**

Run:

```powershell
supabase db reset
supabase db advisors
supabase migration list --local
```

Expected:
- `db reset` applies all migrations.
- `db advisors` reports no critical RLS/security warnings for the new policies.
- `migration list --local` shows the new migration as applied locally.

- [ ] **Step 5: Commit**

```powershell
git add supabase/migrations/*_add_group_rls_policies.sql
git commit -m "feat: add group RLS policies"
```

---

### Task 6: End-to-End Verification and PR Prep

**Files:**
- Verify all changed files.

- [ ] **Step 1: Run formatter**

Run:

```powershell
dart format lib/models/group.dart lib/services/group_store.dart lib/services/supabase_service.dart lib/screens/group_screen.dart test/services/group_store_test.dart test/services/supabase_service_test.dart test/screens/group_screen_test.dart test/widget_test.dart
```

Expected: command exits `0`; files may be reformatted.

- [ ] **Step 2: Run analyzer with repo-aligned flags**

Run:

```powershell
flutter analyze --no-fatal-infos
```

Expected: exits `0`. If it reports warnings from the new files, fix them before continuing.

- [ ] **Step 3: Run all tests**

Run:

```powershell
flutter test
```

Expected: all tests pass.

- [ ] **Step 4: Check Supabase migration status**

Run:

```powershell
supabase migration list --local
```

Expected: the new `add_group_rls_policies` migration is listed after the existing 2026-05-06 migrations.

- [ ] **Step 5: Inspect the final diff**

Run:

```powershell
git status --short
git diff --stat
git diff -- lib/models/group.dart lib/services/group_store.dart lib/services/supabase_service.dart lib/screens/group_screen.dart
```

Expected:
- Only intended feature files and the generated migration are modified.
- Existing unrelated local files such as `.gitignore`, `.claude/`, `.mcp.json`, or unrelated docs stay out of staging unless the user explicitly requests them.

- [ ] **Step 6: Final commit or PR branch**

If previous tasks were not committed one by one, create one feature commit:

```powershell
git add lib/models/group.dart lib/services/group_store.dart lib/services/supabase_service.dart lib/screens/group_screen.dart test/services/group_store_test.dart test/services/supabase_service_test.dart test/screens/group_screen_test.dart test/widget_test.dart supabase/migrations/*_add_group_rls_policies.sql
git commit -m "feat: add group creation flow"
```

For a develop-targeted PR:

```powershell
git push -u origin <feature-branch>
gh pr create --base develop --head <feature-branch> --title "그룹 생성 UI 및 Supabase 연동" --body "## 변경 사항
- 그룹 생성 UI 추가
- Supabase groups/group_members/users.default_group_id 연동
- 그룹 상태 Store 및 테스트 추가
- 그룹 RLS 정책 migration 추가

## 테스트
- dart format
- flutter analyze --no-fatal-infos
- flutter test
- supabase migration list --local"
```

---

## Self-Review Notes

- Spec coverage: The plan covers group creation UI, Supabase `groups` insert, owner membership creation, default group linkage, tests, RLS, and verification.
- Placeholder scan: No task uses `TBD`, generic "handle errors", or unspecified tests; each implementation task includes concrete code or commands.
- Type consistency: `BuylogGroup`, `BuylogGroupMember`, `GroupRole`, `GroupState`, `GroupStore`, and `GroupDatabaseGateway` are defined before later tasks reference them.
- Risk to resolve during implementation: current app identity is a hard-coded dev UUID while strict RLS expects authenticated `auth.uid()`. The implementation must not expose service-role credentials in Flutter; align auth/session behavior or explicitly document a dev-only policy before merge.

## References

- Supabase RLS docs: https://supabase.com/docs/guides/database/postgres/row-level-security
- Supabase Flutter insert docs: https://supabase.com/docs/reference/dart/insert
- Supabase Flutter select docs: https://supabase.com/docs/reference/dart/select
