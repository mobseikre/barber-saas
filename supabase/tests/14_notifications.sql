begin;
select plan(31);
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

create function pg_temp.local_ts(p_date date, p_time time) returns timestamptz language sql immutable as $$
  select (p_date + p_time) at time zone 'Africa/Tripoli'
$$;

create function pg_temp.next_saturday() returns date language sql stable as $$
  select current_date + 7 + ((6 - extract(dow from current_date)::int + 7) % 7)
$$;

create temp table seen (id bigint primary key);

-- Every payload queued in the outbox since the last call, oldest first
create function pg_temp.sent() returns setof jsonb language plpgsql security definer as $$
begin
  return query select payload from notification_outbox where id not in (select id from seen) order by id;
  insert into seen select id from notification_outbox on conflict do nothing;
  delete from net.http_request_queue;
end $$;

create function pg_temp.book(p_customer text, p_starts_at timestamptz, p_created_ago interval, p_status booking_status default 'confirmed')
returns uuid language plpgsql as $$
declare
  v_id uuid;
begin
  insert into bookings (barber_id, customer_id, service_id, price, duration_min, time_range, status, cancelled_at, created_at)
  values (pg_temp.fx('barber'), pg_temp.fx(p_customer), pg_temp.fx('haircut'), 25, 30,
          tstzrange(p_starts_at, p_starts_at + interval '30 minutes', '[)'), p_status,
          case when p_status = 'cancelled' then now() end, now() - p_created_ago)
  returning id into v_id;
  return v_id;
end $$;

create function pg_temp.setup() returns void language plpgsql as $$
declare
  v_area uuid := (select id from areas where name = 'حي الأندلس');
  v_salon uuid;
  v_barber uuid;
begin
  perform pg_temp.new_user('admin', '218990000001', 'Admin', 'customer');
  update profiles set role = 'admin' where id = pg_temp.fx('admin');
  perform pg_temp.new_user('ali', '218990000002', 'علي', 'barber');
  perform pg_temp.new_user('khaled', '218990000004', 'خالد المقريف', 'customer');
  perform pg_temp.new_user('salem', '218990000005', 'سالم بن عامر', 'customer');

  insert into salons (name, owner_id, area_id) values ('صالون الأناقة', pg_temp.fx('ali'), v_area) returning id into v_salon;
  insert into barbers (profile_id, salon_id, display_name, status, subscription_ends_at)
  values (pg_temp.fx('ali'), v_salon, 'علي القماطي', 'active', now() + interval '30 days') returning id into v_barber;
  insert into fx values ('barber', v_barber);
  insert into fx select 'haircut', id from service_catalog where code = 'haircut';

  insert into barber_services (barber_id, service_id, price, duration_min) values (v_barber, pg_temp.fx('haircut'), 25, 30);
  insert into working_hours (barber_id, weekday, opens_at, closes_at)
  select v_barber, d, '10:00', '22:00' from generate_series(0, 6) d;

  insert into device_tokens (profile_id, token, platform) values
    (pg_temp.fx('ali'), 'token-ali', 'android'),
    (pg_temp.fx('khaled'), 'token-khaled', 'ios'),
    (pg_temp.fx('admin'), 'token-admin', 'android');

  perform vault.create_secret('http://kong:8000/functions/v1/send-notification', 'notification_function_url');
  perform vault.create_secret('test-secret', 'notification_webhook_secret');
end $$;

select pg_temp.setup();

-- Device tokens

select pg_temp.login('salem');
select lives_ok($$ select register_device_token('token-khaled', 'android') $$, 'a signed-in user registers a token');
select pg_temp.logout();
select results_eq(
  $$ select profile_id, platform::text from device_tokens where token = 'token-khaled' $$,
  $$ values (pg_temp.fx('salem'), 'android') $$,
  'a token moves to whoever signed in on the device last');
select pg_temp.login('khaled');
select lives_ok($$ select register_device_token('token-khaled', 'ios') $$, 'the token moves back on the next sign-in');
select throws_ok($$ insert into device_tokens (profile_id, token, platform) values (auth.uid(), 'direct', 'ios') $$,
  '42501', null, 'clients cannot insert tokens directly');
