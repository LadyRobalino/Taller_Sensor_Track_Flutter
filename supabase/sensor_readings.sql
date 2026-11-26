-- Ejecutar en un proyecto nuevo de Supabase.
begin;

create table public.sensor_readings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  sensor_type text not null check (sensor_type in ('accelerometer', 'gyroscope', 'gps')),
  x double precision,
  y double precision,
  z double precision,
  latitude double precision,
  longitude double precision,
  accuracy double precision,
  recorded_at timestamptz not null default now(),
  constraint reading_values_match_sensor check (
    (sensor_type in ('accelerometer', 'gyroscope')
      and x is not null and y is not null and z is not null
      and latitude is null and longitude is null and accuracy is null)
    or
    (sensor_type = 'gps' and x is null and y is null and z is null
      and latitude is not null and longitude is not null and accuracy is not null
      and latitude between -90 and 90 and longitude between -180 and 180 and accuracy >= 0)
  )
);

create index sensor_readings_owner_time_idx
  on public.sensor_readings (user_id, recorded_at, id);

alter table public.sensor_readings enable row level security;
revoke all on public.sensor_readings from anon, authenticated;
grant select, insert on public.sensor_readings to authenticated;

create policy readings_select_own on public.sensor_readings
  for select to authenticated using ((select auth.uid()) = user_id);
create policy readings_insert_own on public.sensor_readings
  for insert to authenticated with check ((select auth.uid()) = user_id);

commit;
