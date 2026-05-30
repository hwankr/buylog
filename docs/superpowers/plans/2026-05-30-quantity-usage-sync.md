# Quantity Usage Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 구매 등록 시 수량을 입력하고, 사용자가 상세 화면에서 직접 남은 수량을 차감하거나 맞춰서 이후 교체 주기 계산에 활용할 수 있는 이력을 남긴다.

**Architecture:** `purchases.quantity`를 구매 단위의 초기 수량으로 사용하고, 수동 사용은 새 `product_usage_events` 테이블에 불변 이벤트로 저장한다. 최신 남은 수량은 기존 `product_inventory_snapshots`를 수동 출처로 upsert해 목록과 상세 화면이 기존 재고 표시 흐름을 그대로 사용하게 한다.

**Tech Stack:** Flutter, Dart, Supabase Postgres, Supabase RPC, `flutter_test`

---

## Branch

- Current implementation branch: `quantity-usage-sync`
- Base branch at plan creation: `develop`
- Existing untracked files under `hardware/**` are unrelated and must not be staged with this feature.

## Decisions

- 등록 화면의 구매 수량 기본값은 `1`이다.
- 수량은 1 이상의 정수만 허용한다.
- 수동 `1개 사용`은 남은 수량을 0 아래로 내릴 수 없다.
- `수량 맞추기`는 실제 재고가 앱과 다를 때 남은 수량을 정확한 값으로 덮어쓴다.
- 교체 주기 자동 재계산은 이번 범위에 넣지 않고, 이후 계산이 가능하도록 `product_usage_events.occurred_at`, `quantity_delta`, `remaining_quantity_after`를 저장한다.

## File Map

- Modify `lib/models/item.dart`
  - `PurchaseRecord.quantity` 추가
  - `ConsumableItem.copyWith`, `ConsumableItem.totalPurchasedQuantity`, 수량 라벨 보강
- Create `lib/models/manual_quantity_snapshot.dart`
  - Supabase RPC 결과를 Dart 모델로 변환
- Create `test/models/item_quantity_test.dart`
  - 구매 수량 기본값, Supabase 매핑, 합계 계산 검증
- Create `supabase/migrations/20260530090000_add_manual_quantity_sync.sql`
  - `purchases.quantity` 제약 보강
  - `product_usage_events` 테이블과 수동 수량 RPC 2개 추가
- Modify `lib/services/supabase_service.dart`
  - 구매 이력 `quantity` 로드/저장
  - 기존 구매 이력 update 지원
  - 수동 수량 set/decrement RPC gateway 추가
- Modify `test/services/supabase_service_test.dart`
  - 구매 수량 저장, 기존 구매 업데이트, RPC 매핑 테스트 추가
- Modify `lib/services/item_store.dart`
  - 수동 수량 변경을 optimistic update와 rollback으로 감싼다
- Modify `test/services/item_store_test.dart`
  - 수동 사용 성공, 초과 차감 방지, 실패 rollback 테스트 추가
- Modify `lib/screens/add_item_screen.dart`
  - 구매 이력 항목마다 수량 입력 필드 추가
  - 신규 등록과 동일 제품 병합에서 남은 수량 초기화/증가
- Modify `test/screens/add_item_screen_test.dart`
  - 기본 수량 1, 입력 수량 저장 검증
- Modify `lib/screens/item_detail_screen.dart`
  - 현재 수량 카드에 `1개 사용`, `수량 맞추기` 액션 추가
- Modify `test/screens/item_detail_screen_test.dart`
  - 버튼 표시, 차감 성공, 0개 비활성, 수량 맞추기 검증

---

### Task 1: Item Quantity Model

**Files:**
- Modify: `lib/models/item.dart`
- Create: `lib/models/manual_quantity_snapshot.dart`
- Test: `test/models/item_quantity_test.dart`

- [ ] **Step 1: Write the failing model tests**

Create `test/models/item_quantity_test.dart`:

```dart
import 'package:buylog/models/item.dart';
import 'package:buylog/models/manual_quantity_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PurchaseRecord quantity', () {
    test('defaults to one item when quantity is omitted', () {
      final record = PurchaseRecord(
        date: DateTime(2026, 5, 30),
        price: 12000,
        store: 'Market',
      );

      expect(record.quantity, 1);
    });

    test('maps purchase quantity from Supabase rows', () {
      final item = ConsumableItem.fromSupabase(
        data: <String, dynamic>{
          'id': 'item-1',
          'name': '칫솔',
          'brand': 'Brand',
          'replacement_cycle_days': 30,
        },
        categoryName: '욕실/위생',
        purchases: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'purchase-1',
            'purchase_date': '2026-05-30',
            'price': 10000,
            'store_name': 'Market',
            'quantity': 10,
          },
        ],
      );

      expect(item.purchaseHistory.single.quantity, 10);
      expect(item.totalPurchasedQuantity, 10);
    });

    test('falls back to quantity one for older purchase rows', () {
      final item = ConsumableItem.fromSupabase(
        data: <String, dynamic>{
          'id': 'item-1',
          'name': '샴푸',
          'brand': 'Brand',
          'replacement_cycle_days': 30,
        },
        categoryName: '헤어/바디',
        purchases: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'purchase-1',
            'purchase_date': '2026-05-30',
            'price': 9000,
            'store_name': 'Market',
          },
        ],
      );

      expect(item.purchaseHistory.single.quantity, 1);
      expect(item.totalPurchasedQuantity, 1);
    });
  });

  group('ManualQuantitySnapshot', () {
    test('maps RPC response fields', () {
      final snapshot = ManualQuantitySnapshot.fromSupabase(
        <String, dynamic>{
          'remaining_quantity': 7,
          'confidence': 1.0,
          'source_detected_name': 'manual',
          'observed_at': '2026-05-30T12:00:00.000Z',
        },
      );

      expect(snapshot.remainingQuantity, 7);
      expect(snapshot.confidence, 1.0);
      expect(snapshot.sourceName, 'manual');
      expect(snapshot.observedAt, DateTime.parse('2026-05-30T12:00:00.000Z'));
    });
  });
}
```

- [ ] **Step 2: Run the model tests and verify failure**

Run:

```bash
flutter test test/models/item_quantity_test.dart
```

Expected: fail with missing `quantity`, `totalPurchasedQuantity`, or `ManualQuantitySnapshot`.

- [ ] **Step 3: Add model fields and helpers**

In `lib/models/item.dart`, add `totalPurchasedQuantity`, `copyWith`, and quantity mapping:

