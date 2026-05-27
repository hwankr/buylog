-- Track when a purchased item actually starts being used.
-- Existing rows default to purchase_date so current D-day behavior is preserved.

begin;

alter table public.purchases
  add column if not exists use_started_on date;

comment on column public.purchases.use_started_on is
  'Date this purchased product actually started being used/opened.';

update public.purchases
set use_started_on = purchase_date
where use_started_on is null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'purchases_use_started_on_after_purchase_date'
      and conrelid = 'public.purchases'::regclass
  ) then
    alter table public.purchases
      add constraint purchases_use_started_on_after_purchase_date
      check (use_started_on is null or use_started_on >= purchase_date);
  end if;
end $$;

create index if not exists purchases_product_item_use_started_on_idx
on public.purchases (product_item_id, use_started_on desc)
where use_started_on is not null;

commit;
