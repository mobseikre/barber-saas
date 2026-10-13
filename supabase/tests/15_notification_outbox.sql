begin;
select plan(32);
-- Tests use only the reference data; the local dev seed is removed inside this transaction.
delete from public.bookings;
delete from public.subscription_payments;
delete from public.barbers;
delete from public.salons;
delete from auth.users;
delete from net.http_request_queue;
delete from vault.secrets where name in ('notification_function_url', 'notification_webhook_secret');
create extension if not exists pgtap with schema extensions;

create temp table fx (key text primary key, id uuid not null);

create function pg_temp.fx(p_key text) returns uuid language sql stable security definer as $$
  select id from fx where key = p_key
$$;

create function pg_temp.new_user(p_key text, p_phone text, p_name text, p_role text) returns uuid language plpgsql as $$
declare
  v_id uuid := gen_random_uuid();
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, email_confirmed_at)
  values (v_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', p_phone || '@app.local', 'x',
          '{"provider":"email","providers":["email"]}', jsonb_build_object('full_name', p_name, 'role', p_role, 'phone', p_phone), now(), now(), now());
  insert into fx values (p_key, v_id);
  return v_id;
end $$;

create function pg_temp.login(p_key text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.fx(p_key), 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', pg_temp.fx(p_key)::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

create function pg_temp.logout() returns void language plpgsql as $$
begin
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
end $$;

create function pg_temp.book(p_customer text, p_starts_at timestamptz, p_created_ago interval) returns uuid language plpgsql as $$
declare
  v_id uuid;
begin
  insert into bookings (barber_id, customer_id, service_id, price, duration_min, time_range, created_at)
  values (pg_temp.fx('barber'), pg_temp.fx(p_customer), pg_temp.fx('haircut'), 25, 30,
          tstzrange(p_starts_at, p_starts_at + interval '30 minutes', '[)'), now() - p_created_ago)
  returning id into v_id;
  return v_id;
end $$;

-- The Edge Function answers the request in flight for the outbox row of [p_booking]
create function pg_temp.respond(p_booking uuid, p_status int, p_timed_out bool default false) returns void language sql as $$
  insert into net._http_response (id, status_code, timed_out, error_msg, created)
  select request_id, p_status, p_timed_out, case when p_timed_out then 'Timeout was reached' end, now()
  from notification_outbox where (payload ->> 'booking_id')::uuid = p_booking and status = 'sending'
$$;

create function pg_temp.row_of(p_booking uuid) returns notification_outbox language sql as $$
  select * from notification_outbox where (payload ->> 'booking_id')::uuid = p_booking
$$;

create function pg_temp.posts() returns int language plpgsql as $$
declare
  v_count int := (select count(*) from net.http_request_queue);
begin
  delete from net.http_request_queue;
  return v_count;
end $$;

create function pg_temp.make_due() returns void language sql as $$
  update notification_outbox set next_attempt_at = now() where status = 'pending'
$$;

create function pg_temp.setup() returns void language plpgsql as $$
declare
  v_salon uuid;
  v_barber uuid;
begin
  perform pg_temp.new_user('ali', '218990000002', 'علي', 'barber');
  perform pg_temp.new_user('khaled', '218990000004', 'خالد المقريف', 'customer');
  perform pg_temp.new_user('salem', '218990000005', 'سالم بن عامر', 'customer');

  insert into salons (name, owner_id, area_id)
  values ('صالون الأناقة', pg_temp.fx('ali'), (select id from areas where name = 'حي الأندلس')) returning id into v_salon;
  insert into barbers (profile_id, salon_id, display_name, status, subscription_ends_at)
  values (pg_temp.fx('ali'), v_salon, 'علي القماطي', 'active', now() + interval '30 days') returning id into v_barber;
  insert into fx values ('barber', v_barber);
  insert into fx select 'haircut', id from service_catalog where code = 'haircut';

  insert into device_tokens (profile_id, token, platform) values
    (pg_temp.fx('ali'), 'token-ali', 'android'),
    (pg_temp.fx('khaled'), 'token-khaled', 'ios');

  perform vault.create_secret('http://kong:8000/functions/v1/send-notification', 'notification_function_url');
  perform vault.create_secret('test-secret', 'notification_webhook_secret');
end $$;

select pg_temp.setup();

-- Retries

insert into fx values ('booking', pg_temp.book('khaled', now() + interval '2 days', interval '1 day'));
select is((pg_temp.row_of(pg_temp.fx('booking'))).status, 'pending', 'a new booking queues a pending row');
select is(pg_temp.posts(), 0, 'queueing posts nothing by itself');

select deliver_notifications();
select is(pg_temp.posts(), 1, 'the outbox job posts the pending row');
select results_eq(
  $$ select status::text, attempts, request_id is not null from pg_temp.row_of(pg_temp.fx('booking')) $$,
  $$ values ('sending', 1, true) $$,
  'the row is sending with one attempt and the request id');

select deliver_notifications();
select is(pg_temp.posts(), 0, 'a row is not posted again while its request is in flight');

select pg_temp.respond(pg_temp.fx('booking'), 500);
select deliver_notifications();
select results_eq(
  $$ select status::text, attempts, sent_at is null, last_error, next_attempt_at > now() + interval '59 seconds' from pg_temp.row_of(pg_temp.fx('booking')) $$,
  $$ values ('pending', 1, true, '500', true) $$,
  'a 500 puts the row back with a one minute wait');
select is(pg_temp.posts(), 0, 'the row waits before the next attempt');

select pg_temp.make_due();
select deliver_notifications();
select is(pg_temp.posts(), 1, 'the second attempt is posted once the wait is over');
select pg_temp.respond(pg_temp.fx('booking'), null, true);
select deliver_notifications();
select results_eq(
  $$ select status::text, attempts, last_error, next_attempt_at > now() + interval '119 seconds' from pg_temp.row_of(pg_temp.fx('booking')) $$,
  $$ values ('pending', 2, 'Timeout was reached', true) $$,
  'a timeout counts as a failure and doubles the wait');

select pg_temp.make_due();
select deliver_notifications();
select pg_temp.respond(pg_temp.fx('booking'), 401);
select deliver_notifications();
select is((pg_temp.row_of(pg_temp.fx('booking'))).attempts, 3, 'a 4xx answer is retried too');

select pg_temp.make_due();
select deliver_notifications();
update notification_outbox set last_attempt_at = now() - interval '6 minutes'
where (payload ->> 'booking_id')::uuid = pg_temp.fx('booking');
select deliver_notifications();
select results_eq(
  $$ select status::text, attempts, last_error from pg_temp.row_of(pg_temp.fx('booking')) $$,
  $$ values ('pending', 4, 'no_response') $$,
  'a request without a response after 5 minutes counts as failed');

select pg_temp.make_due();
select deliver_notifications();
select pg_temp.respond(pg_temp.fx('booking'), 503);
select deliver_notifications();
select pg_temp.posts();
select results_eq(
  $$ select status::text, attempts, sent_at is null from pg_temp.row_of(pg_temp.fx('booking')) $$,
  $$ values ('failed', 5, true) $$,
  'the fifth failure gives up');
select pg_temp.make_due();
select deliver_notifications();
select is(pg_temp.posts(), 0, 'a failed row is never posted again');

select results_eq(
  $$ select notification_retry_delay(a) from generate_series(1, 4) a $$,
  $$ values (interval '1 minute'), (interval '2 minutes'), (interval '4 minutes'), (interval '8 minutes') $$,
  'the wait doubles from one minute');
select is(notification_max_attempts(), 5, 'at most 5 attempts');

-- Success, and reminders marked only on a 2xx

delete from notification_outbox;
insert into fx values ('soon', pg_temp.book('khaled', now() + interval '50 minutes', interval '1 day'));
delete from notification_outbox;
select is(send_booking_reminders(), 1, 'the reminder is queued');
select deliver_notifications();
select is((select reminder_sent_at from bookings where id = pg_temp.fx('soon')), null, 'reminder_sent_at stays empty while the request is in flight');
select is(send_booking_reminders(), 0, 'a reminder in the outbox is not queued twice');

select pg_temp.respond(pg_temp.fx('soon'), 500);
select deliver_notifications();
select is((select reminder_sent_at from bookings where id = pg_temp.fx('soon')), null, 'a failed reminder leaves reminder_sent_at empty');

select pg_temp.make_due();
select deliver_notifications();
select pg_temp.respond(pg_temp.fx('soon'), 200);
select deliver_notifications();
select results_eq(
  $$ select status::text, sent_at is not null, last_error from pg_temp.row_of(pg_temp.fx('soon')) $$,
  $$ values ('sent', true, null::text) $$,
  'a 200 marks the row sent');
select isnt((select reminder_sent_at from bookings where id = pg_temp.fx('soon')), null, 'a 200 sets reminder_sent_at');
select is(send_booking_reminders(), 0, 'a delivered reminder is never queued again');

-- Late rows

delete from bookings;
insert into fx values ('cancelled', pg_temp.book('khaled', now() + interval '40 minutes', interval '1 day'));
delete from notification_outbox;
select send_booking_reminders();
update bookings set status = 'cancelled', cancelled_at = now(), cancelled_by = pg_temp.fx('khaled') where id = pg_temp.fx('cancelled');
select pg_temp.posts();
select deliver_notifications();
select is((pg_temp.row_of(pg_temp.fx('cancelled'))).status, 'expired',
  'a reminder for a booking cancelled before it went out is dropped');
select is(pg_temp.posts(), 1, 'only the cancellation itself is posted');

-- Device tokens: at most 5 per user

select pg_temp.login('salem');
select register_device_token('salem-' || n, 'android') from generate_series(1, 5) n;
select register_device_token('salem-1', 'android');
select register_device_token('salem-6', 'ios');
select pg_temp.logout();
select results_eq(
  $$ select token from device_tokens where profile_id = pg_temp.fx('salem') order by token $$,
  $$ values ('salem-1'), ('salem-3'), ('salem-4'), ('salem-5'), ('salem-6') $$,
  'the sixth token removes the oldest; registering a token again makes it the newest');
select is((select count(*) from device_tokens where profile_id <> pg_temp.fx('salem'))::int, 2,
  'other users keep their tokens');
select is(device_token_limit(), 5, 'the limit is 5');

-- Clients have no access to the outbox and cannot truncate

select pg_temp.login('khaled');
select throws_ok($$ select * from notification_outbox $$, '42501', null, 'clients cannot read the outbox');
select throws_ok($$ truncate bookings $$, '42501', null, 'clients cannot truncate a table');
select pg_temp.logout();
select is_empty(
  $$ select table_name::text from information_schema.role_table_grants
     where table_schema = 'public' and privilege_type = 'TRUNCATE' and grantee in ('anon', 'authenticated') $$,
  'no table in public grants TRUNCATE to anon or authenticated');
select ok(not has_function_privilege('authenticated', 'public.deliver_notifications()', 'execute'),
  'clients cannot run the outbox job');

select is((select count(*) from cron.job where jobname = 'notification-outbox' and schedule = '10 seconds')::int, 1,
  'the outbox job runs every 10 seconds');

select * from finish();
rollback;