select throws_ok($$ select register_device_token('', 'ios') $$, 'invalid_device_token', 'an empty token is refused');
select lives_ok($$ delete from device_tokens where token = 'token-khaled' $$, 'a user deletes their own token on sign-out');
select pg_temp.logout();
select is((select count(*) from device_tokens where token = 'token-khaled')::int, 0, 'the token is gone');
insert into device_tokens (profile_id, token, platform) values (pg_temp.fx('khaled'), 'token-khaled', 'ios');

select ok(not has_function_privilege('authenticated', 'public.send_notification(jsonb)', 'execute'),
  'clients cannot send notifications');
select ok(not has_function_privilege('authenticated', 'public.send_booking_reminders()', 'execute'),
  'clients cannot run the reminders');
select ok(not has_function_privilege('anon', 'public.register_device_token(text, public.device_platform)', 'execute'),
  'visitors cannot register tokens');

-- New booking: the barber is notified

select pg_temp.sent();
select pg_temp.login('khaled');
select create_booking(pg_temp.fx('barber'), pg_temp.fx('haircut'), pg_temp.local_ts(pg_temp.next_saturday(), '10:00'),
                      '00000000-0000-0000-0000-0000000000c1');
select pg_temp.logout();

select deliver_notifications();
select results_eq(
  $$ select url, headers ->> 'Authorization' from net.http_request_queue $$,
  $$ values ('http://kong:8000/functions/v1/send-notification', 'Bearer test-secret') $$,
  'the request goes to the function URL with the shared secret');
select is(
  (select p from pg_temp.sent() p),
  jsonb_build_object(
    'type', 'booking_created',
    'booking_id', (select id from bookings where customer_id = pg_temp.fx('khaled')),
    'recipient_id', pg_temp.fx('ali'),
    'audience', 'barber',
    'starts_at', pg_temp.local_ts(pg_temp.next_saturday(), '10:00'),
    'barber_name', 'علي القماطي',
    'salon_name', 'صالون الأناقة',
    'customer_name', 'خالد المقريف',
    'service_name', (select name_ar from service_catalog where code = 'haircut')
  ),
  'a new booking notifies the barber with the customer, service and time');

select pg_temp.login('khaled');
select create_booking(pg_temp.fx('barber'), pg_temp.fx('haircut'), pg_temp.local_ts(pg_temp.next_saturday(), '10:00'),
                      '00000000-0000-0000-0000-0000000000c1');
select pg_temp.logout();
select is((select count(*) from pg_temp.sent())::int, 0, 'a retried booking request sends nothing again');

select pg_temp.login('ali');
select create_manual_booking(pg_temp.fx('haircut'), pg_temp.local_ts(pg_temp.next_saturday(), '12:00'), 'زبون');
select pg_temp.logout();
select is((select count(*) from pg_temp.sent())::int, 0, 'a manual booking sends nothing');

-- Cancellations: the other side is notified

select pg_temp.login('khaled');
select cancel_booking((select id from bookings where customer_id = pg_temp.fx('khaled')));
select pg_temp.logout();
select results_eq(
  $$ select p ->> 'type', (p ->> 'recipient_id')::uuid, p ->> 'cancelled_by', p ? 'cancel_reason' from pg_temp.sent() p $$,
  $$ values ('booking_cancelled', pg_temp.fx('ali'), 'customer', false) $$,
  'a customer cancellation notifies the barber, without a reason');

insert into fx values ('by_barber', pg_temp.book('khaled', now() + interval '1 day', interval '1 day'));
select pg_temp.sent();
select pg_temp.login('ali');
select cancel_booking(pg_temp.fx('by_barber'), 'sick', 'حرارة');
select pg_temp.logout();
select results_eq(
  $$ select p ->> 'type', (p ->> 'recipient_id')::uuid, p ->> 'cancelled_by', p ->> 'cancel_reason', p ->> 'cancel_note' from pg_temp.sent() p $$,
  $$ values ('booking_cancelled', pg_temp.fx('khaled'), 'barber', 'sick', 'حرارة') $$,
  'a barber cancellation notifies the customer with the reason and note');

