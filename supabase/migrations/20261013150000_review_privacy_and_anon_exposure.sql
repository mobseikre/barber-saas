-- Reviews are private to the customer, the reviewed barber and the admin

drop policy reviews_read on public.reviews;
create policy reviews_read_parties on public.reviews for select
  using (customer_id = auth.uid() or barber_id = current_barber_id());
revoke all on public.reviews from anon;

-- Review tags come from a fixed list

create function public.review_tags() returns text[]
language sql immutable as $$ select array['جودة القص', 'النظافة', 'الالتزام بالموعد', 'حسن التعامل', 'السعر مناسب'] $$;

create function public.review_max_tags() returns int
language sql immutable as $$ select 5 $$;

alter table public.reviews drop constraint reviews_tags_size;
alter table public.reviews
  add constraint reviews_tags_size check (cardinality(tags) <= review_max_tags() and char_length(array_to_string(tags, ',')) <= 100),
  add constraint reviews_tags_allowed check (tags <@ review_tags());

-- Free slots exist only for bookable barbers

create or replace function public.get_available_slots(p_barber_id uuid, p_date date, p_duration_min int)
returns table (starts_at timestamptz, ends_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
declare
  v_tz text := app_timezone();
  v_weekday smallint := extract(dow from p_date)::smallint;
  v_hours working_hours%rowtype;
  v_closure day_closures%rowtype;
  v_close timestamptz;
  v_closed_from timestamptz;
  v_slot timestamptz;
  v_range tstzrange;
begin
  if p_duration_min is null or p_duration_min <= 0 or not is_barber_bookable(p_barber_id) then
    return;
  end if;

  select * into v_hours from working_hours where barber_id = p_barber_id and weekday = v_weekday;
  if v_hours.barber_id is null or v_hours.is_closed then
    return;
  end if;

  select * into v_closure from day_closures where barber_id = p_barber_id and date = p_date;
  if v_closure.id is not null then
    if v_closure.from_time is null then
      return;
    end if;
    v_closed_from := (p_date + v_closure.from_time) at time zone v_tz;
  end if;

  v_slot := (p_date + v_hours.opens_at) at time zone v_tz;
  v_close := (p_date + v_hours.closes_at) at time zone v_tz;

  while v_slot + make_interval(mins => p_duration_min) <= v_close loop
    v_range := tstzrange(v_slot, v_slot + make_interval(mins => p_duration_min), '[)');
    if v_slot > now()
      and (v_closed_from is null or upper(v_range) <= v_closed_from)
      and not exists (
        select 1 from breaks b
        where b.barber_id = p_barber_id
          and (b.weekday is null or b.weekday = v_weekday)
          and v_range && tstzrange((p_date + b.starts_at) at time zone v_tz, (p_date + b.ends_at) at time zone v_tz, '[)')
      )
      and not exists (
        select 1 from bookings k
        where k.barber_id = p_barber_id and k.status <> 'cancelled' and k.time_range && v_range
      )
    then
      starts_at := v_slot;
      ends_at := upper(v_range);
      return next;
    end if;
    v_slot := v_slot + interval '15 minutes';
  end loop;
end $$;

-- The auth email is derived from the phone and never changes

create function public.block_auth_email_change() returns trigger
language plpgsql as $$
begin
  if new.email is distinct from old.email then
    raise exception 'email_change_not_allowed';
  end if;
  return new;
end $$;

create trigger on_auth_user_email_change
before update of email on auth.users
for each row execute function public.block_auth_email_change();

-- Visitors read only the columns the public pages show

revoke select on public.barbers from anon;
grant select (id, salon_id, display_name, photo_url, is_vip, rating_avg, rating_count, created_at) on public.barbers to anon;

revoke select on public.salons from anon;
grant select (id, name, area_id, address, location, photos, created_at) on public.salons to anon;

revoke select on public.day_closures from anon;
grant select (id, barber_id, date, from_time, created_at) on public.day_closures to anon;

-- salon_barbers lists barbers who have been activated once

create or replace view public.salon_barbers with (security_invoker = false) as
  select b.id, b.salon_id, b.display_name, b.photo_url, b.is_vip, b.rating_avg, b.rating_count,
         is_barber_bookable(b.id) as is_bookable
  from barbers b
  where b.status in ('active', 'suspended');

-- Only signed-in users may list the avatars bucket

drop policy avatars_read on storage.objects;
create policy avatars_read on storage.objects for select to authenticated
  using (bucket_id = 'avatars');

-- created_at is set by the database

revoke insert, update on public.reviews from anon, authenticated;
grant insert (id, booking_id, barber_id, salon_id, customer_id, rating, tags, comment) on public.reviews to authenticated;
grant update (booking_id, barber_id, salon_id, customer_id, rating, tags, comment) on public.reviews to authenticated;

revoke insert, update on public.profiles from anon, authenticated;
grant insert (id, role, full_name, phone, avatar_url, city_id, no_show_count, blocked_at, blocked_by) on public.profiles to authenticated;
grant update (role, full_name, phone, avatar_url, city_id, no_show_count, blocked_at, blocked_by) on public.profiles to authenticated;

-- Profile names are bounded

create function public.full_name_max_length() returns int
language sql immutable as $$ select 60 $$;

alter table public.profiles
  add constraint profiles_full_name_length check (char_length(full_name) <= full_name_max_length());

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_role user_role;
  v_phone text := split_part(new.email, '@', 1);
  v_name text := coalesce(new.raw_user_meta_data ->> 'full_name', '');
begin
  if split_part(new.email, '@', 2) <> 'app.local' or v_phone !~ '^218[0-9]{9}$' then
    raise exception 'invalid_auth_email';
  end if;
  if char_length(v_name) > full_name_max_length() then
    raise exception 'full_name_too_long' using detail = format('full_name_max_length=%s', full_name_max_length());
  end if;
  v_role := case new.raw_user_meta_data ->> 'role' when 'barber' then 'barber' else 'customer' end;
  insert into profiles (id, role, full_name, phone)
  values (new.id, v_role, v_name, v_phone);
  return new;
end $$;
