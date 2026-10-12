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
      and lower(time_range) < (v_now_local::date + 1)::timestamp at time zone app_timezone()
    order by lower(time_range);
end $$;
