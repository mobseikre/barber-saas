-- Constants

create function public.no_show_limit() returns int
language sql immutable as $$ select 3 $$;

create function public.upcoming_booking_limit() returns int
language sql immutable as $$ select 2 $$;

create function public.cancellation_window() returns interval
language sql immutable as $$ select interval '2 hours' $$;

create function public.app_timezone() returns text
language sql immutable as $$ select 'Africa/Tripoli' $$;

-- Identity helpers

create function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid() and role = 'admin')
$$;

create function public.current_barber_id() returns uuid
language sql stable security definer set search_path = public as $$
  select id from barbers where profile_id = auth.uid()
$$;

create function public.is_barber_bookable(p_barber_id uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from barbers
    where id = p_barber_id
      and status = 'active'
      and profile_id is not null
      and subscription_ends_at > now()
  )
$$;

-- Profile creation from auth sign-up

create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_role user_role;
  v_phone text;
begin
  v_role := case new.raw_user_meta_data ->> 'role' when 'barber' then 'barber' else 'customer' end;
  v_phone := coalesce(new.raw_user_meta_data ->> 'phone', split_part(new.email, '@', 1));
  insert into profiles (id, role, full_name, phone)
  values (new.id, v_role, coalesce(new.raw_user_meta_data ->> 'full_name', ''), v_phone);
  return new;
end $$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- Column guards: only admins may change privileged columns directly

create function public.guard_profile_update() returns trigger
language plpgsql as $$
begin
  if pg_trigger_depth() = 1 and auth.uid() is not null and not is_admin() and (
    new.role is distinct from old.role
    or new.no_show_count is distinct from old.no_show_count
    or new.blocked_at is distinct from old.blocked_at
    or new.blocked_by is distinct from old.blocked_by
  ) then
    raise exception 'only admins can change role or block state';
  end if;
  return new;
end $$;

create trigger profiles_guard before update on public.profiles
for each row execute function public.guard_profile_update();

create function public.guard_barber_update() returns trigger
language plpgsql as $$
begin
  if pg_trigger_depth() = 1 and auth.uid() is not null and not is_admin() and (
    new.status is distinct from old.status
    or new.subscription_ends_at is distinct from old.subscription_ends_at
    or new.is_vip is distinct from old.is_vip
    or new.profile_id is distinct from old.profile_id
    or new.rating_avg is distinct from old.rating_avg
    or new.rating_count is distinct from old.rating_count
  ) then
    raise exception 'only admins can change barber status, subscription or VIP';
  end if;
  return new;
end $$;

create trigger barbers_guard before update on public.barbers
for each row execute function public.guard_barber_update();

-- No-show tracking

create function public.track_no_shows() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.customer_id is null or new.status = old.status then
    return new;
  end if;
  if new.status = 'no_show' then
    update profiles
    set no_show_count = no_show_count + 1,
        blocked_at = case when no_show_count + 1 >= no_show_limit() then coalesce(blocked_at, now()) else blocked_at end
    where id = new.customer_id;
  elsif old.status = 'no_show' and new.status in ('completed', 'confirmed') then
    update profiles
    set no_show_count = greatest(no_show_count - 1, 0)
    where id = new.customer_id;
  end if;
  return new;
end $$;

create trigger bookings_track_no_shows after update of status on public.bookings
for each row execute function public.track_no_shows();

-- Ratings

create function public.refresh_barber_rating() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_barber_id uuid := coalesce(new.barber_id, old.barber_id);
begin
  update barbers b
  set rating_avg = coalesce((select round(avg(rating), 2) from reviews where barber_id = v_barber_id), 0),
      rating_count = (select count(*) from reviews where barber_id = v_barber_id)
  where b.id = v_barber_id;
  return null;
end $$;

create trigger reviews_refresh_rating after insert or update or delete on public.reviews
for each row execute function public.refresh_barber_rating();

create function public.fill_review_from_booking() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_booking bookings%rowtype;
begin
  select * into v_booking from bookings where id = new.booking_id;
  if v_booking.id is null or v_booking.status <> 'completed' then
    raise exception 'only completed bookings can be reviewed';
  end if;
  if v_booking.customer_id is distinct from new.customer_id then
    raise exception 'review must belong to the booking customer';
  end if;
  new.barber_id := v_booking.barber_id;
  new.salon_id := (select salon_id from barbers where id = v_booking.barber_id);
  return new;
