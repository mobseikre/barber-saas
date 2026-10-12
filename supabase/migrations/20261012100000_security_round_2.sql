-- Sign-up: only the app's internal emails may create a profile

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_role user_role;
  v_phone text := split_part(new.email, '@', 1);
begin
  if split_part(new.email, '@', 2) <> 'app.local' or v_phone !~ '^218[0-9]{9}$' then
    raise exception 'invalid_auth_email';
  end if;
  v_role := case new.raw_user_meta_data ->> 'role' when 'barber' then 'barber' else 'customer' end;
  insert into profiles (id, role, full_name, phone)
  values (new.id, v_role, coalesce(new.raw_user_meta_data ->> 'full_name', ''), v_phone);
  return new;
end $$;

-- Constants

create function public.customer_name_max_length() returns int
language sql immutable as $$ select 60 $$;

create function public.note_max_length() returns int
language sql immutable as $$ select 200 $$;

-- Column constraints

alter table public.bookings
  add constraint bookings_customer_name_length check (char_length(customer_name) <= customer_name_max_length()),
  add constraint bookings_cancel_note_length check (char_length(cancel_note) <= note_max_length());

alter table public.day_closures
  add constraint day_closures_reason_length check (char_length(reason) <= note_max_length());

alter table public.profiles
  add constraint profiles_avatar_url_path check (avatar_url like 'avatars/%');

alter table public.barbers
  add constraint barbers_photo_url_path check (photo_url like 'avatars/%');

-- Pending barbers may set up their chair, but only active barbers run a day

create function public.active_barber_id() returns uuid
language plpgsql stable security definer set search_path = public as $$
declare
  v_barber barbers%rowtype;
begin
  select * into v_barber from barbers where profile_id = auth.uid();
  if v_barber.id is null then
    raise exception 'not_a_barber';
  end if;
  if v_barber.status <> 'active' then
    raise exception 'barber_not_active';
  end if;
  return v_barber.id;
end $$;

create or replace function public.create_manual_booking(p_service_id uuid, p_starts_at timestamptz, p_customer_name text)
returns public.bookings
language plpgsql security definer set search_path = public as $$
declare
  v_barber_id uuid := active_barber_id();
  v_tz text := app_timezone();
  v_name text := trim(coalesce(p_customer_name, ''));
  v_service barber_services%rowtype;
  v_hours working_hours%rowtype;
  v_closure day_closures%rowtype;
  v_date date;
  v_weekday smallint;
  v_range tstzrange;
  v_booking bookings%rowtype;
begin
  if v_name = '' then
    raise exception 'customer_name_required';
  end if;
  if char_length(v_name) > customer_name_max_length() then
    raise exception 'customer_name_too_long' using detail = format('customer_name_max_length=%s', customer_name_max_length());
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
  values (v_barber_id, v_name, p_service_id, v_service.price, v_service.duration_min, v_range, 'manual')
  returning * into v_booking;
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
  p_note := nullif(trim(coalesce(p_note, '')), '');
  if char_length(p_note) > note_max_length() then
    raise exception 'cancel_note_too_long' using detail = format('note_max_length=%s', note_max_length());
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
  v_barber_id uuid := active_barber_id();
  v_now_local timestamp := now() at time zone app_timezone();
begin
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
      and lower(time_range) < (v_now_local::date + 1)::timestamp at time zone app_timezone()
    order by lower(time_range);
end $$;

create or replace function public.reopen_today()
returns boolean
language plpgsql security definer set search_path = public as $$
declare
  v_barber_id uuid := active_barber_id();
  v_deleted int;
begin
  delete from day_closures
  where barber_id = v_barber_id and date = (now() at time zone app_timezone())::date;
  get diagnostics v_deleted = row_count;
  return v_deleted > 0;
end $$;

