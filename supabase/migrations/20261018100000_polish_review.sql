-- A barber whose subscription has lapsed keeps their existing bookings but cannot add manual ones

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
  if not is_barber_bookable(v_barber_id) then
    raise exception 'barber_not_bookable';
  end if;
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

-- The salon owner renames the salon from the app; the name stays short and never blank

create function public.salon_name_max_length() returns int
language sql immutable as $$ select 60 $$;

alter table public.salons
  add constraint salons_name_length check (char_length(btrim(name)) between 1 and salon_name_max_length());

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
  v_salon_name text := trim(coalesce(p_salon_name, ''));
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
  if char_length(v_salon_name) > salon_name_max_length() then
    raise exception 'salon_name_too_long' using detail = format('salon_name_max_length=%s', salon_name_max_length());
  end if;

  if p_salon_id is not null then
    select id into v_salon_id from salons where id = p_salon_id;
    if v_salon_id is null then
      raise exception 'salon_not_found';
    end if;
  else
    insert into salons (name, owner_id, area_id, address, location)
    values (
      coalesce(nullif(v_salon_name, ''), left('صالون ' || v_name, salon_name_max_length())),
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

-- The barber hears when an admin activates them, reactivates them or renews a lapsed subscription

create function public.notify_barber_activation() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_was_bookable boolean := coalesce(old.status = 'active' and old.profile_id is not null and old.subscription_ends_at > now(), false);
  v_bookable boolean := coalesce(new.status = 'active' and new.profile_id is not null and new.subscription_ends_at > now(), false);
begin
  if new.profile_id is not null
     and ((old.status <> 'active' and new.status = 'active') or (v_bookable and not v_was_bookable)) then
    perform send_notification(jsonb_build_object(
      'type', 'barber_activated',
      'recipient_id', new.profile_id,
      'audience', 'barber',
      'barber_name', new.display_name,
      'bookable', v_bookable,
      'renewed', old.status = 'active'
    ));
  end if;
  return null;
end $$;

create trigger barbers_notify_activation
  after update of status, subscription_ends_at on public.barbers
  for each row execute function public.notify_barber_activation();

revoke execute on function public.notify_barber_activation() from public, anon, authenticated;