end $$;

create trigger reviews_fill_from_booking before insert on public.reviews
for each row execute function public.fill_review_from_booking();

-- Availability

create function public.get_available_slots(p_barber_id uuid, p_date date, p_duration_min int)
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
  if p_duration_min is null or p_duration_min <= 0 then
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

-- Booking lifecycle

create function public.create_booking(p_barber_id uuid, p_service_id uuid, p_starts_at timestamptz)
returns public.bookings
language plpgsql security definer set search_path = public as $$
declare
  v_customer profiles%rowtype;
  v_service barber_services%rowtype;
  v_booking bookings%rowtype;
begin
  select * into v_customer from profiles where id = auth.uid();
  if v_customer.id is null or v_customer.role <> 'customer' then
    raise exception 'only customers can book';
  end if;
  if v_customer.blocked_at is not null then
    raise exception 'customer is blocked after % no-shows', no_show_limit();
  end if;
  if (select count(*) from bookings
      where customer_id = v_customer.id and status = 'confirmed' and lower(time_range) > now())
     >= upcoming_booking_limit() then
    raise exception 'customer already has % upcoming bookings', upcoming_booking_limit();
  end if;
  if not is_barber_bookable(p_barber_id) then
    raise exception 'barber is not bookable';
  end if;

  select * into v_service from barber_services
  where barber_id = p_barber_id and service_id = p_service_id and is_enabled;
  if v_service.barber_id is null then
    raise exception 'service is not offered by this barber';
  end if;

  if not exists (
    select 1 from get_available_slots(p_barber_id, (p_starts_at at time zone app_timezone())::date, v_service.duration_min) s
    where s.starts_at = p_starts_at
  ) then
    raise exception 'slot is not available';
  end if;

  insert into bookings (barber_id, customer_id, service_id, price, duration_min, time_range, source)
  values (p_barber_id, v_customer.id, p_service_id, v_service.price, v_service.duration_min,
          tstzrange(p_starts_at, p_starts_at + make_interval(mins => v_service.duration_min), '[)'), 'app')
  returning * into v_booking;
  return v_booking;
end $$;

create function public.create_manual_booking(p_service_id uuid, p_starts_at timestamptz, p_customer_name text)
returns public.bookings
language plpgsql security definer set search_path = public as $$
declare
  v_barber_id uuid := current_barber_id();
  v_service barber_services%rowtype;
  v_booking bookings%rowtype;
begin
  if v_barber_id is null then
    raise exception 'only barbers can add manual bookings';
  end if;
  if coalesce(trim(p_customer_name), '') = '' then
    raise exception 'customer name is required';
  end if;
  select * into v_service from barber_services
  where barber_id = v_barber_id and service_id = p_service_id and is_enabled;
  if v_service.barber_id is null then
    raise exception 'service is not offered by this barber';
  end if;
  if p_starts_at + make_interval(mins => v_service.duration_min) <= now() then
    raise exception 'booking is in the past';
  end if;

  insert into bookings (barber_id, customer_name, service_id, price, duration_min, time_range, source)
  values (v_barber_id, trim(p_customer_name), p_service_id, v_service.price, v_service.duration_min,
          tstzrange(p_starts_at, p_starts_at + make_interval(mins => v_service.duration_min), '[)'), 'manual')
  returning * into v_booking;
  return v_booking;
end $$;

create function public.set_booking_status(p_booking_id uuid, p_status public.booking_status)
returns public.bookings
language plpgsql security definer set search_path = public as $$
declare
  v_booking bookings%rowtype;
begin
  if p_status not in ('confirmed', 'completed', 'no_show') then
    raise exception 'use cancel_booking to cancel';
  end if;
  select * into v_booking from bookings where id = p_booking_id for update;
  if v_booking.id is null or (v_booking.barber_id <> current_barber_id() and not is_admin()) then
    raise exception 'booking not found';
  end if;
  if v_booking.status = 'cancelled' then
    raise exception 'cancelled bookings cannot change status';
  end if;
  update bookings set status = p_status where id = p_booking_id returning * into v_booking;
  return v_booking;
end $$;

create function public.cancel_booking(p_booking_id uuid, p_reason public.barber_cancel_reason default null, p_note text default null)
returns public.bookings
language plpgsql security definer set search_path = public as $$
declare
  v_booking bookings%rowtype;
  v_is_customer boolean;
  v_is_barber boolean;
