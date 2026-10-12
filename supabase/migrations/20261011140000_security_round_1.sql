-- Sign-up: the phone is always the one the auth email was built from

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_role user_role;
begin
  v_role := case new.raw_user_meta_data ->> 'role' when 'barber' then 'barber' else 'customer' end;
  insert into profiles (id, role, full_name, phone)
  values (new.id, v_role, coalesce(new.raw_user_meta_data ->> 'full_name', ''), split_part(new.email, '@', 1));
  return new;
end $$;

-- Column guards

create or replace function public.guard_profile_update() returns trigger
language plpgsql as $$
begin
  if pg_trigger_depth() = 1 and auth.uid() is not null and not is_admin() and (
    new.role is distinct from old.role
    or new.phone is distinct from old.phone
    or new.no_show_count is distinct from old.no_show_count
    or new.blocked_at is distinct from old.blocked_at
    or new.blocked_by is distinct from old.blocked_by
  ) then
    raise exception 'admin_only';
  end if;
  return new;
end $$;

create or replace function public.guard_barber_update() returns trigger
language plpgsql as $$
begin
  if pg_trigger_depth() = 1 and auth.uid() is not null and not is_admin() and (
    new.status is distinct from old.status
    or new.subscription_ends_at is distinct from old.subscription_ends_at
    or new.is_vip is distinct from old.is_vip
    or new.profile_id is distinct from old.profile_id
    or new.salon_id is distinct from old.salon_id
    or new.rating_avg is distinct from old.rating_avg
    or new.rating_count is distinct from old.rating_count
  ) then
    raise exception 'admin_only';
  end if;
  return new;
end $$;

create or replace function public.fill_review_from_booking() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_booking bookings%rowtype;
begin
  select * into v_booking from bookings where id = new.booking_id;
  if v_booking.id is null or v_booking.status <> 'completed' then
    raise exception 'booking_not_completed';
  end if;
  if v_booking.customer_id is distinct from new.customer_id then
    raise exception 'review_customer_mismatch';
  end if;
  new.barber_id := v_booking.barber_id;
  new.salon_id := (select salon_id from barbers where id = v_booking.barber_id);
  return new;
end $$;

-- Barber registration: salon and barber row in one call, safe to retry

create function public.register_barber(
  p_display_name text,
  p_salon_id uuid default null,
  p_salon_name text default null,
  p_area_id uuid default null,
  p_address text default null,
  p_latitude double precision default null,
  p_longitude double precision default null
)
returns public.barbers
language plpgsql security definer set search_path = public as $$
declare
  v_profile profiles%rowtype;
  v_barber barbers%rowtype;
  v_salon_id uuid;
  v_name text := trim(coalesce(p_display_name, ''));
begin
  select * into v_profile from profiles where id = auth.uid() for update;
  if v_profile.id is null or v_profile.role <> 'barber' then
    raise exception 'not_a_barber';
  end if;

  select * into v_barber from barbers where profile_id = v_profile.id;
  if v_barber.id is not null then
    return v_barber;
  end if;

  if v_name = '' then
    raise exception 'display_name_required';
  end if;

  if p_salon_id is not null then
    select id into v_salon_id from salons where id = p_salon_id;
    if v_salon_id is null then
      raise exception 'salon_not_found';
    end if;
  else
    insert into salons (name, owner_id, area_id, address, location)
    values (
      coalesce(nullif(trim(p_salon_name), ''), 'صالون ' || v_name),
      v_profile.id,
      p_area_id,
      nullif(trim(p_address), ''),
      case when p_latitude is not null and p_longitude is not null
           then st_setsrid(st_makepoint(p_longitude, p_latitude), 4326)::geography end
    )
    returning id into v_salon_id;
  end if;

  insert into barbers (profile_id, salon_id, display_name)
  values (v_profile.id, v_salon_id, v_name)
  returning * into v_barber;
  return v_barber;
end $$;

-- Booking lifecycle

