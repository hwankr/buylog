-- Long-running sample consumable data for manual QA and demos.
--
-- This seed creates one deterministic demo user and gives that user enough
-- purchase history to make D-day, cycle prediction, and spending screens look
-- like the app has been used for a long time.

begin;

do $$
begin
  if to_regclass('public.product_items') is null then
    raise exception 'public.product_items must exist before applying seed_sample_consumables';
  end if;

  if to_regclass('public.purchases') is null then
    raise exception 'public.purchases must exist before applying seed_sample_consumables';
  end if;

  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'purchases'
      and column_name = 'use_started_on'
  ) then
    raise exception 'public.purchases.use_started_on must exist before applying seed_sample_consumables';
  end if;
end $$;

insert into auth.users (
  id,
  aud,
  role,
  email,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
)
values (
  '00000000-0000-4000-8000-000000000101',
  'authenticated',
  'authenticated',
  'demo.user+buylog@example.com',
  now() - interval '760 days',
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{"display_name":"Buylog Demo User"}'::jsonb,
  now() - interval '760 days',
  now() - interval '1 day'
)
on conflict (id) do update
set
  email = excluded.email,
  raw_app_meta_data = excluded.raw_app_meta_data,
  raw_user_meta_data = excluded.raw_user_meta_data,
  updated_at = now();

insert into public.users (
  id,
  email,
  display_name,
  notification_enabled,
  created_at
)
values (
  '00000000-0000-4000-8000-000000000101',
  'demo.user+buylog@example.com',
  'Buylog Demo User',
  true,
  now() - interval '760 days'
)
on conflict (id) do update
set
  email = excluded.email,
  display_name = excluded.display_name,
  notification_enabled = excluded.notification_enabled;

with seed_products(name, brand, category_name, replacement_cycle_days, created_at) as (
  values
    ('정수기 필터', '코웨이', '필터류', 90, now() - interval '720 days'),
    ('주방 세제', '자연퐁', '주방용품', 30, now() - interval '710 days'),
    ('고양이 모래', '카사바랑', '생활잡화', 21, now() - interval '700 days'),
    ('액상 세제', '퍼실', '세탁용품', 45, now() - interval '690 days'),
    ('휴지', '코디', '위생용품', 42, now() - interval '680 days'),
    ('치약', '덴티스테', '위생용품', 60, now() - interval '670 days'),
    ('칫솔', '오랄비', '위생용품', 90, now() - interval '660 days'),
    ('에어컨 필터', '삼성', '필터류', 180, now() - interval '650 days'),
    ('샤워기 필터', '바디럽', '필터류', 75, now() - interval '640 days'),
    ('식기세척기 세제', '프로쉬', '주방용품', 50, now() - interval '630 days')
),
resolved_products as (
  select
    '00000000-0000-4000-8000-000000000101'::uuid as user_id,
    categories.id as category_id,
    seed_products.name,
    seed_products.brand,
    seed_products.replacement_cycle_days,
    seed_products.created_at
  from seed_products
  join public.categories
    on categories.name = seed_products.category_name
   and categories.user_id is null
   and categories.group_id is null
)
insert into public.product_items (
  user_id,
  category_id,
  name,
  brand,
  replacement_cycle_days,
  registered_by,
  created_at
)
select
  resolved_products.user_id,
  resolved_products.category_id,
  resolved_products.name,
  resolved_products.brand,
  resolved_products.replacement_cycle_days,
  resolved_products.user_id,
  resolved_products.created_at
from resolved_products
where not exists (
  select 1
  from public.product_items existing
  where existing.user_id = resolved_products.user_id
    and existing.name = resolved_products.name
    and existing.brand = resolved_products.brand
);

with demo_products(name, brand, start_offset, cycle_days, count_rows, base_price, store_names) as (
  values
    ('정수기 필터', '코웨이', 641, 92, 7, 34900, array['쿠팡','네이버쇼핑','오늘의집']),
    ('주방 세제', '자연퐁', 705, 32, 22, 4300, array['이마트','쿠팡','홈플러스']),
    ('고양이 모래', '카사바랑', 620, 23, 27, 13200, array['마켓컬리','쿠팡','펫프렌즈']),
    ('액상 세제', '퍼실', 610, 45, 14, 14900, array['이마트','쿠팡','네이버쇼핑']),
    ('휴지', '코디', 590, 42, 14, 18900, array['쿠팡','이마트','홈플러스']),
    ('치약', '덴티스테', 540, 61, 9, 10800, array['올리브영','쿠팡','네이버쇼핑']),
    ('칫솔', '오랄비', 620, 91, 7, 7900, array['다이소','쿠팡','올리브영']),
    ('에어컨 필터', '삼성', 560, 182, 4, 19800, array['삼성몰','쿠팡','네이버쇼핑']),
    ('샤워기 필터', '바디럽', 520, 76, 7, 11900, array['쿠팡','오늘의집']),
    ('식기세척기 세제', '프로쉬', 490, 51, 10, 14900, array['마켓컬리','쿠팡','이마트'])
),
seed_purchases as (
  select
    demo_products.name as product_name,
    demo_products.brand as product_brand,
    (current_date - (demo_products.start_offset - (n * demo_products.cycle_days)))::date as purchase_date,
    (current_date - (demo_products.start_offset - (n * demo_products.cycle_days)) + ((n % 4) + 1))::date as use_started_on,
    (demo_products.base_price + (n * 350) + ((n % 3) * 200))::integer as price,
    demo_products.store_names[(n % array_length(demo_products.store_names, 1)) + 1] as store_name
  from demo_products
  cross join lateral generate_series(0, demo_products.count_rows - 1) as n
),
valid_seed_purchases as (
  select *
  from seed_purchases
  where purchase_date <= current_date
    and use_started_on <= current_date
),
resolved_purchases as (
  select
    product_items.id as product_item_id,
    '00000000-0000-4000-8000-000000000101'::uuid as purchased_by,
    valid_seed_purchases.purchase_date,
    valid_seed_purchases.use_started_on,
    valid_seed_purchases.price,
    valid_seed_purchases.store_name,
    valid_seed_purchases.purchase_date::timestamp with time zone + interval '12 hours' as created_at
  from valid_seed_purchases
  join public.product_items
    on product_items.user_id = '00000000-0000-4000-8000-000000000101'::uuid
   and product_items.name = valid_seed_purchases.product_name
   and product_items.brand = valid_seed_purchases.product_brand
)
insert into public.purchases (
  product_item_id,
  purchased_by,
  purchase_date,
  use_started_on,
  price,
  store_name,
  created_at
)
select
  resolved_purchases.product_item_id,
  resolved_purchases.purchased_by,
  resolved_purchases.purchase_date,
  resolved_purchases.use_started_on,
  resolved_purchases.price,
  resolved_purchases.store_name,
  resolved_purchases.created_at
from resolved_purchases
where not exists (
  select 1
  from public.purchases existing
  where existing.product_item_id = resolved_purchases.product_item_id
    and existing.purchase_date = resolved_purchases.purchase_date
    and existing.store_name = resolved_purchases.store_name
);

commit;
