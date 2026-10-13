-- Push notifications: new bookings, cancellations and a reminder before each booking

create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron;

create function public.reminder_lead_time() returns interval
language sql immutable as $$ select interval '1 hour' $$;

alter table public.bookings add column reminder_sent_at timestamptz;

create index bookings_reminder_due_idx on public.bookings (lower(time_range))
  where status = 'confirmed' and reminder_sent_at is null and customer_id is not null;

-- Device tokens: a token belongs to whoever signed in on the device last

create function public.register_device_token(p_token text, p_platform public.device_platform) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if coalesce(char_length(p_token), 0) not between 1 and 4096 then
    raise exception 'invalid_device_token';
  end if;
  insert into device_tokens (profile_id, token, platform)
  values (auth.uid(), p_token, p_platform)
  on conflict (token) do update
    set profile_id = excluded.profile_id, platform = excluded.platform, updated_at = now();
end $$;

revoke insert, update on public.device_tokens from anon, authenticated;
revoke all on public.device_tokens from anon;
revoke execute on function public.register_device_token(text, public.device_platform) from public, anon;
grant execute on function public.register_device_token(text, public.device_platform) to authenticated;

-- Sending: the send-notification Edge Function is called through pg_net.
-- Its URL and shared secret live in Vault as `notification_function_url` and `notification_webhook_secret`.

create function public.send_notification(p_payload jsonb) returns void
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_url text;
  v_secret text;
begin
  if not exists (select 1 from device_tokens where profile_id = (p_payload ->> 'recipient_id')::uuid) then
    return;
  end if;
  select decrypted_secret into v_url from vault.decrypted_secrets where name = 'notification_function_url';
  select decrypted_secret into v_secret from vault.decrypted_secrets where name = 'notification_webhook_secret';
  if v_url is null or v_secret is null then
    raise warning 'notifications_not_configured';
    return;
  end if;
  perform net.http_post(
    url := v_url,
    body := p_payload,
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || v_secret),
    timeout_milliseconds := 5000
  );
end $$;

create function public.booking_notification(p_type text, p_booking public.bookings, p_recipient uuid, p_audience text)
returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_strip_nulls(jsonb_build_object(
    'type', p_type,
    'booking_id', p_booking.id,
    'recipient_id', p_recipient,
    'audience', p_audience,
    'starts_at', lower(p_booking.time_range),
    'barber_name', b.display_name,
    'salon_name', s.name,
    'customer_name', coalesce(c.full_name, p_booking.customer_name),
    'service_name', sc.name_ar,
    'cancel_reason', p_booking.cancel_reason,
    'cancel_note', p_booking.cancel_note
  ))
  from barbers b
  join salons s on s.id = b.salon_id
  join service_catalog sc on sc.id = p_booking.service_id
  left join profiles c on c.id = p_booking.customer_id
  where b.id = p_booking.barber_id
$$;

create function public.notify_booking_change() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_barber_profile uuid := (select profile_id from barbers where id = new.barber_id);
  v_by text;
begin
  if tg_op = 'INSERT' then
    if new.source = 'app' and new.status = 'confirmed' and v_barber_profile is not null then
      perform send_notification(booking_notification('booking_created', new, v_barber_profile, 'barber'));
    end if;
  elsif old.status = 'confirmed' and new.status = 'cancelled' then
    v_by := case
      when new.cancelled_by = new.customer_id then 'customer'
      when new.cancelled_by = v_barber_profile then 'barber'
      else 'admin'
    end;
    if v_by <> 'customer' and new.customer_id is not null then
      perform send_notification(
        booking_notification('booking_cancelled', new, new.customer_id, 'customer') || jsonb_build_object('cancelled_by', v_by));
    end if;
    if v_by <> 'barber' and v_barber_profile is not null then
      perform send_notification(
        booking_notification('booking_cancelled', new, v_barber_profile, 'barber') || jsonb_build_object('cancelled_by', v_by));
    end if;
  end if;
  return null;
end $$;

create trigger bookings_notify
  after insert or update of status on public.bookings
  for each row execute function public.notify_booking_change();

-- Reminders: each booking is marked once, so a reminder is never sent twice.
-- Bookings made less than the lead time ahead get none.

create function public.send_booking_reminders() returns int
language plpgsql security definer set search_path = public as $$
declare
  v_booking bookings%rowtype;
  v_count int := 0;
begin
  for v_booking in
    update bookings
    set reminder_sent_at = now()
    where status = 'confirmed'
      and reminder_sent_at is null
      and customer_id is not null
      and lower(time_range) > now()
      and lower(time_range) <= now() + reminder_lead_time()
      and created_at < lower(time_range) - reminder_lead_time()
    returning *
  loop
    perform send_notification(booking_notification('booking_reminder', v_booking, v_booking.customer_id, 'customer'));
    v_count := v_count + 1;
  end loop;
  return v_count;
end $$;

revoke execute on function public.send_notification(jsonb) from public, anon, authenticated;
revoke execute on function public.booking_notification(text, public.bookings, uuid, text) from public, anon, authenticated;
revoke execute on function public.notify_booking_change() from public, anon, authenticated;
revoke execute on function public.send_booking_reminders() from public, anon, authenticated;

select cron.schedule('booking-reminders', '* * * * *', $$ select public.send_booking_reminders() $$);