```dart
  int get totalPurchasedQuantity {
    return purchaseHistory.fold<int>(
      0,
      (total, record) => total + record.quantity,
    );
  }

  ConsumableItem copyWith({
    String? id,
    String? name,
    String? brand,
    String? category,
    IconData? icon,
    int? daysRemaining,
    int? cycleDays,
    double? progress,
    int? aiPredictedDays,
    double? aiConfidence,
    List<PurchaseRecord>? purchaseHistory,
    String? imageUrl,
    String? groupId,
    String? registeredBy,
    String? registeredByDisplayName,
    String? registeredByEmail,
    int? remainingQuantity,
    DateTime? inventoryObservedAt,
    double? inventoryConfidence,
    String? inventorySourceName,
    bool? visionTrackingEnabled,
    int? visionMeasureIntervalMinutes,
    DateTime? visionLastMeasuredAt,
  }) {
    return ConsumableItem(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      category: category ?? this.category,
      icon: icon ?? this.icon,
      daysRemaining: daysRemaining ?? this.daysRemaining,
      cycleDays: cycleDays ?? this.cycleDays,
      progress: progress ?? this.progress,
      aiPredictedDays: aiPredictedDays ?? this.aiPredictedDays,
      aiConfidence: aiConfidence ?? this.aiConfidence,
      purchaseHistory: purchaseHistory ?? this.purchaseHistory,
      imageUrl: imageUrl ?? this.imageUrl,
      groupId: groupId ?? this.groupId,
      registeredBy: registeredBy ?? this.registeredBy,
      registeredByDisplayName:
          registeredByDisplayName ?? this.registeredByDisplayName,
      registeredByEmail: registeredByEmail ?? this.registeredByEmail,
      remainingQuantity: remainingQuantity ?? this.remainingQuantity,
      inventoryObservedAt: inventoryObservedAt ?? this.inventoryObservedAt,
      inventoryConfidence: inventoryConfidence ?? this.inventoryConfidence,
      inventorySourceName: inventorySourceName ?? this.inventorySourceName,
      visionTrackingEnabled:
          visionTrackingEnabled ?? this.visionTrackingEnabled,
      visionMeasureIntervalMinutes:
          visionMeasureIntervalMinutes ?? this.visionMeasureIntervalMinutes,
      visionLastMeasuredAt: visionLastMeasuredAt ?? this.visionLastMeasuredAt,
    );
  }
```

Update the `PurchaseRecord` mapping inside `ConsumableItem.fromSupabase`:

```dart
            (p) => PurchaseRecord(
              id: p['id'] as String?,
              date: DateTime.parse(p['purchase_date']),
              price: (p['price'] as int?) ?? 0,
              store: (p['store_name'] as String?) ?? '',
              quantity: ((p['quantity'] as num?)?.toInt() ?? 1).clamp(1, 9999),
            ),
```

Update `PurchaseRecord`:

```dart
class PurchaseRecord {
  final String? id;
  final DateTime date;
  final int price;
  final String store;
  final int quantity;

  const PurchaseRecord({
    this.id,
    required this.date,
    required this.price,
    required this.store,
    this.quantity = 1,
  }) : assert(quantity > 0);
}
```

Create `lib/models/manual_quantity_snapshot.dart`:

```dart
class ManualQuantitySnapshot {
  const ManualQuantitySnapshot({
    required this.remainingQuantity,
    required this.confidence,
    required this.sourceName,
    required this.observedAt,
  });

  final int remainingQuantity;
  final double confidence;
  final String sourceName;
  final DateTime observedAt;

  factory ManualQuantitySnapshot.fromSupabase(Map<String, dynamic> row) {
    final observedAtRaw = row['observed_at'];
    return ManualQuantitySnapshot(
      remainingQuantity: (row['remaining_quantity'] as num).toInt(),
      confidence: (row['confidence'] as num).toDouble(),
      sourceName: row['source_detected_name'] as String? ?? 'manual',
      observedAt: observedAtRaw is DateTime
          ? observedAtRaw
          : DateTime.parse(observedAtRaw as String),
    );
  }
}
```

- [ ] **Step 4: Run model tests and verify pass**

Run:

```bash
flutter test test/models/item_quantity_test.dart
```

Expected: all tests pass.

- [ ] **Step 5: Commit model changes**

```bash
git add lib/models/item.dart lib/models/manual_quantity_snapshot.dart test/models/item_quantity_test.dart
git commit -m "feat: model purchase quantities"
```

---

### Task 2: Supabase Quantity Persistence

**Files:**
- Create: `supabase/migrations/20260530090000_add_manual_quantity_sync.sql`
- Modify: `lib/services/supabase_service.dart`
- Test: `test/services/supabase_service_test.dart`

- [ ] **Step 1: Write failing Supabase service tests**

Add these tests inside the `SupabaseService.saveItem scoped ownership` group in `test/services/supabase_service_test.dart`:

```dart
    test('inserts purchase quantity from PurchaseRecord', () async {
      final gateway = _RecordingItemDatabaseGateway();
      SupabaseService.debugItemDatabaseGateway = gateway;

      await SupabaseService.saveItem(
        ConsumableItem(
          id: 'item-quantity',
          name: '칫솔',
          brand: 'Brand',
          category: '욕실/위생',
          icon: ConsumableItem.iconForCategory('욕실/위생'),
          daysRemaining: 30,
          cycleDays: 30,
          progress: 0,
          remainingQuantity: 10,
          purchaseHistory: <PurchaseRecord>[
            PurchaseRecord(
              date: DateTime(2026, 5, 30),
              price: 12000,
              store: 'Market',
              quantity: 10,
            ),
          ],
        ),
      );

      expect(gateway.insertedPurchasePayloads.single['quantity'], 10);
      expect(gateway.manualQuantityProductItemId, 'item-quantity');
      expect(gateway.manualQuantityRemainingQuantity, 10);
    });

    test('updates existing purchase quantity when purchase id is present', () async {
      final gateway = _RecordingItemDatabaseGateway();
      SupabaseService.debugItemDatabaseGateway = gateway;

      await SupabaseService.saveItem(
        ConsumableItem(
          id: 'item-existing',
          name: '필터',
          brand: 'Brand',
          category: '가전/필터',
          icon: ConsumableItem.iconForCategory('가전/필터'),
          daysRemaining: 30,
          cycleDays: 30,
          progress: 0,
          purchaseHistory: <PurchaseRecord>[
            PurchaseRecord(
              id: 'purchase-existing',
              date: DateTime(2026, 5, 30),
              price: 45000,
              store: 'Market',
              quantity: 3,
            ),
          ],
        ),
      );

      expect(gateway.insertedPurchasePayloads, isEmpty);
      expect(gateway.updatedPurchaseIds, <String>['purchase-existing']);
      expect(gateway.updatedPurchasePayloads.single['quantity'], 3);
    });
```