insert into fx values ('by_admin', pg_temp.book('khaled', now() + interval '2 days', interval '1 day'));
select pg_temp.sent();
select pg_temp.login('admin');
select cancel_booking(pg_temp.fx('by_admin'));
select pg_temp.logout();
select results_eq(
  $$ select (p ->> 'recipient_id')::uuid, p ->> 'audience', p ->> 'cancelled_by' from pg_temp.sent() p $$,
  $$ values (pg_temp.fx('khaled'), 'customer', 'admin'), (pg_temp.fx('ali'), 'barber', 'admin') $$,
  'an admin cancellation notifies the customer and the barber');

insert into fx values ('no_device', pg_temp.book('salem', now() + interval '3 days', interval '1 day'));
select is((select count(*) from pg_temp.sent())::int, 1, 'the barber hears of the booking of a customer without a device');
select pg_temp.login('ali');
select cancel_booking(pg_temp.fx('no_device'), 'emergency');
select pg_temp.logout();
select is((select count(*) from pg_temp.sent())::int, 0, 'nothing is sent to a recipient without a device');

update bookings set status = 'completed' where id = (select pg_temp.book('khaled', now() - interval '1 hour', interval '1 day'));
select is((select count(*) from pg_temp.sent())::int, 1, 'marking attendance sends nothing beyond the booking itself');

-- Reminders

delete from bookings;
insert into fx values
  ('due', pg_temp.book('khaled', now() + interval '50 minutes', interval '1 day')),
  ('later', pg_temp.book('khaled', now() + interval '2 hours', interval '1 day')),
  ('last_minute', pg_temp.book('khaled', now() + interval '15 minutes', interval '10 minutes')),
  ('cancelled', pg_temp.book('khaled', now() + interval '30 minutes', interval '1 day', 'cancelled')),
  ('started', pg_temp.book('khaled', now() - interval '20 minutes', interval '1 day'));
insert into bookings (barber_id, customer_name, service_id, price, duration_min, time_range, source, created_at)
values (pg_temp.fx('barber'), 'زبون', pg_temp.fx('haircut'), 25, 5,
        tstzrange(now() + interval '45 minutes', now() + interval '50 minutes', '[)'), 'manual', now() - interval '1 day');
select pg_temp.sent();

select is(send_booking_reminders(), 1, 'one booking is due for a reminder');
select results_eq(
  $$ select reminder_for from notification_outbox where reminder_for is not null $$,
  $$ values (pg_temp.fx('due')) $$,
  'only the app booking starting within the hour is queued: later, last-minute, cancelled, started and manual ones are not');
select results_eq(
  $$ select p ->> 'type', (p ->> 'recipient_id')::uuid, (p ->> 'booking_id')::uuid, p ->> 'barber_name', p ->> 'salon_name' from pg_temp.sent() p $$,
  $$ values ('booking_reminder', pg_temp.fx('khaled'), pg_temp.fx('due'), 'علي القماطي', 'صالون الأناقة') $$,
  'the reminder goes to the customer with the barber and salon');
select is(send_booking_reminders(), 0, 'a second run sends nothing');
select is((select count(*) from pg_temp.sent())::int, 0, 'the reminder is never sent twice');

delete from bookings where id = pg_temp.fx('due');
update bookings set time_range = tstzrange(now() + interval '55 minutes', now() + interval '85 minutes', '[)')
where id = pg_temp.fx('later');
select is(send_booking_reminders(), 1, 'a booking is reminded once it enters the hour before it');
select is((select (p ->> 'booking_id')::uuid from pg_temp.sent() p), pg_temp.fx('later'), 'the reminder belongs to that booking');

-- Without the Vault settings nothing is posted and bookings still work

delete from vault.secrets where name = 'notification_function_url';
select lives_ok($$ select pg_temp.book('khaled', now() + interval '4 days', interval '1 day') $$,
  'bookings work while notifications are not configured');
select is((select count(*) from pg_temp.sent())::int, 1, 'the notification waits in the outbox');
select deliver_notifications();
select is((select count(*) from net.http_request_queue)::int, 0, 'nothing is posted without the function URL');

select is((select count(*) from cron.job where jobname = 'booking-reminders' and schedule = '* * * * *')::int, 1,
  'reminders run every minute');

select * from finish();
rollback;