create or replace function public.create_booking(p_barber_id uuid, p_service_id uuid, p_starts_at timestamptz)
returns public.bookings
language plpgsql security definer set search_path = public as $$
declare
  v_customer profiles%rowtype;
  v_service barber_services%rowtype;
  v_booking bookings%rowtype;
begin
  select * into v_customer from profiles where id = auth.uid() for update;
  if v_customer.id is null or v_customer.role <> 'customer' then
    raise exception 'not_a_customer';
  end if;
  if v_customer.blocked_at is not null then
    raise exception 'customer_blocked' using detail = format('no_show_limit=%s', no_show_limit());
  end if;
  if (select count(*) from bookings
      where customer_id = v_customer.id and status = 'confirmed' and lower(time_range) > now())
     >= upcoming_booking_limit() then
    raise exception 'booking_limit_reached' using detail = format('upcoming_booking_limit=%s', upcoming_booking_limit());
  end if;
  if not is_barber_bookable(p_barber_id) then
    raise exception 'barber_not_bookable';
  end if;

  select * into v_service from barber_services
  where barber_id = p_barber_id and service_id = p_service_id and is_enabled;
  if v_service.barber_id is null then
    raise exception 'service_not_offered';
  end if;

  if not exists (
    select 1 from get_available_slots(p_barber_id, (p_starts_at at time zone app_timezone())::date, v_service.duration_min) s
    where s.starts_at = p_starts_at
  ) then
    raise exception 'slot_not_available';
  end if;

  insert into bookings (barber_id, customer_id, service_id, price, duration_min, time_range, source)
  values (p_barber_id, v_customer.id, p_service_id, v_service.price, v_service.duration_min,
          tstzrange(p_starts_at, p_starts_at + make_interval(mins => v_service.duration_min), '[)'), 'app')
  returning * into v_booking;
  return v_booking;
end $$;

create or replace function public.create_manual_booking(p_service_id uuid, p_starts_at timestamptz, p_customer_name text)
returns public.bookings
language plpgsql security definer set search_path = public as $$
declare
  v_barber_id uuid := current_barber_id();
  v_tz text := app_timezone();
  v_service barber_services%rowtype;
  v_hours working_hours%rowtype;
  v_closure day_closures%rowtype;
  v_date date;
  v_weekday smallint;
  v_range tstzrange;
  v_booking bookings%rowtype;
begin
  if v_barber_id is null then
    raise exception 'not_a_barber';
  end if;
  if coalesce(trim(p_customer_name), '') = '' then
    raise exception 'customer_name_required';
  end if;
  select * into v_service from barber_services
  where barber_id = v_barber_id and service_id = p_service_id and is_enabled;
  if v_service.barber_id is null then
    raise exception 'service_not_offered';
  end if;

  v_range := tstzrange(p_starts_at, p_starts_at + make_interval(mins => v_service.duration_min), '[)');
  if upper(v_range) <= now() then
    raise exception 'booking_in_past';
  end if;

  v_date := (p_starts_at at time zone v_tz)::date;
  v_weekday := extract(dow from v_date)::smallint;

  select * into v_hours from working_hours where barber_id = v_barber_id and weekday = v_weekday;
  if v_hours.barber_id is null or v_hours.is_closed
     or lower(v_range) < (v_date + v_hours.opens_at) at time zone v_tz
     or upper(v_range) > (v_date + v_hours.closes_at) at time zone v_tz then
    raise exception 'outside_working_hours';
  end if;

  if exists (
    select 1 from breaks b
    where b.barber_id = v_barber_id
      and (b.weekday is null or b.weekday = v_weekday)
      and v_range && tstzrange((v_date + b.starts_at) at time zone v_tz, (v_date + b.ends_at) at time zone v_tz, '[)')
  ) then
    raise exception 'inside_break';
  end if;

  select * into v_closure from day_closures where barber_id = v_barber_id and date = v_date;
  if v_closure.id is not null
     and (v_closure.from_time is null or upper(v_range) > (v_date + v_closure.from_time) at time zone v_tz) then
    raise exception 'day_closed';
  end if;

  insert into bookings (barber_id, customer_name, service_id, price, duration_min, time_range, source)
  values (v_barber_id, trim(p_customer_name), p_service_id, v_service.price, v_service.duration_min, v_range, 'manual')
  returning * into v_booking;
  return v_booking;