Add this test group after the save group:

```dart
  group('SupabaseService manual quantity sync', () {
    tearDown(() {
      SupabaseService.debugItemDatabaseGateway = null;
    });

    test('sets manual quantity through the item gateway', () async {
      final gateway = _RecordingItemDatabaseGateway();
      SupabaseService.debugItemDatabaseGateway = gateway;

      final snapshot = await SupabaseService.setManualQuantity(
        productItemId: 'item-1',
        remainingQuantity: 8,
        observedAt: DateTime.parse('2026-05-30T12:00:00.000Z'),
      );

      expect(gateway.manualQuantityProductItemId, 'item-1');
      expect(gateway.manualQuantityRemainingQuantity, 8);
      expect(snapshot.remainingQuantity, 8);
      expect(snapshot.sourceName, 'manual');
    });

    test('records manual usage through the item gateway', () async {
      final gateway = _RecordingItemDatabaseGateway();
      SupabaseService.debugItemDatabaseGateway = gateway;

      final snapshot = await SupabaseService.recordManualUsage(
        productItemId: 'item-1',
        usedQuantity: 1,
        usedAt: DateTime.parse('2026-05-30T12:00:00.000Z'),
      );

      expect(gateway.manualUsageProductItemId, 'item-1');
      expect(gateway.manualUsageUsedQuantity, 1);
      expect(snapshot.remainingQuantity, 4);
      expect(snapshot.sourceName, 'manual');
    });
  });
```

Extend `_RecordingItemDatabaseGateway` in the same test file:

```dart
  final List<String> updatedPurchaseIds = [];
  final List<Map<String, dynamic>> updatedPurchasePayloads = [];
  String? manualQuantityProductItemId;
  int? manualQuantityRemainingQuantity;
  DateTime? manualQuantityObservedAt;
  String? manualUsageProductItemId;
  int? manualUsageUsedQuantity;
  DateTime? manualUsageUsedAt;
```

Add methods to `_RecordingItemDatabaseGateway`:

```dart
  @override
  Future<void> updatePurchase({
    required String purchaseId,
    required Map<String, dynamic> payload,
  }) async {
    updatedPurchaseIds.add(purchaseId);
    updatedPurchasePayloads.add(Map<String, dynamic>.from(payload));
  }

  @override
  Future<ManualQuantitySnapshot> setManualQuantity({
    required String productItemId,
    required int remainingQuantity,
    required DateTime observedAt,
  }) async {
    manualQuantityProductItemId = productItemId;
    manualQuantityRemainingQuantity = remainingQuantity;
    manualQuantityObservedAt = observedAt;
    return ManualQuantitySnapshot(
      remainingQuantity: remainingQuantity,
      confidence: 1,
      sourceName: 'manual',
      observedAt: observedAt,
    );
  }

  @override
  Future<ManualQuantitySnapshot> recordManualUsage({
    required String productItemId,
    required int usedQuantity,
    required DateTime usedAt,
  }) async {
    manualUsageProductItemId = productItemId;
    manualUsageUsedQuantity = usedQuantity;
    manualUsageUsedAt = usedAt;
    return ManualQuantitySnapshot(
      remainingQuantity: 4,
      confidence: 1,
      sourceName: 'manual',
      observedAt: usedAt,
    );
  }
```

- [ ] **Step 2: Run Supabase service tests and verify failure**

Run:

```bash
flutter test test/services/supabase_service_test.dart
```

Expected: fail because the gateway interface and quantity persistence methods do not exist yet.

- [ ] **Step 3: Add the SQL migration**

Create `supabase/migrations/20260530090000_add_manual_quantity_sync.sql`:

```sql
begin;

update public.purchases
set quantity = 1
where quantity is null or quantity < 1;

alter table public.purchases
  alter column quantity set default 1,
  alter column quantity set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'purchases_quantity_positive'
      and conrelid = 'public.purchases'::regclass
  ) then
    alter table public.purchases
      add constraint purchases_quantity_positive check (quantity > 0);
  end if;
end $$;

create table if not exists public.product_usage_events (
  id uuid primary key default gen_random_uuid(),
  product_item_id uuid not null references public.product_items(id) on delete cascade,
  recorded_by uuid references public.users(id) on delete set null,
  event_type text not null check (event_type in ('manual_set', 'consume')),
  quantity_delta int not null,
  remaining_quantity_after int not null check (remaining_quantity_after >= 0),
  occurred_at timestamptz not null default now(),
  note text,
  created_at timestamptz not null default now(),
  constraint product_usage_events_delta_check check (
    (event_type = 'manual_set') or (event_type = 'consume' and quantity_delta < 0)
  )
);

comment on table public.product_usage_events is
  'Manual quantity changes that can be used later for replacement-cycle analysis.';
comment on column public.product_usage_events.quantity_delta is
  'Change in remaining quantity. consume events are negative.';
comment on column public.product_usage_events.remaining_quantity_after is
  'Remaining quantity after this event is applied.';

create index if not exists product_usage_events_product_occurred_at_idx
on public.product_usage_events (product_item_id, occurred_at desc);

grant select on table public.product_usage_events to anon, authenticated;

alter table public.product_usage_events enable row level security;

drop policy if exists "Users can view accessible product usage events"
on public.product_usage_events;

create policy "Users can view accessible product usage events"
on public.product_usage_events
for select
to anon, authenticated
using (
  private.can_access_product_item(
    product_item_id,
    private.current_buylog_user_id()
  )
);

create or replace function public.set_product_manual_quantity(
  target_product_item_id uuid,
  target_remaining_quantity int,
  target_observed_at timestamptz default now()
)
returns table (
  remaining_quantity int,
  confidence numeric,
  source_detected_name text,
  observed_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := private.current_buylog_user_id();
  previous_remaining int;
  delta int;
begin
  if target_remaining_quantity < 0 then
    raise exception 'remaining quantity must be zero or greater'
      using errcode = '22003';
  end if;

  if not private.can_access_product_item(target_product_item_id, current_user_id) then
    raise exception 'product item is not accessible'
      using errcode = '42501';
  end if;

  select pis.remaining_quantity
  into previous_remaining
  from public.product_inventory_snapshots as pis
  where pis.product_item_id = target_product_item_id
  for update;

  if previous_remaining is null then
    select coalesce(sum(p.quantity), 0)::int
    into previous_remaining
    from public.purchases as p
    where p.product_item_id = target_product_item_id;
  end if;

  delta := target_remaining_quantity - previous_remaining;

  insert into public.product_usage_events (
    product_item_id,
    recorded_by,
    event_type,
    quantity_delta,
    remaining_quantity_after,
    occurred_at,
    note
  )
  values (
    target_product_item_id,
    current_user_id,
    'manual_set',
    delta,
    target_remaining_quantity,
    target_observed_at,
    'manual quantity set'
  );

  insert into public.product_inventory_snapshots (
    product_item_id,
    remaining_quantity,
    confidence,
    source_detected_name,
    observed_at
  )
  values (
    target_product_item_id,
    target_remaining_quantity,
    1.000,
    'manual',
    target_observed_at
  )
  on conflict (product_item_id) do update
  set remaining_quantity = excluded.remaining_quantity,
      confidence = excluded.confidence,
      source_detected_name = excluded.source_detected_name,
      observed_at = excluded.observed_at,
      updated_at = now();

  return query
  select
    pis.remaining_quantity,
    pis.confidence,
    pis.source_detected_name,
    pis.observed_at
  from public.product_inventory_snapshots as pis
  where pis.product_item_id = target_product_item_id;
end;
$$;

create or replace function public.record_product_usage(
  target_product_item_id uuid,
  target_used_quantity int,
  target_used_at timestamptz default now()
)
returns table (
  remaining_quantity int,
  confidence numeric,
  source_detected_name text,
  observed_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := private.current_buylog_user_id();
  current_remaining int;
  next_remaining int;
begin
  if target_used_quantity < 1 then
    raise exception 'used quantity must be greater than zero'
      using errcode = '22003';
  end if;

  if not private.can_access_product_item(target_product_item_id, current_user_id) then
    raise exception 'product item is not accessible'
      using errcode = '42501';
  end if;

  select pis.remaining_quantity
  into current_remaining
  from public.product_inventory_snapshots as pis
  where pis.product_item_id = target_product_item_id
  for update;

  if current_remaining is null then
    select coalesce(sum(p.quantity), 0)::int
    into current_remaining
    from public.purchases as p
    where p.product_item_id = target_product_item_id;
  end if;

  if current_remaining < target_used_quantity then
    raise exception 'remaining quantity cannot go below zero'
      using errcode = '22003';
  end if;

  next_remaining := current_remaining - target_used_quantity;

  insert into public.product_usage_events (
    product_item_id,
    recorded_by,
    event_type,
    quantity_delta,
    remaining_quantity_after,
    occurred_at,
    note
  )
  values (
    target_product_item_id,
    current_user_id,
    'consume',
    -target_used_quantity,
    next_remaining,
    target_used_at,
    'manual usage'
  );

  insert into public.product_inventory_snapshots (
    product_item_id,
    remaining_quantity,
    confidence,
    source_detected_name,
    observed_at
  )
  values (
    target_product_item_id,
    next_remaining,
    1.000,
    'manual',
    target_used_at
  )
  on conflict (product_item_id) do update
  set remaining_quantity = excluded.remaining_quantity,
      confidence = excluded.confidence,
      source_detected_name = excluded.source_detected_name,
      observed_at = excluded.observed_at,
      updated_at = now();

  return query
  select
    pis.remaining_quantity,
    pis.confidence,
    pis.source_detected_name,
    pis.observed_at
  from public.product_inventory_snapshots as pis
  where pis.product_item_id = target_product_item_id;
end;
$$;

revoke all on function public.set_product_manual_quantity(uuid, int, timestamptz)
from public, anon, authenticated;
revoke all on function public.record_product_usage(uuid, int, timestamptz)
from public, anon, authenticated;

grant execute on function public.set_product_manual_quantity(uuid, int, timestamptz)
to anon, authenticated;
grant execute on function public.record_product_usage(uuid, int, timestamptz)
to anon, authenticated;

commit;
```

- [ ] **Step 4: Update `SupabaseService` and gateway interface**

Add the import near the top of `lib/services/supabase_service.dart`:

```dart
import '../models/manual_quantity_snapshot.dart';
```

Update `_itemProjection` so purchases include quantity:

```dart
          purchases ( id, purchase_date, price, store_name, quantity ),
```

Add static methods to `SupabaseService`:

```dart
  static Future<ManualQuantitySnapshot> setManualQuantity({
    required String productItemId,
    required int remainingQuantity,
    DateTime? observedAt,
  }) {
    if (remainingQuantity < 0) {
      throw ArgumentError.value(
        remainingQuantity,
        'remainingQuantity',
        'Remaining quantity must be zero or greater.',
      );
    }
    return _itemDatabaseGateway.setManualQuantity(
      productItemId: productItemId,
      remainingQuantity: remainingQuantity,
      observedAt: observedAt ?? DateTime.now(),
    );
  }

  static Future<ManualQuantitySnapshot> recordManualUsage({
    required String productItemId,
    required int usedQuantity,
    DateTime? usedAt,
  }) {
    if (usedQuantity < 1) {
      throw ArgumentError.value(
        usedQuantity,
        'usedQuantity',
        'Used quantity must be greater than zero.',
      );
    }
    return _itemDatabaseGateway.recordManualUsage(
      productItemId: productItemId,
      usedQuantity: usedQuantity,
      usedAt: usedAt ?? DateTime.now(),
    );
  }
```

Update purchase persistence inside `saveItem`:

```dart
      for (final record in item.purchaseHistory) {
        final payload = {
          'product_item_id': item.id,
          'purchased_by': uid,
          'purchase_date': record.date.toIso8601String().substring(0, 10),
          'price': record.price,
          'store_name': record.store,
          'quantity': record.quantity,
        };

        if (record.id == null) {
          await _itemDatabaseGateway.insertPurchase(payload);
        } else {
          await _itemDatabaseGateway.updatePurchase(
            purchaseId: record.id!,
            payload: payload,
          );
        }
      }

      final remainingQuantity = item.remainingQuantity;
      if (remainingQuantity != null) {
        await _itemDatabaseGateway.setManualQuantity(
          productItemId: item.id,
          remainingQuantity: remainingQuantity,
          observedAt: DateTime.now(),
        );
      }
```

Extend `ItemDatabaseGateway`:

```dart
  Future<void> updatePurchase({
    required String purchaseId,
    required Map<String, dynamic> payload,
  });

  Future<ManualQuantitySnapshot> setManualQuantity({
    required String productItemId,
    required int remainingQuantity,
    required DateTime observedAt,
  });

  Future<ManualQuantitySnapshot> recordManualUsage({
    required String productItemId,
    required int usedQuantity,
    required DateTime usedAt,
  });
```

Implement the methods in `SupabaseItemDatabaseGateway`:

```dart
  @override
  Future<void> updatePurchase({
    required String purchaseId,
    required Map<String, dynamic> payload,
  }) async {
    await _client.from('purchases').update(payload).eq('id', purchaseId);
  }

  @override
  Future<ManualQuantitySnapshot> setManualQuantity({
    required String productItemId,
    required int remainingQuantity,
    required DateTime observedAt,
  }) async {
    final row = await _client
        .rpc(
          'set_product_manual_quantity',
          params: {
            'target_product_item_id': productItemId,
            'target_remaining_quantity': remainingQuantity,
            'target_observed_at': observedAt.toIso8601String(),
          },
        )
        .select()
        .single();
    return ManualQuantitySnapshot.fromSupabase(Map<String, dynamic>.from(row));
  }

  @override
  Future<ManualQuantitySnapshot> recordManualUsage({
    required String productItemId,
    required int usedQuantity,
    required DateTime usedAt,
  }) async {
    final row = await _client
        .rpc(
          'record_product_usage',
          params: {
            'target_product_item_id': productItemId,
            'target_used_quantity': usedQuantity,
            'target_used_at': usedAt.toIso8601String(),
          },
        )
        .select()
        .single();
    return ManualQuantitySnapshot.fromSupabase(Map<String, dynamic>.from(row));
  }
```

- [ ] **Step 5: Update all fake `ItemDatabaseGateway` classes**

Every test fake that implements `ItemDatabaseGateway` must add `updatePurchase`, `setManualQuantity`, and `recordManualUsage`. Use this minimal implementation where the test does not inspect the calls:

```dart
  @override
  Future<void> updatePurchase({
    required String purchaseId,
    required Map<String, dynamic> payload,
  }) async {}

  @override
  Future<ManualQuantitySnapshot> setManualQuantity({
    required String productItemId,
    required int remainingQuantity,
    required DateTime observedAt,
  }) async {
    return ManualQuantitySnapshot(
      remainingQuantity: remainingQuantity,
      confidence: 1,
      sourceName: 'manual',
      observedAt: observedAt,
    );
  }

  @override
  Future<ManualQuantitySnapshot> recordManualUsage({
    required String productItemId,
    required int usedQuantity,
    required DateTime usedAt,
  }) async {
    return ManualQuantitySnapshot(
      remainingQuantity: 0,
      confidence: 1,
      sourceName: 'manual',
      observedAt: usedAt,
    );
  }
```

Add `import 'package:buylog/models/manual_quantity_snapshot.dart';` to each touched test file with a gateway fake.

- [ ] **Step 6: Run Supabase service tests and verify pass**

Run:

```bash
flutter test test/services/supabase_service_test.dart
```

Expected: all tests pass.

- [ ] **Step 7: Commit persistence changes**

```bash
git add supabase/migrations/20260530090000_add_manual_quantity_sync.sql lib/services/supabase_service.dart test/services/supabase_service_test.dart test/screens/add_item_screen_test.dart test/screens/group_screen_test.dart test/main_navigation_test.dart test/services/group_items_store_test.dart test/services/report_items_store_test.dart test/services/item_store_test.dart
git commit -m "feat: persist manual quantity sync"
```

---

### Task 3: Add Quantity Input To Registration

**Files:**
- Modify: `lib/screens/add_item_screen.dart`
- Test: `test/screens/add_item_screen_test.dart`

- [ ] **Step 1: Write failing registration screen tests**

In `test/screens/add_item_screen_test.dart`, update `_RecordingItemDatabaseGateway` to store purchase payloads:

```dart
  final List<Map<String, dynamic>> insertedPurchasePayloads = [];
```

Update `insertPurchase`:

```dart
  @override
  Future<void> insertPurchase(Map<String, dynamic> payload) async {
    insertedPurchasePayloads.add(Map<String, dynamic>.from(payload));
  }
```

Add tests:

```dart
  testWidgets('purchase quantity defaults to one when adding an item', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const AddItemScreen()));

    expect(find.byKey(const ValueKey('purchase_quantity_0')), findsOneWidget);
    expect(
      tester.widget<TextFormField>(
        find.byKey(const ValueKey('purchase_quantity_0')),
      ).controller?.text,
      '1',
    );

    await _submitMinimalItem(tester);

    expect(gateway.insertedPurchasePayloads.single['quantity'], 1);
    expect(gateway.manualQuantityRemainingQuantity, 1);
  });

  testWidgets('entered purchase quantity is saved and initializes inventory', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const AddItemScreen()));

    await tester.ensureVisible(find.byKey(const ValueKey('purchase_quantity_0')));
    await tester.enterText(find.byKey(const ValueKey('purchase_quantity_0')), '10');
    await _submitMinimalItem(tester);

    expect(gateway.insertedPurchasePayloads.single['quantity'], 10);
    expect(gateway.manualQuantityRemainingQuantity, 10);
  });
```

- [ ] **Step 2: Run registration tests and verify failure**

Run:

```bash
flutter test test/screens/add_item_screen_test.dart
```

Expected: fail because `purchase_quantity_0` is not present.

- [ ] **Step 3: Add quantity controller to `_PurchaseEntry`**

Update `_PurchaseEntry` in `lib/screens/add_item_screen.dart`:

```dart
class _PurchaseEntry {
  final String? id;
  final DateTime date;
  final TextEditingController priceCtrl;
  final TextEditingController storeCtrl;
  final TextEditingController quantityCtrl;

  _PurchaseEntry({
    this.id,
    required this.date,
    required this.priceCtrl,
    required this.storeCtrl,
    required this.quantityCtrl,
  });

  int get quantity {
    final parsed = int.tryParse(quantityCtrl.text.trim());
    if (parsed == null || parsed < 1) return 1;
    return parsed;
  }

  _PurchaseEntry copyWith({DateTime? date}) {
    return _PurchaseEntry(
      id: id,
      date: date ?? this.date,
      priceCtrl: priceCtrl,
      storeCtrl: storeCtrl,
      quantityCtrl: quantityCtrl,
    );
  }
}
```

Update every `_PurchaseEntry` constructor call:

