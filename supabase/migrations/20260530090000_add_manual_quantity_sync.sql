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