begin
  select * into v_booking from bookings where id = p_booking_id for update;
  if v_booking.id is null then
    raise exception 'booking not found';
  end if;
  v_is_customer := v_booking.customer_id = auth.uid();
  v_is_barber := v_booking.barber_id = current_barber_id();
  if not (v_is_customer or v_is_barber or is_admin()) then
    raise exception 'booking not found';
  end if;
  if v_booking.status <> 'confirmed' then
    raise exception 'only confirmed bookings can be cancelled';
  end if;

  if v_is_customer then
    if lower(v_booking.time_range) - now() < cancellation_window() then
      raise exception 'bookings can only be cancelled up to % before the start', cancellation_window();
    end if;
    p_reason := null;
    p_note := null;
  elsif v_is_barber and p_reason is null then
    raise exception 'barber cancellations require a reason';
  end if;

  update bookings
  set status = 'cancelled', cancelled_at = now(), cancelled_by = auth.uid(),
      cancel_reason = p_reason, cancel_note = p_note
  where id = p_booking_id
  returning * into v_booking;
  return v_booking;
end $$;

create function public.close_rest_of_today()
returns setof public.bookings
language plpgsql security definer set search_path = public as $$
declare
  v_barber_id uuid := current_barber_id();
  v_now_local timestamp := now() at time zone app_timezone();
begin
  if v_barber_id is null then
    raise exception 'only barbers can close their day';
  end if;

  insert into day_closures (barber_id, date, from_time, reason)
  values (v_barber_id, v_now_local::date, v_now_local::time, 'closed early')
  on conflict (barber_id, date) do update
    set from_time = least(day_closures.from_time, excluded.from_time)
    where day_closures.from_time is not null;

  return query
    select * from bookings
    where barber_id = v_barber_id
      and status = 'confirmed'
      and time_range && tstzrange(now(), (v_now_local::date + 1) at time zone app_timezone(), '[)')
    order by lower(time_range);
end $$;

-- Admin actions

create function public.activate_subscription(p_barber_id uuid, p_months int, p_amount numeric, p_note text default null)
returns public.barbers
language plpgsql security definer set search_path = public as $$
declare
  v_barber barbers%rowtype;
  v_start timestamptz;
begin
  if not is_admin() then
    raise exception 'only admins can activate subscriptions';
  end if;
  if p_months is null or p_months <= 0 then
    raise exception 'months must be positive';
  end if;
  select * into v_barber from barbers where id = p_barber_id for update;
  if v_barber.id is null then
    raise exception 'barber not found';
  end if;
  if v_barber.profile_id is null then
    raise exception 'barber has no account';
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

create function public.unblock_customer(p_profile_id uuid)
returns public.profiles
language plpgsql security definer set search_path = public as $$
declare
  v_profile profiles%rowtype;
begin
  if not is_admin() then
    raise exception 'only admins can unblock customers';
  end if;
  update profiles
  set blocked_at = null, blocked_by = null, no_show_count = 0
  where id = p_profile_id
  returning * into v_profile;
  if v_profile.id is null then
    raise exception 'customer not found';
  end if;
  return v_profile;
end $$;

-- Views

create view public.salon_barbers with (security_invoker = false) as
  select b.id, b.salon_id, b.display_name, b.photo_url, b.is_vip, b.rating_avg, b.rating_count,
         is_barber_bookable(b.id) as is_bookable
  from barbers b
  where b.status in ('active', 'pending', 'suspended');

create view public.salon_hours with (security_invoker = false) as
  select b.salon_id, w.weekday, min(w.opens_at) as opens_at, max(w.closes_at) as closes_at
  from working_hours w
  join barbers b on b.id = w.barber_id
  where not w.is_closed and is_barber_bookable(b.id)
  group by b.salon_id, w.weekday;

create view public.admin_barber_cancellations with (security_invoker = true) as
  select b.id as barber_id, b.display_name, b.salon_id,
         count(k.id) as cancelled_total,
         count(k.id) filter (where k.cancel_reason = 'sick') as sick,
         count(k.id) filter (where k.cancel_reason = 'emergency') as emergency,
         count(k.id) filter (where k.cancel_reason = 'other') as other
  from barbers b
  left join bookings k on k.barber_id = b.id and k.status = 'cancelled' and k.cancelled_by = b.profile_id
  group by b.id;