```dart
            quantityCtrl: TextEditingController(text: r.quantity.toString()),
```

```dart
          quantityCtrl: TextEditingController(text: '1'),
```

Dispose the controller:

```dart
      e.quantityCtrl.dispose();
```

Also dispose it in `_removePurchaseEntry`:

```dart
      entry.quantityCtrl.dispose();
```

- [ ] **Step 4: Map quantity into `PurchaseRecord` and initial remaining quantity**

Update the purchase mapping in `_submit`:

```dart
      final purchases = _purchases
          .where((e) => e.priceCtrl.text.trim().isNotEmpty)
          .map(
            (e) => PurchaseRecord(
              id: e.id,
              date: e.date,
              price:
                  int.tryParse(
                    e.priceCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
                  ) ??
                  0,
              store: e.storeCtrl.text.trim(),
              quantity: e.quantity,
            ),
          )
          .toList();
```

Compute the new purchase quantity once:

```dart
      final newPurchaseQuantity = purchases.fold<int>(
        0,
        (total, purchase) => total + purchase.quantity,
      );
```

For duplicate merge, preserve existing inventory and add the new purchase quantity:

```dart
            final existingRemaining = duplicate.remainingQuantity;
            final mergedRemainingQuantity = existingRemaining == null
                ? duplicate.totalPurchasedQuantity + newPurchaseQuantity
                : existingRemaining + newPurchaseQuantity;
```

Set the merged item with `copyWith`:

```dart
            final mergedPurchaseHistory =
                List<PurchaseRecord>.of(duplicate.purchaseHistory)
                  ..addAll(newPurchases);
            final merged = duplicate.copyWith(
              imageUrl: imageUrl ?? duplicate.imageUrl,
              remainingQuantity: mergedRemainingQuantity,
              inventoryObservedAt: DateTime.now(),
              inventoryConfidence: 1,
              inventorySourceName: 'manual',
              purchaseHistory: mergedPurchaseHistory,
            );
```

Set the new item inventory fields:

```dart
        remainingQuantity: _isEditing
            ? widget.editItem!.remainingQuantity
            : newPurchaseQuantity,
        inventoryObservedAt: _isEditing
            ? widget.editItem!.inventoryObservedAt
            : DateTime.now(),
        inventoryConfidence: _isEditing
            ? widget.editItem!.inventoryConfidence
            : 1,
        inventorySourceName: _isEditing
            ? widget.editItem!.inventorySourceName
            : 'manual',
```

- [ ] **Step 5: Add the quantity field UI**

Inside `_buildPurchaseEntry`, replace the existing price/store row with a row that includes quantity:

```dart
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _compactField(
                  label: '가격 (원)',
                  controller: entry.priceCtrl,
                  hint: '0',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _compactField(
                  key: ValueKey('purchase_quantity_$index'),
                  label: '수량',
                  controller: entry.quantityCtrl,
                  hint: '1',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    final parsed = int.tryParse(value?.trim() ?? '');
                    if (parsed == null || parsed < 1) {
                      return '1개 이상';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _compactField(
            label: '매장명',
            controller: entry.storeCtrl,
            hint: '예) 쿠팡',
          ),
```

Update `_compactField` to accept a key and validator:

```dart
  Widget _compactField({
    Key? key,
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
```

Pass them into `TextFormField`:

```dart
        TextFormField(
          key: key,
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
```

- [ ] **Step 6: Run registration tests and verify pass**

Run:

```bash
flutter test test/screens/add_item_screen_test.dart
```

Expected: all tests pass.

- [ ] **Step 7: Commit registration UI changes**

```bash
git add lib/screens/add_item_screen.dart test/screens/add_item_screen_test.dart
git commit -m "feat: capture purchase quantity on registration"
```

---

### Task 4: ItemStore Manual Quantity Operations

**Files:**
- Modify: `lib/services/item_store.dart`
- Test: `test/services/item_store_test.dart`

- [ ] **Step 1: Write failing store tests**

Import the snapshot model in `test/services/item_store_test.dart`:

```dart
import 'package:buylog/models/manual_quantity_snapshot.dart';
```

Add helper seed parameters:

```dart
ConsumableItem _seed(
  String id, {
  String name = 'X',
  int days = 10,
  int? remainingQuantity,
}) =>
    ConsumableItem(
      id: id,
      name: name,
      brand: 'B',
      category: '기타',
      icon: ConsumableItem.iconForCategory('기타'),
      daysRemaining: days,
      cycleDays: 30,
      progress: 0.5,
      remainingQuantity: remainingQuantity,
    );
```

Add tests:

```dart
    test('recordManualUsage updates local remaining quantity', () async {
      final gateway = _RecordingItemDatabaseGateway();
      SupabaseService.debugItemDatabaseGateway = gateway;
      addTearDown(() => SupabaseService.debugItemDatabaseGateway = null);
      ItemStore.instance.value = [_seed('a', remainingQuantity: 3)];

      final updated = await ItemStore.instance.recordManualUsage(
        ItemStore.instance.value.single,
        usedQuantity: 1,
        usedAt: DateTime.parse('2026-05-30T12:00:00.000Z'),
      );

      expect(gateway.manualUsageProductItemId, 'a');
      expect(gateway.manualUsageUsedQuantity, 1);
      expect(updated.remainingQuantity, 2);
      expect(ItemStore.instance.value.single.remainingQuantity, 2);
    });

    test('recordManualUsage rejects counts below zero before saving', () async {
      final gateway = _RecordingItemDatabaseGateway();
      SupabaseService.debugItemDatabaseGateway = gateway;
      addTearDown(() => SupabaseService.debugItemDatabaseGateway = null);
      ItemStore.instance.value = [_seed('a', remainingQuantity: 0)];

      await expectLater(
        ItemStore.instance.recordManualUsage(
          ItemStore.instance.value.single,
          usedQuantity: 1,
        ),
        throwsA(isA<StateError>()),
      );

      expect(gateway.manualUsageProductItemId, isNull);
      expect(ItemStore.instance.value.single.remainingQuantity, 0);
    });

    test('recordManualUsage rolls back local quantity on Supabase failure', () async {
      final gateway = _RecordingItemDatabaseGateway()
        ..manualUsageError = StateError('rpc failed');
      SupabaseService.debugItemDatabaseGateway = gateway;
      addTearDown(() => SupabaseService.debugItemDatabaseGateway = null);
      ItemStore.instance.value = [_seed('a', remainingQuantity: 3)];

      await expectLater(
        ItemStore.instance.recordManualUsage(
          ItemStore.instance.value.single,
          usedQuantity: 1,
        ),
        throwsA(isA<StateError>()),
      );

      expect(ItemStore.instance.value.single.remainingQuantity, 3);
    });
```

