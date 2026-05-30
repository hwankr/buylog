begin;

alter table public.product_items
  add column vision_tracking_enabled boolean not null default false,
  add column vision_measure_interval_minutes int not null default 360,
  add column vision_last_measured_at timestamptz,
  add constraint product_items_vision_measure_interval_minutes_check
    check (
      vision_measure_interval_minutes in (60, 180, 360, 720, 1440)
    );

comment on column public.product_items.vision_tracking_enabled is
  'Whether MIDAS camera vision inventory tracking is enabled for this product.';
comment on column public.product_items.vision_measure_interval_minutes is
  'Minimum minutes between vision inventory snapshot updates for this product.';
comment on column public.product_items.vision_last_measured_at is
  'Last observation timestamp that updated this product from vision tracking.';

commit;