create or replace function public.barber_stats(p_at timestamptz default now())
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_barber_id uuid := active_barber_id();
  v_tz text := app_timezone();
  v_today date := (p_at at time zone v_tz)::date;
  v_day_start timestamptz := v_today::timestamp at time zone v_tz;
  v_day_end timestamptz := (v_today + 1)::timestamp at time zone v_tz;
  v_month_start timestamptz := date_trunc('month', v_today::timestamp) at time zone v_tz;
  v_month_end timestamptz := (date_trunc('month', v_today::timestamp) + interval '1 month') at time zone v_tz;
begin
  return jsonb_build_object(
    'today_customers', (
      select count(*) from bookings
      where barber_id = v_barber_id and status <> 'cancelled' and lower(time_range) >= v_day_start and lower(time_range) < v_day_end),
    'today_completed', (
      select count(*) from bookings
      where barber_id = v_barber_id and status = 'completed' and lower(time_range) >= v_day_start and lower(time_range) < v_day_end),
    'today_no_show', (
      select count(*) from bookings
      where barber_id = v_barber_id and status = 'no_show' and lower(time_range) >= v_day_start and lower(time_range) < v_day_end),
    'today_income', (
      select coalesce(sum(price), 0) from bookings
      where barber_id = v_barber_id and status = 'completed' and lower(time_range) >= v_day_start and lower(time_range) < v_day_end),
    'month_customers', (
      select count(*) from bookings
      where barber_id = v_barber_id and status <> 'cancelled' and lower(time_range) >= v_month_start and lower(time_range) < v_month_end),
    'month_income', (
      select coalesce(sum(price), 0) from bookings
      where barber_id = v_barber_id and status = 'completed' and lower(time_range) >= v_month_start and lower(time_range) < v_month_end),
    'top_services', coalesce((
      select jsonb_agg(jsonb_build_object('name_ar', s.name_ar, 'count', s.total) order by s.total desc, s.name_ar)
      from (
        select c.name_ar, count(*) as total
        from bookings k
        join service_catalog c on c.id = k.service_id
        where k.barber_id = v_barber_id and k.status <> 'cancelled'
          and lower(k.time_range) >= v_month_start and lower(k.time_range) < v_month_end
        group by c.name_ar
        order by count(*) desc, c.name_ar
        limit 5
      ) s), '[]'::jsonb)
  );
end $$;

-- PostGIS lives in the extensions schema

create or replace function public.register_barber(
  p_display_name text,
  p_salon_id uuid default null,
  p_salon_name text default null,
  p_area_id uuid default null,
  p_address text default null,
  p_latitude double precision default null,
  p_longitude double precision default null
)
returns public.barbers
language plpgsql security definer set search_path = public, extensions as $$
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

-- Views

create or replace view public.admin_barber_cancellations with (security_invoker = true) as
  select b.id as barber_id, b.display_name, b.salon_id,
         count(k.id) as cancelled_total,
         count(k.id) filter (where k.cancel_reason = 'sick') as sick,
         count(k.id) filter (where k.cancel_reason = 'emergency') as emergency,
         count(k.id) filter (where k.cancel_reason = 'other') as other
  from barbers b
  left join bookings k on k.barber_id = b.id and k.status = 'cancelled' and k.cancelled_by = b.profile_id
  where is_admin()
  group by b.id;

create or replace view public.barber_directory with (security_invoker = false) as
  select b.id, b.salon_id, b.display_name, b.photo_url, b.is_vip, b.rating_avg, b.rating_count,
         is_barber_bookable(b.id) as is_bookable,
         p.phone,
         s.name as salon_name, s.area_id, s.address,
         extensions.st_y(s.location::extensions.geometry) as latitude,
         extensions.st_x(s.location::extensions.geometry) as longitude,
         s.photos as salon_photos
  from barbers b
  join salons s on s.id = b.salon_id
  left join profiles p on p.id = b.profile_id
  where b.status in ('active', 'suspended');

-- Browsing needs no session; booking does

grant select on public.barber_directory to anon;
grant execute on function public.get_available_slots(uuid, date, int) to anon;