end $$;

create or replace function public.set_booking_status(p_booking_id uuid, p_status public.booking_status)
returns public.bookings
language plpgsql security definer set search_path = public as $$
declare
  v_booking bookings%rowtype;
begin
  if p_status not in ('confirmed', 'completed', 'no_show') then
    raise exception 'use_cancel_booking';
  end if;
  select * into v_booking from bookings where id = p_booking_id for update;
  if v_booking.id is null or (v_booking.barber_id is distinct from current_barber_id() and not is_admin()) then
    raise exception 'booking_not_found';
  end if;
  if v_booking.status = 'cancelled' then
    raise exception 'booking_cancelled';
  end if;
  if p_status in ('completed', 'no_show') and lower(v_booking.time_range) > now() then
    raise exception 'booking_not_started';
  end if;
  update bookings set status = p_status where id = p_booking_id returning * into v_booking;
  return v_booking;
end $$;

create or replace function public.cancel_booking(p_booking_id uuid, p_reason public.barber_cancel_reason default null, p_note text default null)
returns public.bookings
language plpgsql security definer set search_path = public as $$
declare
  v_booking bookings%rowtype;
  v_is_customer boolean;
  v_is_barber boolean;
begin
  select * into v_booking from bookings where id = p_booking_id for update;
  if v_booking.id is null then
    raise exception 'booking_not_found';
  end if;
  v_is_customer := coalesce(v_booking.customer_id = auth.uid(), false);
  v_is_barber := coalesce(v_booking.barber_id = current_barber_id(), false);
  if not (v_is_customer or v_is_barber or is_admin()) then
    raise exception 'booking_not_found';
  end if;
  if v_booking.status <> 'confirmed' then
    raise exception 'booking_not_confirmed';
  end if;

  if v_is_customer then
    if lower(v_booking.time_range) - now() < cancellation_window() then
      raise exception 'cancellation_window_passed'
        using detail = format('cancellation_window_minutes=%s', (extract(epoch from cancellation_window()) / 60)::int);
    end if;
    p_reason := null;
    p_note := null;
  elsif v_is_barber and p_reason is null then
    raise exception 'cancel_reason_required';
  end if;

  update bookings
  set status = 'cancelled', cancelled_at = now(), cancelled_by = auth.uid(),
      cancel_reason = p_reason, cancel_note = p_note
  where id = p_booking_id
  returning * into v_booking;
  return v_booking;
end $$;

create or replace function public.close_rest_of_today()
returns setof public.bookings
language plpgsql security definer set search_path = public as $$
declare
  v_barber_id uuid := current_barber_id();
  v_now_local timestamp := now() at time zone app_timezone();
begin
  if v_barber_id is null then
    raise exception 'not_a_barber';
  end if;

  insert into day_closures (barber_id, date, from_time, reason)
  values (v_barber_id, v_now_local::date, v_now_local::time, 'closed_early')
  on conflict (barber_id, date) do update
    set from_time = least(day_closures.from_time, excluded.from_time)
    where day_closures.from_time is not null;

  return query
    select * from bookings
    where barber_id = v_barber_id
      and status = 'confirmed'
      and lower(time_range) > now()
      and lower(time_range) < (v_now_local::date + 1) at time zone app_timezone()
    order by lower(time_range);
end $$;

create function public.reopen_today()
returns boolean
language plpgsql security definer set search_path = public as $$
declare
  v_barber_id uuid := current_barber_id();
  v_deleted int;
begin
  if v_barber_id is null then
    raise exception 'not_a_barber';
  end if;
  delete from day_closures
  where barber_id = v_barber_id and date = (now() at time zone app_timezone())::date;
  get diagnostics v_deleted = row_count;
  return v_deleted > 0;
end $$;

-- Admin actions

create or replace function public.activate_subscription(p_barber_id uuid, p_months int, p_amount numeric, p_note text default null)
returns public.barbers
language plpgsql security definer set search_path = public as $$
declare
  v_barber barbers%rowtype;
  v_start timestamptz;
