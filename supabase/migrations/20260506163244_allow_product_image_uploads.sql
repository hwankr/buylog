-- Allow the Flutter app to upload product images without a client-side
-- service-role key. The bucket is public for reads, while write policies are
-- scoped to the product image path prefix used by SupabaseService.

begin;

insert into storage.buckets (
  id,
  name,
  public
)
values (
  'product-images',
  'product-images',
  true
)
on conflict (id) do update
set
  name = excluded.name,
  public = excluded.public;

drop policy if exists "Public read product images" on storage.objects;
drop policy if exists "Upload product images" on storage.objects;
drop policy if exists "Update product images" on storage.objects;

create policy "Public read product images"
on storage.objects
for select
to anon, authenticated
using (
  bucket_id = 'product-images'
);

create policy "Upload product images"
on storage.objects
for insert
to anon, authenticated
with check (
  bucket_id = 'product-images'
  and name like 'items/%'
);

create policy "Update product images"
on storage.objects
for update
to anon, authenticated
using (
  bucket_id = 'product-images'
  and name like 'items/%'
)
with check (
  bucket_id = 'product-images'
  and name like 'items/%'
);

commit;
