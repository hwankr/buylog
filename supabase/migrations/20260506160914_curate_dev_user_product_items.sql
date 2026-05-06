-- Replace noisy development-user product_items with a realistic household set.
--
-- The Flutter app currently reads this fixed development user through
-- SupabaseService.currentUserId. Keep this cleanup scoped to that user only.

begin;

do $$
begin
  if to_regclass('public.users') is null then
    raise exception 'public.users must exist before applying curate_dev_user_product_items';
  end if;

  if to_regclass('public.categories') is null then
    raise exception 'public.categories must exist before applying curate_dev_user_product_items';
  end if;

  if to_regclass('public.product_items') is null then
    raise exception 'public.product_items must exist before applying curate_dev_user_product_items';
  end if;

  if to_regclass('public.purchases') is null then
    raise exception 'public.purchases must exist before applying curate_dev_user_product_items';
  end if;

  if to_regclass('public.ai_predictions') is null then
    raise exception 'public.ai_predictions must exist before applying curate_dev_user_product_items';
  end if;

  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'purchases'
      and column_name = 'use_started_on'
  ) then
    raise exception 'public.purchases.use_started_on must exist before applying curate_dev_user_product_items';
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
  '08cccfe3-766f-43bd-b06c-8d909e0f9fe8',
  'authenticated',
  'authenticated',
  'dev.user+buylog@example.com',
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
  '08cccfe3-766f-43bd-b06c-8d909e0f9fe8',
  'dev.user+buylog@example.com',
  '사용자',
  true,
  now() - interval '420 days'
)
on conflict (id) do update
set
  email = excluded.email,
  display_name = excluded.display_name,
  notification_enabled = excluded.notification_enabled;

create temporary table curate_dev_user_product_items_decision (
  should_replace boolean not null
) on commit drop;

do $$
declare
  existing_product_count int;
  noisy_product_count int;
  curated_product_count int;
  existing_purchase_count int;
  existing_prediction_count int;
begin
  select
    count(*)::int,
    count(*) filter (
      where name ilike '%test%'
         or name ilike '%issue%'
         or name like '테스트 물품%'
         or name in ('삼다수2L', '테스트 세제', '테스트 필터')
    )::int,
    count(*) filter (
      where (name, brand) in (
        ('샤워기 필터', '바디럽'),
        ('정수기 필터', '코웨이'),
        ('주방 세제', '자연퐁'),
        ('식기세척기 세제', '프로쉬'),
        ('세탁 세제', '퍼실'),
        ('화장지', '코디'),
        ('치약', '덴티스테'),
        ('샴푸', '케라시스')
      )
    )::int
  into existing_product_count, noisy_product_count, curated_product_count
  from public.product_items
  where user_id = '08cccfe3-766f-43bd-b06c-8d909e0f9fe8'::uuid;

  select count(*)::int
  into existing_purchase_count
  from public.purchases
  join public.product_items
    on product_items.id = purchases.product_item_id
  where product_items.user_id = '08cccfe3-766f-43bd-b06c-8d909e0f9fe8'::uuid;

  select count(*)::int
  into existing_prediction_count
  from public.ai_predictions
  join public.product_items
    on product_items.id = ai_predictions.product_item_id
  where product_items.user_id = '08cccfe3-766f-43bd-b06c-8d909e0f9fe8'::uuid;

  if existing_product_count > 0
     and noisy_product_count = 0
     and curated_product_count <> existing_product_count then
    raise exception
      'Refusing to replace % existing development-user product_items without noisy seed markers',
      existing_product_count;
  end if;

  insert into curate_dev_user_product_items_decision (should_replace)
  values (
    existing_product_count = 0
    or noisy_product_count > 0
    or (
      existing_product_count = 8
      and curated_product_count = 8
      and existing_purchase_count < 30
      and existing_prediction_count = 0
    )
  );
end $$;

with desired_categories(name, icon, color, sort_order) as (
  values
    ('욕실/위생', 'bathroom', '#4A90D9', 10),
    ('주방/세제', 'kitchen', '#E8913A', 20),
    ('세탁/청소', 'laundry', '#9B59B6', 30),
    ('헤어/바디', 'shower', '#2ECC71', 40),
    ('가전/필터', 'air', '#45B7D1', 50)
)
insert into public.categories (
  user_id,
  name,
  icon,
  color,
  sort_order
)
select
  '08cccfe3-766f-43bd-b06c-8d909e0f9fe8'::uuid,
  desired_categories.name,
  desired_categories.icon,
  desired_categories.color,
  desired_categories.sort_order
from desired_categories
where not exists (
  select 1
  from public.categories existing
  where existing.user_id = '08cccfe3-766f-43bd-b06c-8d909e0f9fe8'::uuid
    and existing.group_id is null
    and existing.name = desired_categories.name
);

delete from public.product_items
where user_id = '08cccfe3-766f-43bd-b06c-8d909e0f9fe8'::uuid
  and exists (
    select 1
    from curate_dev_user_product_items_decision
    where should_replace
  );

