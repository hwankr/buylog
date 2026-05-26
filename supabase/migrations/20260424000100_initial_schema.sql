-- ============================================
-- Buylog DB Migration
-- 테이블 생성 + 시스템 기본 카테고리 seed
-- Supabase SQL Editor에서 실행
-- ============================================


-- =========================
-- 1. users
-- =========================
create table public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  display_name text,
  avatar_url text,
  fcm_token text,
  notification_enabled boolean default true,
  default_group_id uuid,  -- FK는 groups 생성 후 추가
  created_at timestamptz default now()
);

comment on table public.users is '사용자 프로필 정보 (auth.users와 1:1)';


-- =========================
-- 2. groups
-- =========================
create table public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  invite_code text unique,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz default now()
);

comment on table public.groups is '가구/동아리 등 그룹';

-- users.default_group_id FK 추가
alter table public.users
  add constraint fk_users_default_group
  foreign key (default_group_id) references public.groups(id) on delete set null;


-- =========================
-- 3. group_members
-- =========================
create table public.group_members (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  role text not null default 'member',
  joined_at timestamptz default now(),
  unique(group_id, user_id)  -- 같은 그룹에 중복 가입 방지
);

comment on table public.group_members is '그룹 ↔ 사용자 연결 (N:M)';


-- =========================
-- 4. categories
-- =========================
create table public.categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete cascade,
  group_id uuid references public.groups(id) on delete cascade,
  name text not null,
  icon text,
  color text,
  sort_order int default 0,
  created_at timestamptz default now()
);

comment on table public.categories is '소모품 카테고리 (user_id, group_id 모두 null이면 시스템 기본)';


-- =========================
-- 5. product_items
-- =========================
create table public.product_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete cascade,
  group_id uuid references public.groups(id) on delete cascade,
  category_id uuid not null references public.categories(id) on delete restrict,
  name text not null,
  brand text,
  barcode text,
  memo text,
  image_url text,
  replacement_cycle_days int,
  registered_by uuid references public.users(id) on delete set null,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  -- user_id 또는 group_id 중 하나만 값이 있어야 함
  constraint chk_product_owner check (
    (user_id is not null and group_id is null) or
    (user_id is null and group_id is not null)
  )
);

comment on table public.product_items is '등록된 소모품 (핵심 테이블)';

-- updated_at 자동 갱신 트리거
create or replace function update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger trg_product_items_updated_at
  before update on public.product_items
  for each row execute function update_updated_at();


-- =========================
-- 6. purchases
-- =========================
create table public.purchases (
  id uuid primary key default gen_random_uuid(),
  product_item_id uuid not null references public.product_items(id) on delete cascade,
  purchased_by uuid references public.users(id) on delete set null,
  purchase_date date not null,
  price int not null,
  store_name text,
  quantity int default 1,
  memo text,
  receipt_image_url text,
  created_at timestamptz default now()
);

comment on table public.purchases is '구매 이력';


-- =========================
-- 7. ocr_scans
-- =========================
create table public.ocr_scans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  image_url text not null,
  raw_result jsonb,
  parsed_data jsonb,
  status text default 'pending' check (status in ('pending', 'confirmed', 'rejected')),
  product_item_id uuid references public.product_items(id) on delete set null,
  purchase_id uuid references public.purchases(id) on delete set null,
  created_at timestamptz default now()
);

comment on table public.ocr_scans is 'OCR 영수증 스캔 임시 결과';


-- =========================
-- 8. ai_predictions
-- =========================
create table public.ai_predictions (
  id uuid primary key default gen_random_uuid(),
  product_item_id uuid not null references public.product_items(id) on delete cascade,
  predicted_replacement_date date,
  predicted_cycle_days int,
  predicted_cost int,
  recommendation jsonb,
  confidence float,
  created_at timestamptz default now()
);

comment on table public.ai_predictions is 'AI 교체주기 예측 결과';


-- =========================
-- 9. notifications
-- =========================
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  product_item_id uuid references public.product_items(id) on delete set null,
  type text not null check (type in ('replacement', 'price_drop', 'report')),
  title text not null,
  body text not null,
  is_read boolean default false,
  created_at timestamptz default now()
);

comment on table public.notifications is '푸시 알림 기록';


-- ============================================
-- 시스템 기본 카테고리 seed 데이터
-- user_id = null, group_id = null → 모든 사용자에게 보임
-- ============================================
insert into public.categories (name, icon, color, sort_order) values
  ('미분류',    '📦', '#888888', 0),
  ('위생용품',  '🧴', '#4A90D9', 1),
  ('주방용품',  '🍳', '#E8913A', 2),
  ('필터류',    '💧', '#45B7D1', 3),
  ('세탁용품',  '👕', '#9B59B6', 4),
  ('생활잡화',  '🏠', '#2ECC71', 5);
