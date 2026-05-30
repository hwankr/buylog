begin;

create schema if not exists private;

create or replace function private.current_buylog_user_id()
returns uuid
language sql
stable
set search_path = ''
as $$
  select coalesce(
    (select auth.uid()),
    '08cccfe3-766f-43bd-b06c-8d909e0f9fe8'::uuid
  );
$$;

create or replace function private.can_access_product_item(
  target_product_item_id uuid,
  target_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.product_items as pi
    where pi.id = target_product_item_id
      and (
        pi.user_id = target_user_id
        or (
          pi.group_id is not null
          and exists (
            select 1
            from public.group_members as gm
            where gm.group_id = pi.group_id
              and gm.user_id = target_user_id
          )
        )
      )
  );
$$;

revoke all on function private.current_buylog_user_id() from public;
revoke all on function private.can_access_product_item(uuid, uuid) from public;
grant execute on function private.current_buylog_user_id() to anon, authenticated;
grant execute on function private.can_access_product_item(uuid, uuid) to anon, authenticated;

create table public.inventory_observations (
  id uuid primary key default gen_random_uuid(),
  device_id text not null,
  user_id uuid references public.users(id) on delete cascade,
  group_id uuid references public.groups(id) on delete cascade,
  image_file text not null,
  txt_file text,
  summary text,
  raw_result jsonb not null default '{}'::jsonb,
  gpt_ok boolean not null default false,
  sensor_id text,
  weight_g numeric,
  delta_g numeric,
  observed_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint inventory_observations_owner_check check (
    (user_id is not null and group_id is null) or
    (user_id is null and group_id is not null)
  )
);

create table public.inventory_observation_items (
  id uuid primary key default gen_random_uuid(),
  observation_id uuid not null references public.inventory_observations(id) on delete cascade,
  product_item_id uuid references public.product_items(id) on delete set null,
  detected_name text not null,
  normalized_name text not null,
  quantity int not null check (quantity >= 0),
  confidence numeric(4, 3) not null check (confidence >= 0 and confidence <= 1),
  note text,
  match_status text not null check (
    match_status in ('matched', 'unmatched', 'low_confidence', 'ambiguous')
  ),
  match_score numeric(5, 4) check (
    match_score is null or (match_score >= 0 and match_score <= 1)
  ),
  created_at timestamptz not null default now()
);

create table public.product_inventory_snapshots (
  product_item_id uuid primary key references public.product_items(id) on delete cascade,
  observation_item_id uuid references public.inventory_observation_items(id) on delete set null,
  remaining_quantity int not null check (remaining_quantity >= 0),
  confidence numeric(4, 3) not null check (confidence >= 0 and confidence <= 1),
  source_detected_name text not null,
  observed_at timestamptz not null,
  updated_at timestamptz not null default now()
);

create or replace function private.can_access_inventory_observation(
  target_observation_id uuid,
  target_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.inventory_observations as io
    where io.id = target_observation_id
      and (
        io.user_id = target_user_id
        or (
          io.group_id is not null
          and exists (
            select 1
            from public.group_members as gm
            where gm.group_id = io.group_id
              and gm.user_id = target_user_id
          )
        )
      )
  );
$$;

revoke all on function private.can_access_inventory_observation(uuid, uuid) from public;
grant execute on function private.can_access_inventory_observation(uuid, uuid) to anon, authenticated;

comment on table public.inventory_observations is
  'Camera/GPT inventory recognition runs received from MIDAS hardware.';
comment on table public.inventory_observation_items is
  'Detected items from a single inventory observation, including matching status.';
comment on table public.product_inventory_snapshots is
  'Latest known remaining quantity per registered product item.';

create index inventory_observations_owner_observed_at_idx
on public.inventory_observations (user_id, group_id, observed_at desc);

create index inventory_observation_items_observation_idx
on public.inventory_observation_items (observation_id);

create index inventory_observation_items_product_idx
on public.inventory_observation_items (product_item_id, created_at desc)
where product_item_id is not null;

create trigger trg_product_inventory_snapshots_updated_at
  before update on public.product_inventory_snapshots
  for each row execute function update_updated_at();

grant select on table public.inventory_observations to anon, authenticated;
grant select on table public.inventory_observation_items to anon, authenticated;
grant select on table public.product_inventory_snapshots to anon, authenticated;

grant select, insert on table public.inventory_observations to service_role;
grant select, insert on table public.inventory_observation_items to service_role;
grant select, insert, update on table public.product_inventory_snapshots to service_role;

alter table public.inventory_observations enable row level security;
alter table public.inventory_observation_items enable row level security;
alter table public.product_inventory_snapshots enable row level security;

create policy "Users can view accessible inventory observations"
on public.inventory_observations
for select
to anon, authenticated
using (
  user_id = private.current_buylog_user_id()
  or (
    group_id is not null
    and private.is_group_member(group_id, private.current_buylog_user_id())
  )
);

create policy "Users can view accessible inventory observation items"
on public.inventory_observation_items
for select
to anon, authenticated
using (
  private.can_access_inventory_observation(
    observation_id,
    private.current_buylog_user_id()
  )
);

create policy "Users can view accessible product inventory snapshots"
on public.product_inventory_snapshots
for select
to anon, authenticated
using (
  private.can_access_product_item(
    product_item_id,
    private.current_buylog_user_id()
  )
);

commit;