with curated_products(name, brand, category_name, replacement_cycle_days, created_days_ago) as (
  values
    ('샤워기 필터', '바디럽', '가전/필터', 95, 260),
    ('정수기 필터', '코웨이', '가전/필터', 90, 340),
    ('주방 세제', '자연퐁', '주방/세제', 32, 210),
    ('식기세척기 세제', '프로쉬', '주방/세제', 45, 190),
    ('세탁 세제', '퍼실', '세탁/청소', 48, 240),
    ('화장지', '코디', '욕실/위생', 36, 180),
    ('치약', '덴티스테', '욕실/위생', 70, 220),
    ('샴푸', '케라시스', '헤어/바디', 65, 200)
),
category_candidates as (
  select
    categories.id,
    categories.name,
    row_number() over (
      partition by categories.name
      order by categories.created_at desc, categories.id
    ) as rn
  from public.categories
  where categories.user_id = '08cccfe3-766f-43bd-b06c-8d909e0f9fe8'::uuid
    and categories.group_id is null
    and categories.name in (
      '욕실/위생',
      '주방/세제',
      '세탁/청소',
      '헤어/바디',
      '가전/필터'
    )
),
resolved_products as (
  select
    '08cccfe3-766f-43bd-b06c-8d909e0f9fe8'::uuid as user_id,
    category_candidates.id as category_id,
    curated_products.name,
    curated_products.brand,
    curated_products.replacement_cycle_days,
    (current_date - curated_products.created_days_ago)::timestamp with time zone + interval '10 hours' as created_at
  from curated_products
  cross join curate_dev_user_product_items_decision
  join category_candidates
    on category_candidates.name = curated_products.category_name
   and category_candidates.rn = 1
  where curate_dev_user_product_items_decision.should_replace
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

-- The current Flutter UI calculates D-day from purchase_date, so days_ago
-- drives the visible overdue/near-due/future spread. use_delay_days only keeps
-- use_started_on coherent for future consumers that distinguish actual use.
with curated_purchases(product_name, product_brand, days_ago, use_delay_days, price, store_name) as (
  values
    ('샤워기 필터', '바디럽', 289, 2, 17200, '네이버쇼핑'),
    ('샤워기 필터', '바디럽', 194, 2, 17500, '쿠팡'),
    ('샤워기 필터', '바디럽', 101, 3, 17900, '오늘의집'),

    ('정수기 필터', '코웨이', 354, 1, 34900, '코웨이몰'),
    ('정수기 필터', '코웨이', 263, 2, 35900, '쿠팡'),
    ('정수기 필터', '코웨이', 173, 1, 34500, '네이버쇼핑'),
    ('정수기 필터', '코웨이', 83, 2, 34900, '코웨이몰'),

    ('주방 세제', '자연퐁', 132, 0, 5200, '홈플러스'),
    ('주방 세제', '자연퐁', 98, 1, 4980, '이마트'),
    ('주방 세제', '자연퐁', 67, 0, 4700, '쿠팡'),
    ('주방 세제', '자연퐁', 31, 1, 4980, '이마트'),

    ('식기세척기 세제', '프로쉬', 181, 3, 11900, 'SSG닷컴'),
    ('식기세척기 세제', '프로쉬', 135, 4, 12200, '마켓컬리'),
    ('식기세척기 세제', '프로쉬', 88, 2, 11800, '쿠팡'),
    ('식기세척기 세제', '프로쉬', 44, 3, 11900, '쿠팡'),

    ('세탁 세제', '퍼실', 151, 4, 18500, '코스트코'),
    ('세탁 세제', '퍼실', 102, 3, 18900, 'SSG닷컴'),
    ('세탁 세제', '퍼실', 58, 5, 19200, '쿠팡'),
    ('세탁 세제', '퍼실', 11, 3, 18900, '쿠팡'),

    ('화장지', '코디', 137, 0, 16200, '이마트'),
    ('화장지', '코디', 101, 0, 15900, '쿠팡'),
    ('화장지', '코디', 65, 0, 16200, '이마트'),
    ('화장지', '코디', 33, 1, 15400, '쿠팡'),
    ('화장지', '코디', 6, 0, 15900, '마켓컬리'),

    ('치약', '덴티스테', 188, 3, 9500, '네이버쇼핑'),
    ('치약', '덴티스테', 121, 1, 9800, '쿠팡'),
    ('치약', '덴티스테', 55, 2, 9900, '올리브영'),

    ('샴푸', '케라시스', 195, 5, 13100, '롯데온'),
    ('샴푸', '케라시스', 129, 3, 12500, '쿠팡'),
    ('샴푸', '케라시스', 63, 4, 12900, '올리브영')
),
resolved_purchases as (
  select
    product_items.id as product_item_id,
    '08cccfe3-766f-43bd-b06c-8d909e0f9fe8'::uuid as purchased_by,
    (current_date - curated_purchases.days_ago)::date as purchase_date,
    (current_date - curated_purchases.days_ago + curated_purchases.use_delay_days)::date as use_started_on,
    curated_purchases.price,
    curated_purchases.store_name,
    (current_date - curated_purchases.days_ago)::timestamp with time zone + interval '13 hours' as created_at
  from curated_purchases
  cross join curate_dev_user_product_items_decision
  join public.product_items
    on product_items.user_id = '08cccfe3-766f-43bd-b06c-8d909e0f9fe8'::uuid
   and product_items.name = curated_purchases.product_name
   and product_items.brand = curated_purchases.product_brand
  where curate_dev_user_product_items_decision.should_replace
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
