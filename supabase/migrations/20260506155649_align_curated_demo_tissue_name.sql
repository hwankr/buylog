-- Align the curated demo dataset with the documented household product name.
--
-- The first curated demo seed used "휴지" for the tissue item. The approved
-- product set names the item "화장지", so this migration corrects only the
-- deterministic demo user's row.

update public.product_items
set
  name = '화장지',
  updated_at = now()
where user_id = '00000000-0000-4000-8000-000000000101'::uuid
  and name = '휴지'
  and brand = '코디';