Extend `_RecordingItemDatabaseGateway` in this test file with the same interface methods used in Task 2. Its `recordManualUsage` should compute a remaining count of `2` for these tests:

```dart
  Object? manualUsageError;
  String? manualUsageProductItemId;
  int? manualUsageUsedQuantity;

  @override
  Future<ManualQuantitySnapshot> recordManualUsage({
    required String productItemId,
    required int usedQuantity,
    required DateTime usedAt,
  }) async {
    if (manualUsageError != null) throw manualUsageError!;
    manualUsageProductItemId = productItemId;
    manualUsageUsedQuantity = usedQuantity;
    return ManualQuantitySnapshot(
      remainingQuantity: 2,
      confidence: 1,
      sourceName: 'manual',
      observedAt: usedAt,
    );
  }
```

- [ ] **Step 2: Run store tests and verify failure**

Run:

```bash
flutter test test/services/item_store_test.dart
```

Expected: fail because `ItemStore.recordManualUsage` does not exist.

- [ ] **Step 3: Implement `recordManualUsage` and `setManualQuantity`**

Add these methods to `ItemStore`:

```dart
  Future<ConsumableItem> recordManualUsage(
    ConsumableItem item, {
    int usedQuantity = 1,
    DateTime? usedAt,
  }) async {
    if (usedQuantity < 1) {
      throw ArgumentError.value(
        usedQuantity,
        'usedQuantity',
        'Used quantity must be greater than zero.',
      );
    }

    final current = findById(item.id) ?? item;
    final remaining = current.remainingQuantity;
    if (remaining != null && remaining < usedQuantity) {
      throw StateError('남은 수량보다 많이 사용할 수 없습니다.');
    }

    final observedAt = usedAt ?? DateTime.now();
    final previous = List<ConsumableItem>.unmodifiable(value);
    final hasLocalItem = value.any((candidate) => candidate.id == current.id);

    if (hasLocalItem && remaining != null) {
      _replaceLocal(
        current.copyWith(
          remainingQuantity: remaining - usedQuantity,
          inventoryObservedAt: observedAt,
          inventoryConfidence: 1,
          inventorySourceName: 'manual',
        ),
      );
    }

    try {
      final snapshot = await SupabaseService.recordManualUsage(
        productItemId: current.id,
        usedQuantity: usedQuantity,
        usedAt: observedAt,
      );
      final updated = current.copyWith(
        remainingQuantity: snapshot.remainingQuantity,
        inventoryObservedAt: snapshot.observedAt,
        inventoryConfidence: snapshot.confidence,
        inventorySourceName: snapshot.sourceName,
      );
      if (hasLocalItem) {
        _replaceLocal(updated);
      }
      _notifySaved(_scopeFor(updated));
      return updated;
    } catch (_) {
      if (hasLocalItem) {
        value = List.of(previous);
      }
      rethrow;
    }
  }

  Future<ConsumableItem> setManualQuantity(
    ConsumableItem item, {
    required int remainingQuantity,
    DateTime? observedAt,
  }) async {
    if (remainingQuantity < 0) {
      throw ArgumentError.value(
        remainingQuantity,
        'remainingQuantity',
        'Remaining quantity must be zero or greater.',
      );
    }

    final current = findById(item.id) ?? item;
    final effectiveObservedAt = observedAt ?? DateTime.now();
    final previous = List<ConsumableItem>.unmodifiable(value);
    final hasLocalItem = value.any((candidate) => candidate.id == current.id);

    if (hasLocalItem) {
      _replaceLocal(
        current.copyWith(
          remainingQuantity: remainingQuantity,
          inventoryObservedAt: effectiveObservedAt,
          inventoryConfidence: 1,
          inventorySourceName: 'manual',
        ),
      );
    }

    try {
      final snapshot = await SupabaseService.setManualQuantity(
        productItemId: current.id,
        remainingQuantity: remainingQuantity,
        observedAt: effectiveObservedAt,
      );
      final updated = current.copyWith(
        remainingQuantity: snapshot.remainingQuantity,
        inventoryObservedAt: snapshot.observedAt,
        inventoryConfidence: snapshot.confidence,
        inventorySourceName: snapshot.sourceName,
      );
      if (hasLocalItem) {
        _replaceLocal(updated);
      }
      _notifySaved(_scopeFor(updated));
      return updated;
    } catch (_) {
      if (hasLocalItem) {
        value = List.of(previous);
      }
      rethrow;
    }
  }

  void _replaceLocal(ConsumableItem updated) {
    value = value
        .map((item) => item.id == updated.id ? updated : item)
        .toList(growable: false);
  }

  ItemScope _scopeFor(ConsumableItem item) {
    final groupId = item.groupId;
    if (groupId != null && groupId.isNotEmpty) {
      return ItemScope.group(id: groupId, label: '그룹');
    }
    return const ItemScope.personal();
  }
```

- [ ] **Step 4: Run store tests and verify pass**

Run:

```bash
flutter test test/services/item_store_test.dart
```

Expected: all tests pass.

- [ ] **Step 5: Commit store changes**

```bash
git add lib/services/item_store.dart test/services/item_store_test.dart
git commit -m "feat: add manual quantity store updates"
```

---

### Task 5: Detail Screen Manual Countdown UI

**Files:**
- Modify: `lib/screens/item_detail_screen.dart`
- Test: `test/screens/item_detail_screen_test.dart`

- [ ] **Step 1: Write failing detail screen tests**

In `test/screens/item_detail_screen_test.dart`, add a fake gateway for item quantity calls or reuse `SupabaseService.debugItemDatabaseGateway` with methods from Task 2. Add tests:

