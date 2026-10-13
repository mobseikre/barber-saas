-- Notification outbox: triggers and the reminder job queue rows, a pg_cron job posts them and retries failures.
-- A row counts as sent, and a reminder as delivered, only once the Edge Function answers 2xx.

create function public.notification_max_attempts() returns int
language sql immutable as $$ select 5 $$;

-- 1, 2, 4 and 8 minutes after the first, second, third and fourth failed attempt
create function public.notification_retry_delay(p_attempts int) returns interval
language sql immutable as $$ select make_interval(mins => (2 ^ greatest(p_attempts - 1, 0))::int) $$;

create function public.device_token_limit() returns int
language sql immutable as $$ select 5 $$;

create type public.notification_status as enum ('pending', 'sending', 'sent', 'failed', 'expired');

create table public.notification_outbox (
  id bigint generated always as identity primary key,
  recipient_id uuid not null references public.profiles (id) on delete cascade,
  payload jsonb not null,
  reminder_for uuid unique references public.bookings (id) on delete cascade,
  status public.notification_status not null default 'pending',
  attempts int not null default 0,
  next_attempt_at timestamptz not null default now(),
  request_id bigint,
  last_attempt_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  sent_at timestamptz
);

create index notification_outbox_due_idx on public.notification_outbox (next_attempt_at) where status = 'pending';
create index notification_outbox_sending_idx on public.notification_outbox (request_id) where status = 'sending';

alter table public.notification_outbox enable row level security;
revoke all on public.notification_outbox from anon, authenticated;

-- Queueing

create or replace function public.send_notification(p_payload jsonb) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_recipient uuid := (p_payload ->> 'recipient_id')::uuid;
begin
  if not exists (select 1 from device_tokens where profile_id = v_recipient) then
    return;
  end if;
  insert into notification_outbox (recipient_id, payload) values (v_recipient, p_payload);
end $$;

create or replace function public.send_booking_reminders() returns int
language plpgsql security definer set search_path = public as $$
declare
  v_count int;
begin
  insert into notification_outbox (recipient_id, payload, reminder_for)
  select b.customer_id, booking_notification('booking_reminder', b, b.customer_id, 'customer'), b.id
  from bookings b
  where b.status = 'confirmed'
    and b.reminder_sent_at is null
    and b.customer_id is not null
    and lower(b.time_range) > now()
    and lower(b.time_range) <= now() + reminder_lead_time()
    and b.created_at < lower(b.time_range) - reminder_lead_time()
    and exists (select 1 from device_tokens t where t.profile_id = b.customer_id)
    and not exists (select 1 from notification_outbox o where o.reminder_for = b.id)
  on conflict (reminder_for) do nothing;
  get diagnostics v_count = row_count;
  return v_count;
end $$;

-- Delivery

create function public.deliver_notifications() returns void
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_url text;
  v_secret text;
begin
  -- Outcomes of earlier posts. A request without a response after 5 minutes counts as failed.
  with outcome as (
    select o.id, o.attempts, r.status_code,
           coalesce(r.error_msg, case when r.timed_out then 'timed_out' end, 'no_response') as error
    from notification_outbox o
    left join net._http_response r on r.id = o.request_id
    where o.status = 'sending'
      and (r.id is not null or o.last_attempt_at < now() - interval '5 minutes')
    for update of o skip locked
  ), done as (
    update notification_outbox o
    set status = case
          when x.status_code between 200 and 299 then 'sent'
          when x.attempts >= notification_max_attempts() then 'failed'
          else 'pending'
        end::notification_status,
        sent_at = case when x.status_code between 200 and 299 then now() end,
        last_error = case when x.status_code between 200 and 299 then null else coalesce(x.status_code::text, x.error) end,
        next_attempt_at = now() + notification_retry_delay(x.attempts),
        request_id = null
    from outcome x
    where o.id = x.id
    returning o.reminder_for, o.status
  )
  update bookings b set reminder_sent_at = now()
  from done
  where done.status = 'sent' and b.id = done.reminder_for;

  -- News about a booking that has started, or a reminder for one no longer confirmed, is not sent late.
  update notification_outbox o
  set status = 'expired'
  where o.status = 'pending'
    and ((o.payload ->> 'starts_at')::timestamptz <= now()
      or (o.reminder_for is not null
        and not exists (select 1 from bookings b where b.id = o.reminder_for and b.status = 'confirmed')));

  select decrypted_secret into v_url from vault.decrypted_secrets where name = 'notification_function_url';
  select decrypted_secret into v_secret from vault.decrypted_secrets where name = 'notification_webhook_secret';
  if v_url is null or v_secret is null then
    if exists (select 1 from notification_outbox where status = 'pending') then
      raise warning 'notifications_not_configured';
    end if;
    return;
  end if;

  update notification_outbox o
  set status = 'sending',
      attempts = o.attempts + 1,
      last_attempt_at = now(),
      request_id = net.http_post(
        url := v_url,
        body := o.payload,
        headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || v_secret),
        timeout_milliseconds := 5000
      )
  where o.id in (
    select id from notification_outbox
    where status = 'pending' and next_attempt_at <= now()
    order by id
    limit 200
    for update skip locked
  );
end $$;

revoke execute on function public.deliver_notifications() from public, anon, authenticated;
revoke execute on function public.notification_retry_delay(int) from public, anon, authenticated;

select cron.schedule('notification-outbox', '10 seconds', $$ select public.deliver_notifications() $$);

-- Device tokens: at most device_token_limit() per user, the most recently registered ones

create or replace function public.register_device_token(p_token text, p_platform public.device_platform) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if coalesce(char_length(p_token), 0) not between 1 and 4096 then
    raise exception 'invalid_device_token';
  end if;
  insert into device_tokens (profile_id, token, platform, updated_at)
  values (auth.uid(), p_token, p_platform, clock_timestamp())
  on conflict (token) do update
    set profile_id = excluded.profile_id, platform = excluded.platform, updated_at = excluded.updated_at;
  delete from device_tokens
  where id in (
    select id from device_tokens
    where profile_id = auth.uid()
    order by updated_at desc, id
    offset device_token_limit()
  );
end $$;

-- TRUNCATE ignores RLS, so clients never hold it

revoke truncate on all tables in schema public from anon, authenticated;
alter default privileges for role postgres in schema public revoke truncate on tables from anon, authenticated;