begin
  if not is_admin() then
    raise exception 'admin_only';
  end if;
  if p_months is null or p_months <= 0 then
    raise exception 'invalid_months';
  end if;
  select * into v_barber from barbers where id = p_barber_id for update;
  if v_barber.id is null then
    raise exception 'barber_not_found';
  end if;
  if v_barber.profile_id is null then
    raise exception 'barber_has_no_account';
  end if;

  v_start := greatest(now(), coalesce(v_barber.subscription_ends_at, now()));
  insert into subscription_payments (barber_id, amount, period_start, period_end, recorded_by, note)
  values (p_barber_id, p_amount, v_start, v_start + make_interval(months => p_months), auth.uid(), p_note);

  update barbers
  set status = 'active', subscription_ends_at = v_start + make_interval(months => p_months)
  where id = p_barber_id
  returning * into v_barber;
  return v_barber;
end $$;

create or replace function public.unblock_customer(p_profile_id uuid)
returns public.profiles
language plpgsql security definer set search_path = public as $$
declare
  v_profile profiles%rowtype;
begin
  if not is_admin() then
    raise exception 'admin_only';
  end if;
  update profiles
  set blocked_at = null, blocked_by = null, no_show_count = 0
  where id = p_profile_id
  returning * into v_profile;
  if v_profile.id is null then
    raise exception 'customer_not_found';
  end if;
  return v_profile;
end $$;

-- Policies

drop policy barbers_insert_own on public.barbers;
create policy barbers_insert_own on public.barbers for insert
  with check (
    profile_id = auth.uid()
    and status = 'pending'
    and subscription_ends_at is null
    and not is_vip
    and rating_avg = 0
    and rating_count = 0
    and exists (select 1 from profiles where id = auth.uid() and role = 'barber')
  );

drop policy salons_insert_barber on public.salons;
create policy salons_insert_active_barber on public.salons for insert
  with check (
    owner_id = auth.uid()
    and exists (select 1 from barbers where profile_id = auth.uid() and status = 'active')
  );

-- Public directory: barbers and their salon, kept visible after a subscription lapses

create view public.barber_directory with (security_invoker = false) as
  select b.id, b.salon_id, b.display_name, b.photo_url, b.is_vip, b.rating_avg, b.rating_count,
         is_barber_bookable(b.id) as is_bookable,
         p.phone,
         s.name as salon_name, s.area_id, s.address,
         st_y(s.location::geometry) as latitude, st_x(s.location::geometry) as longitude,
         s.photos as salon_photos
  from barbers b
  join salons s on s.id = b.salon_id
  left join profiles p on p.id = b.profile_id
  where b.status <> 'rejected';

-- Views are read-only for clients

revoke all on public.salon_barbers, public.salon_hours, public.admin_barber_cancellations, public.barber_directory
  from public, anon;
revoke insert, update, delete, truncate
  on public.salon_barbers, public.salon_hours, public.admin_barber_cancellations, public.barber_directory
  from authenticated;
grant select on public.barber_directory to authenticated;

-- RPCs need a session

revoke execute on function public.register_barber(text, uuid, text, uuid, text, double precision, double precision) from public, anon;
revoke execute on function public.reopen_today() from public, anon;
revoke execute on function public.activate_subscription(uuid, int, numeric, text) from public, anon;
revoke execute on function public.unblock_customer(uuid) from public, anon;
revoke execute on function public.create_booking(uuid, uuid, timestamptz) from public, anon;
revoke execute on function public.create_manual_booking(uuid, timestamptz, text) from public, anon;
revoke execute on function public.set_booking_status(uuid, public.booking_status) from public, anon;
revoke execute on function public.cancel_booking(uuid, public.barber_cancel_reason, text) from public, anon;
revoke execute on function public.close_rest_of_today() from public, anon;

-- Profile photos: public bucket, one folder per user

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy avatars_read on storage.objects for select
  using (bucket_id = 'avatars');
create policy avatars_insert_own on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy avatars_update_own on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy avatars_delete_own on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
