-- Replace the bulky generated demo seed with a curated household dataset.
--
-- This migration intentionally touches only the deterministic Buylog demo user:
-- 00000000-0000-4000-8000-000000000101

begin;

do $$
begin
  if to_regclass('public.users') is null then
    raise exception 'public.users must exist before applying curated demo seed';
  end if;

  if to_regclass('public.categories') is null then
    raise exception 'public.categories must exist before applying curated demo seed';
  end if;

  if to_regclass('public.product_items') is null then
    raise exception 'public.product_items must exist before applying curated demo seed';
  end if;

  if to_regclass('public.purchases') is null then
    raise exception 'public.purchases must exist before applying curated demo seed';
  end if;

  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'purchases'
      and column_name = 'use_started_on'
  ) then
    raise exception 'public.purchases.use_started_on must exist before applying curated demo seed';
  end if;

  if (
    select count(*)
    from public.categories
    where user_id is null
      and group_id is null
      and name in ('필터류', '주방용품', '세탁용품', '위생용품')
  ) < 4 then
    raise exception 'required system categories are missing before applying curated demo seed';
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
  now() - interval '420 days',
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{"display_name":"사용자"}'::jsonb,
  now() - interval '420 days',
  now()
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
  '사용자',
  true,
  now() - interval '420 days'
)
on conflict (id) do update
set
  email = excluded.email,
  display_name = excluded.display_name,
  notification_enabled = excluded.notification_enabled;

delete from public.product_items
where user_id = '00000000-0000-4000-8000-000000000101'::uuid;

with curated_products(name, brand, category_name, replacement_cycle_days, created_days_ago) as (
  values
    ('정수기 필터', '코웨이', '필터류', 90, 360),
    ('주방 세제', '자연퐁', '주방용품', 32, 330),
    ('세탁 세제', '퍼실', '세탁용품', 48, 310),
    ('휴지', '코디', '위생용품', 36, 300),
    ('치약', '덴티스테', '위생용품', 70, 250),
    ('샴푸', '케라시스', '위생용품', 65, 220),
    ('샤워기 필터', '바디럽', '필터류', 95, 210)
),
resolved_products as (
  select
    '00000000-0000-4000-8000-000000000101'::uuid as user_id,
    categories.id as category_id,
    curated_products.name,
    curated_products.brand,
    curated_products.replacement_cycle_days,
    (current_date - curated_products.created_days_ago)::timestamp with time zone + interval '10 hours' as created_at
  from curated_products
  join public.categories
    on categories.name = curated_products.category_name
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
  created_at,
  updated_at
)
select
  resolved_products.user_id,
  resolved_products.category_id,
  resolved_products.name,
  resolved_products.brand,
  resolved_products.replacement_cycle_days,
  resolved_products.user_id,
  resolved_products.created_at,
  resolved_products.created_at
from resolved_products;

with curated_purchases(product_name, product_brand, days_ago, use_delay_days, price, store_name) as (
  values
    ('정수기 필터', '코웨이', 284, 1, 34900, '코웨이몰'),
    ('정수기 필터', '코웨이', 193, 2, 35900, '쿠팡'),
    ('정수기 필터', '코웨이', 103, 1, 34500, '네이버쇼핑'),
    ('정수기 필터', '코웨이', 14, 2, 34900, '코웨이몰'),

    ('주방 세제', '자연퐁', 132, 0, 5200, '홈플러스'),
    ('주방 세제', '자연퐁', 98, 1, 4980, '이마트'),
    ('주방 세제', '자연퐁', 67, 0, 4700, '쿠팡'),
    ('주방 세제', '자연퐁', 39, 2, 5200, '이마트'),
    ('주방 세제', '자연퐁', 8, 1, 4980, '이마트'),

    ('세탁 세제', '퍼실', 151, 4, 18500, '코스트코'),
    ('세탁 세제', '퍼실', 102, 3, 18900, 'SSG닷컴'),
    ('세탁 세제', '퍼실', 58, 5, 19200, '쿠팡'),
    ('세탁 세제', '퍼실', 11, 3, 18900, '쿠팡'),

    ('휴지', '코디', 137, 0, 16200, '이마트'),
    ('휴지', '코디', 101, 0, 15900, '쿠팡'),
    ('휴지', '코디', 65, 0, 16200, '이마트'),
    ('휴지', '코디', 33, 1, 15400, '쿠팡'),
    ('휴지', '코디', 6, 0, 15900, '마켓컬리'),

    ('치약', '덴티스테', 149, 3, 9500, '네이버쇼핑'),
    ('치약', '덴티스테', 81, 1, 9800, '쿠팡'),
    ('치약', '덴티스테', 16, 2, 9900, '올리브영'),

    ('샴푸', '케라시스', 138, 5, 13100, '롯데온'),
    ('샴푸', '케라시스', 72, 3, 12500, '쿠팡'),
    ('샴푸', '케라시스', 10, 4, 12900, '올리브영'),

    ('샤워기 필터', '바디럽', 202, 2, 17200, '네이버쇼핑'),
    ('샤워기 필터', '바디럽', 109, 2, 17500, '쿠팡'),
    ('샤워기 필터', '바디럽', 19, 3, 17900, '오늘의집')
),
resolved_purchases as (
  select
    product_items.id as product_item_id,
    '00000000-0000-4000-8000-000000000101'::uuid as purchased_by,
    (current_date - curated_purchases.days_ago)::date as purchase_date,
    (current_date - curated_purchases.days_ago + curated_purchases.use_delay_days)::date as use_started_on,
    curated_purchases.price,
    curated_purchases.store_name,
    (current_date - curated_purchases.days_ago)::timestamp with time zone + interval '13 hours' as created_at
  from curated_purchases
  join public.product_items
    on product_items.user_id = '00000000-0000-4000-8000-000000000101'::uuid
   and product_items.name = curated_purchases.product_name
   and product_items.brand = curated_purchases.product_brand
)
insert into public.purchases (
  product_item_id,
  purchased_by,
  purchase_date,
  use_started_on,
  price,
  store_name,
  quantity,
  created_at
)
select
  resolved_purchases.product_item_id,
  resolved_purchases.purchased_by,
  resolved_purchases.purchase_date,
  resolved_purchases.use_started_on,
  resolved_purchases.price,
  resolved_purchases.store_name,
  1,
  resolved_purchases.created_at
from resolved_purchases;

commit;
