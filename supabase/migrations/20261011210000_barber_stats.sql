-- Barber statistics

create function public.barber_stats(p_at timestamptz default now())
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_barber_id uuid := current_barber_id();
  v_tz text := app_timezone();
  v_today date := (p_at at time zone v_tz)::date;
  v_day_start timestamptz := v_today::timestamp at time zone v_tz;
  v_day_end timestamptz := (v_today + 1)::timestamp at time zone v_tz;
  v_month_start timestamptz := date_trunc('month', v_today::timestamp) at time zone v_tz;
  v_month_end timestamptz := (date_trunc('month', v_today::timestamp) + interval '1 month') at time zone v_tz;
begin
  if v_barber_id is null then
    raise exception 'not_a_barber';
  end if;

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

revoke execute on function public.barber_stats(timestamptz) from public, anon;