```dart
  testWidgets('item detail can decrement one remaining item manually', (
    tester,
  ) async {
    final gateway = _RecordingItemDatabaseGateway()
      ..manualUsageRemainingQuantity = 1;
    SupabaseService.debugItemDatabaseGateway = gateway;
    addTearDown(() => SupabaseService.debugItemDatabaseGateway = null);
    final item = _item(id: 'item-usage', remainingQuantity: 2);
    ItemStore.instance.value = [item];

    await tester.pumpWidget(
      _wrap(
        item: item,
        priceComparisonGateway:
            ({required brand, required display, required itemName}) async {
              return const PriceComparisonFetchResult(
                comparisons: [],
                source: PriceComparisonSource.proxy,
              );
            },
      ),
    );

    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('manual_use_one_button')));
    await tester.pumpAndSettle();

    expect(gateway.manualUsageProductItemId, 'item-usage');
    expect(gateway.manualUsageUsedQuantity, 1);
    expect(find.text('1개'), findsOneWidget);
  });

  testWidgets('manual use button is disabled at zero quantity', (tester) async {
    final item = _item(id: 'item-zero', remainingQuantity: 0);
    ItemStore.instance.value = [item];

    await tester.pumpWidget(
      _wrap(
        item: item,
        priceComparisonGateway:
            ({required brand, required display, required itemName}) async {
              return const PriceComparisonFetchResult(
                comparisons: [],
                source: PriceComparisonSource.proxy,
              );
            },
      ),
    );

    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('manual_use_one_button')),
    );
    expect(button.onPressed, isNull);
  });
```

- [ ] **Step 2: Run detail screen tests and verify failure**

Run:

```bash
flutter test test/screens/item_detail_screen_test.dart
```

Expected: fail because `manual_use_one_button` is missing.

- [ ] **Step 3: Add detail screen state and actions**

Add state to `_ItemDetailScreenState`:

```dart
  bool _isSavingQuantity = false;
```

Add manual use action:

```dart
  Future<void> _recordManualUseOne() async {
    if (_isSavingQuantity || (_item.remainingQuantity ?? 0) <= 0) {
      return;
    }

    setState(() => _isSavingQuantity = true);
    try {
      final updated = await ItemStore.instance.recordManualUsage(
        _item,
        usedQuantity: 1,
      );
      if (mounted) {
        setState(() => _item = updated);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('수량을 동기화하지 못했습니다. 잠시 후 다시 시도해주세요.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingQuantity = false);
      }
    }
  }
```

Add manual set dialog:

```dart
  Future<void> _openManualQuantityDialog() async {
    final controller = TextEditingController(
      text: (_item.remainingQuantity ?? _item.totalPurchasedQuantity).toString(),
    );
    final formKey = GlobalKey<FormState>();
    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('수량 맞추기'),
        content: Form(
          key: formKey,
          child: TextFormField(
            key: const ValueKey('manual_quantity_input'),
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '현재 남은 수량'),
            validator: (value) {
              final parsed = int.tryParse(value?.trim() ?? '');
              if (parsed == null || parsed < 0) {
                return '0개 이상 입력해주세요.';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx, int.parse(controller.text.trim()));
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (selected == null) return;
    setState(() => _isSavingQuantity = true);
    try {
      final updated = await ItemStore.instance.setManualQuantity(
        _item,
        remainingQuantity: selected,
      );
      if (mounted) {
        setState(() => _item = updated);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('수량을 저장하지 못했습니다. 잠시 후 다시 시도해주세요.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingQuantity = false);
      }
    }
  }
```

- [ ] **Step 4: Render actions in the inventory card**

At the bottom of `_buildCurrentInventory`, after the observed date block, add:

```dart
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('manual_use_one_button'),
                  onPressed:
                      _isSavingQuantity || (_item.remainingQuantity ?? 0) <= 0
                      ? null
                      : _recordManualUseOne,
                  icon: _isSavingQuantity
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.remove_circle_outline, size: 18),
                  label: const Text('1개 사용'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                key: const ValueKey('manual_set_quantity_button'),
                onPressed: _isSavingQuantity ? null : _openManualQuantityDialog,
                icon: const Icon(Icons.sync, size: 18),
                label: const Text('맞추기'),
              ),
            ],
          ),
```

Change the build condition so existing items can start manual tracking even when no snapshot exists:

```dart
            if (_item.remainingQuantity != null ||
                _item.purchaseHistory.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: _buildCurrentInventory(),
              ),
```

Inside `_buildCurrentInventory`, compute a fallback:

```dart
    final remainingQuantity =
        _item.remainingQuantity ?? _item.totalPurchasedQuantity;
```

Use `remainingQuantity` in displayed text and button disabled checks:

```dart
                '$remainingQuantity개',
```

- [ ] **Step 5: Run detail screen tests and verify pass**

Run:

```bash
flutter test test/screens/item_detail_screen_test.dart
```

Expected: all tests pass.

- [ ] **Step 6: Commit detail UI changes**

```bash
git add lib/screens/item_detail_screen.dart test/screens/item_detail_screen_test.dart
git commit -m "feat: add manual quantity countdown"
```

---

### Task 6: Regression Pass

**Files:**
- Modify only files changed by earlier tasks if verification finds a real failure.

- [ ] **Step 1: Format changed Dart files**

Run:

```bash
dart format lib/models/item.dart lib/models/manual_quantity_snapshot.dart lib/services/supabase_service.dart lib/services/item_store.dart lib/screens/add_item_screen.dart lib/screens/item_detail_screen.dart test/models/item_quantity_test.dart test/services/supabase_service_test.dart test/services/item_store_test.dart test/screens/add_item_screen_test.dart test/screens/item_detail_screen_test.dart
```

Expected: formatter exits with code 0.

- [ ] **Step 2: Run analyzer**

Run:

```bash
flutter analyze
```

Expected: analyzer exits with code 0.

- [ ] **Step 3: Run targeted tests**

Run:

```bash
flutter test test/models/item_quantity_test.dart test/services/supabase_service_test.dart test/services/item_store_test.dart test/screens/add_item_screen_test.dart test/screens/item_detail_screen_test.dart
```

Expected: all targeted tests pass.

- [ ] **Step 4: Run full test suite**

Run:

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 5: Verify SQL migration locally if Supabase CLI is available**

Run:

```bash
supabase db reset
```

Expected: migration applies without SQL errors and the local database resets successfully.

- [ ] **Step 6: Commit final verification fixes**

If formatting or test fixes changed files, commit them:

```bash
git add lib test supabase/migrations/20260530090000_add_manual_quantity_sync.sql
git commit -m "test: verify quantity usage sync"
```

If no files changed after verification, skip this commit.

---

## Self-Review

- Spec coverage: registration quantity, default quantity 1, manual countdown, manual exact sync, and future cycle evidence are each covered by a task.
- Test coverage: model, service, store, registration screen, detail screen, analyzer, targeted tests, and full suite are included.
- Type consistency: `PurchaseRecord.quantity`, `ManualQuantitySnapshot`, `setManualQuantity`, and `recordManualUsage` names are consistent across model, service, store, and tests.
- Scope: automatic replacement-cycle recalculation is intentionally excluded; the event history required for that calculation is included.
