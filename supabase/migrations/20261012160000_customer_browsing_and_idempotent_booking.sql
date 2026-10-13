-- Visitors browse salon pages before signing up

grant select on public.salon_barbers, public.salon_hours to anon;

-- create_booking: a retried request returns the booking it already created

alter table public.bookings add column idempotency_key uuid;
create unique index bookings_customer_idempotency_key_idx on public.bookings (customer_id, idempotency_key);

drop function public.create_booking(uuid, uuid, timestamptz);

create function public.create_booking(p_barber_id uuid, p_service_id uuid, p_starts_at timestamptz, p_idempotency_key uuid)
returns public.bookings
language plpgsql security definer set search_path = public as $$
declare
  v_customer profiles%rowtype;
  v_service barber_services%rowtype;
  v_booking bookings%rowtype;
begin
  if p_idempotency_key is null then
    raise exception 'idempotency_key_required';
  end if;
  select * into v_customer from profiles where id = auth.uid() for update;
  if v_customer.id is null or v_customer.role <> 'customer' then
    raise exception 'not_a_customer';
  end if;

  select * into v_booking from bookings where customer_id = v_customer.id and idempotency_key = p_idempotency_key;
  if v_booking.id is not null then
    if v_booking.barber_id <> p_barber_id or v_booking.service_id <> p_service_id
       or lower(v_booking.time_range) <> p_starts_at then
      raise exception 'idempotency_key_reused';
    end if;
    return v_booking;
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

  insert into bookings (barber_id, customer_id, service_id, price, duration_min, time_range, source, idempotency_key)
  values (p_barber_id, v_customer.id, p_service_id, v_service.price, v_service.duration_min,
          tstzrange(p_starts_at, p_starts_at + make_interval(mins => v_service.duration_min), '[)'), 'app', p_idempotency_key)
  returning * into v_booking;
  return v_booking;
end $$;

revoke execute on function public.create_booking(uuid, uuid, timestamptz, uuid) from public, anon;
grant execute on function public.create_booking(uuid, uuid, timestamptz, uuid) to authenticated;
