-- Admin dashboard: barber status actions, salon pin correction, read models and reports

create or replace function public.admin_set_barber_status(p_barber_id uuid, p_from public.barber_status, p_to public.barber_status)
returns public.barbers
language plpgsql security definer set search_path = public as $$
declare
  v_barber barbers%rowtype;
begin
  if not is_admin() then
    raise exception 'admin_only';
  end if;
  select * into v_barber from barbers where id = p_barber_id for update;
  if v_barber.id is null then
    raise exception 'barber_not_found';
  end if;
  if v_barber.status <> p_from then
    raise exception 'invalid_barber_status';
  end if;
  if p_to = 'active' and v_barber.profile_id is null then
    raise exception 'barber_has_no_account';
  end if;
  update barbers set status = p_to where id = p_barber_id returning * into v_barber;
  return v_barber;
end $$;

create function public.approve_barber(p_barber_id uuid) returns public.barbers
language sql security definer set search_path = public as $$
  select public.admin_set_barber_status(p_barber_id, 'pending', 'active')
$$;

create function public.reject_barber(p_barber_id uuid) returns public.barbers
language sql security definer set search_path = public as $$
  select public.admin_set_barber_status(p_barber_id, 'pending', 'rejected')
$$;

create function public.suspend_barber(p_barber_id uuid) returns public.barbers
language sql security definer set search_path = public as $$
  select public.admin_set_barber_status(p_barber_id, 'active', 'suspended')
$$;

create function public.reactivate_barber(p_barber_id uuid) returns public.barbers
language sql security definer set search_path = public as $$
  select public.admin_set_barber_status(p_barber_id, 'suspended', 'active')
$$;

create function public.admin_set_salon_location(p_salon_id uuid, p_latitude double precision, p_longitude double precision)
returns public.salons
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_salon salons%rowtype;
begin
  if not is_admin() then
    raise exception 'admin_only';
  end if;
  if p_latitude is null or p_longitude is null
     or p_latitude not between -90 and 90 or p_longitude not between -180 and 180 then
    raise exception 'invalid_location';
  end if;
  update salons
  set location = st_setsrid(st_makepoint(p_longitude, p_latitude), 4326)::geography
  where id = p_salon_id
  returning * into v_salon;
  if v_salon.id is null then
    raise exception 'salon_not_found';
  end if;
  return v_salon;
end $$;

revoke execute on function public.admin_set_barber_status(uuid, public.barber_status, public.barber_status) from public, anon;
revoke execute on function public.approve_barber(uuid) from public, anon;
revoke execute on function public.reject_barber(uuid) from public, anon;
revoke execute on function public.suspend_barber(uuid) from public, anon;
revoke execute on function public.reactivate_barber(uuid) from public, anon;
revoke execute on function public.admin_set_salon_location(uuid, double precision, double precision) from public, anon;

-- Read models. Each one is empty for anyone who is not an admin.

create view public.admin_barbers with (security_invoker = true) as
  select b.id, b.display_name, b.status, b.is_vip, b.subscription_ends_at, b.created_at,
         b.rating_avg, b.rating_count, b.profile_id,
         p.phone,
         s.id as salon_id, s.name as salon_name, s.address,
         (s.owner_id is not null and s.owner_id = b.profile_id) as is_salon_owner,
         a.id as area_id, a.name as area_name,
         c.id as city_id, c.name as city_name,
         extensions.st_y(s.location::extensions.geometry) as latitude,
         extensions.st_x(s.location::extensions.geometry) as longitude,
         is_barber_bookable(b.id) as is_bookable
  from barbers b
  join salons s on s.id = b.salon_id
  join areas a on a.id = s.area_id
  join cities c on c.id = a.city_id
  left join profiles p on p.id = b.profile_id
  where is_admin();

create view public.admin_subscription_payments with (security_invoker = true) as
  select sp.id, sp.barber_id, b.display_name as barber_name, sp.amount, sp.paid_at,
         sp.period_start, sp.period_end, sp.note, r.full_name as recorded_by_name
  from subscription_payments sp
  join barbers b on b.id = sp.barber_id
  left join profiles r on r.id = sp.recorded_by
  where is_admin();

create view public.admin_salons with (security_invoker = true) as
  select s.id, s.name, s.address, s.created_at,
         a.id as area_id, a.name as area_name, c.id as city_id, c.name as city_name,
         o.full_name as owner_name, o.phone as owner_phone,
         coalesce(t.barbers_total, 0) as barbers_total,
         coalesce(t.barbers_subscribed, 0) as barbers_subscribed,
         coalesce(t.bookings_month, 0) as bookings_month,
         coalesce(t.rating_avg, 0) as rating_avg
  from salons s
  join areas a on a.id = s.area_id
  join cities c on c.id = a.city_id
  left join profiles o on o.id = s.owner_id
  left join lateral (
    select count(*) filter (where b.status <> 'rejected') as barbers_total,
           count(*) filter (where is_barber_bookable(b.id)) as barbers_subscribed,
           (select count(*) from bookings k
             where k.barber_id in (select id from barbers where salon_id = s.id)
               and k.status <> 'cancelled'
               and date_trunc('month', lower(k.time_range) at time zone app_timezone())
                 = date_trunc('month', now() at time zone app_timezone())) as bookings_month,
           round(sum(b.rating_avg * b.rating_count) / nullif(sum(b.rating_count), 0), 1) as rating_avg
    from barbers b
    where b.salon_id = s.id
  ) t on true
  where is_admin();

revoke all on public.admin_barbers, public.admin_subscription_payments, public.admin_salons from public, anon;
revoke insert, update, delete, truncate on public.admin_barbers, public.admin_subscription_payments, public.admin_salons from authenticated;
grant select on public.admin_barbers, public.admin_subscription_payments, public.admin_salons to authenticated;

-- Reports, bucketed by Tripoli calendar days and months

create function public.admin_bookings_per_day(p_days int default 30)
returns table (day date, total bigint, completed bigint, cancelled bigint, no_show bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_admin() then
    raise exception 'admin_only';
  end if;
  if p_days is null or p_days not between 1 and 366 then
    raise exception 'invalid_range';
  end if;
  return query
  select d::date,
         count(k.id),
         count(k.id) filter (where k.status = 'completed'),
         count(k.id) filter (where k.status = 'cancelled'),
         count(k.id) filter (where k.status = 'no_show')
  from generate_series((now() at time zone app_timezone())::date - (p_days - 1), (now() at time zone app_timezone())::date, interval '1 day') d
  left join bookings k on (lower(k.time_range) at time zone app_timezone())::date = d::date
  group by d
  order by d;
end $$;

create function public.admin_revenue_per_month(p_months int default 12)
returns table (month date, revenue numeric, payments bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_admin() then
    raise exception 'admin_only';
  end if;
  if p_months is null or p_months not between 1 and 60 then
    raise exception 'invalid_range';
  end if;
  return query
  select m::date, coalesce(sum(sp.amount), 0), count(sp.id)
  from generate_series(
         date_trunc('month', now() at time zone app_timezone())::date - ((p_months - 1) * interval '1 month'),
         date_trunc('month', now() at time zone app_timezone())::date,
         interval '1 month') m
  left join subscription_payments sp on date_trunc('month', sp.paid_at at time zone app_timezone())::date = m::date
  group by m
  order by m;
end $$;

revoke execute on function public.admin_bookings_per_day(int) from public, anon;
revoke execute on function public.admin_revenue_per_month(int) from public, anon;
