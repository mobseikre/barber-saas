begin;
select plan(23);
-- Tests use only the reference data; the local dev seed is removed inside this transaction.
delete from public.bookings;
delete from public.subscription_payments;
delete from public.barbers;
delete from public.salons;
delete from auth.users;
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

create function pg_temp.setup() returns void language plpgsql as $$
declare
  v_area uuid := (select id from areas where name = 'حي الأندلس');
  v_salon uuid;
  v_barber uuid;
begin
  perform pg_temp.new_user('admin', '218990000001', 'Admin', 'customer');
  update profiles set role = 'admin' where id = pg_temp.fx('admin');
  perform pg_temp.new_user('ali', '218990000002', 'Ali', 'barber');
  perform pg_temp.new_user('khaled', '218990000004', 'Khaled', 'customer');
  perform pg_temp.new_user('murad', '218990000003', 'Murad', 'barber');
  perform pg_temp.new_user('nadia', '218990000006', 'Nadia', 'barber');
  perform pg_temp.new_user('samir', '218990000007', 'Samir', 'barber');

  insert into salons (name, owner_id, area_id) values ('صالون الأناقة', pg_temp.fx('ali'), v_area) returning id into v_salon;
  insert into barbers (profile_id, salon_id, display_name, status, subscription_ends_at)
  values (pg_temp.fx('ali'), v_salon, 'علي القماطي', 'active', now() + interval '30 days') returning id into v_barber;
  insert into fx values ('barber', v_barber);
  insert into fx values ('salon', v_salon);
  insert into barbers (profile_id, salon_id, display_name, status, subscription_ends_at)
  values (pg_temp.fx('murad'), v_salon, 'مراد الزنتاني', 'active', now() + interval '30 days');
  insert into fx select 'haircut', id from service_catalog where code = 'haircut';

  insert into barber_services (barber_id, service_id, price, duration_min) values (v_barber, pg_temp.fx('haircut'), 25, 30);
  insert into working_hours (barber_id, weekday, opens_at, closes_at, is_closed)
  select v_barber, d, '10:00', '22:00', false from generate_series(0, 6) d;
end $$;

select pg_temp.setup();

insert into bookings (id, barber_id, customer_id, service_id, price, duration_min, time_range, source) values
  ('00000000-0000-0000-0000-00000000f001', pg_temp.fx('barber'), pg_temp.fx('khaled'), pg_temp.fx('haircut'), 25, 30,
   tstzrange(now() - interval '10 minutes', now() + interval '20 minutes', '[)'), 'app'),
  ('00000000-0000-0000-0000-00000000f002', pg_temp.fx('barber'), pg_temp.fx('khaled'), pg_temp.fx('haircut'), 25, 30,
   tstzrange(pg_temp.local_ts(pg_temp.next_saturday(), '11:00'), pg_temp.local_ts(pg_temp.next_saturday(), '11:30'), '[)'), 'app');

-- a lapsed subscription keeps the existing bookings workable, but no new manual ones

select pg_temp.login('ali');
select lives_ok($$ select create_manual_booking(pg_temp.fx('haircut'), pg_temp.local_ts(pg_temp.next_saturday(), '12:00'), 'يوسف') $$,
  'a bookable barber adds a manual booking');
select pg_temp.logout();

update barbers set subscription_ends_at = now() - interval '1 day' where id = pg_temp.fx('barber');
select pg_temp.login('ali');
select throws_ok($$ select create_manual_booking(pg_temp.fx('haircut'), pg_temp.local_ts(pg_temp.next_saturday(), '13:00'), 'يوسف') $$,
  'barber_not_bookable', 'a barber whose subscription has lapsed cannot add a manual booking');
select is((select count(*)::int from bookings where barber_id = pg_temp.fx('barber')), 3,
  'and can still read their bookings');
select is((select status::text from set_booking_status('00000000-0000-0000-0000-00000000f001', 'no_show')), 'no_show',
  'and mark a started booking as no-show');
select is((select status::text from set_booking_status('00000000-0000-0000-0000-00000000f001', 'confirmed')), 'confirmed',
  'and undo it');
select is((select status::text from cancel_booking('00000000-0000-0000-0000-00000000f002', 'sick')), 'cancelled',
  'and cancel an upcoming booking with a reason');
select pg_temp.logout();

update barbers set status = 'suspended', subscription_ends_at = now() + interval '10 days' where id = pg_temp.fx('barber');
select pg_temp.login('ali');
select throws_ok($$ select create_manual_booking(pg_temp.fx('haircut'), pg_temp.local_ts(pg_temp.next_saturday(), '13:00'), 'يوسف') $$,
  'barber_not_active', 'a suspended barber cannot add a manual booking');
select is((select status::text from set_booking_status('00000000-0000-0000-0000-00000000f001', 'completed')), 'completed',
  'but marks a started booking as attended');
select is((select count(*)::int from bookings where barber_id = pg_temp.fx('barber')), 3,
  'and still reads their bookings');
select pg_temp.logout();

-- activation reaches the barber through the outbox

select pg_temp.new_user('omar', '218990000008', 'Omar', 'barber');
insert into barbers (profile_id, salon_id, display_name, status)
values (pg_temp.fx('omar'), pg_temp.fx('salon'), 'عمر البرعصي', 'pending');
insert into device_tokens (profile_id, token, platform) values
  (pg_temp.fx('omar'), 'token-omar', 'android'),
  (pg_temp.fx('ali'), 'token-ali', 'android');
delete from notification_outbox;

select pg_temp.login('admin');
select approve_barber((select id from barbers where profile_id = pg_temp.fx('omar')));
select pg_temp.logout();
select results_eq(
  $$ select payload ->> 'type', payload ->> 'bookable', payload ->> 'renewed' from notification_outbox where recipient_id = pg_temp.fx('omar') $$,
  $$ values ('barber_activated', 'false', 'false') $$,
  'approving a barber without a plan tells them, and that customers cannot book them yet');

delete from notification_outbox;
select pg_temp.login('admin');
select activate_subscription((select id from barbers where profile_id = pg_temp.fx('omar')), 1,
  (select price from subscription_plans where months = 1));
select pg_temp.logout();
select results_eq(
  $$ select payload ->> 'bookable', payload ->> 'renewed' from notification_outbox where recipient_id = pg_temp.fx('omar') $$,
  $$ values ('true', 'true') $$,
  'the first plan makes them bookable and tells them so');

delete from notification_outbox;
select pg_temp.login('admin');
select activate_subscription((select id from barbers where profile_id = pg_temp.fx('omar')), 1,
  (select price from subscription_plans where months = 1));
select pg_temp.logout();
select is((select count(*)::int from notification_outbox), 0, 'extending a subscription that is still running sends nothing');

update barbers set status = 'active', subscription_ends_at = now() - interval '1 day' where id = pg_temp.fx('barber');
delete from notification_outbox;
select pg_temp.login('admin');
select activate_subscription(pg_temp.fx('barber'), 1, (select price from subscription_plans where months = 1));
select pg_temp.logout();
select results_eq(
  $$ select recipient_id, payload ->> 'renewed', payload ->> 'barber_name' from notification_outbox $$,
  $$ values (pg_temp.fx('ali'), 'true', 'علي القماطي') $$,
  'renewing a lapsed subscription tells the barber');

delete from notification_outbox;
select pg_temp.login('admin');
select suspend_barber(pg_temp.fx('barber'));
select pg_temp.logout();
select is((select count(*)::int from notification_outbox), 0, 'suspending sends no activation notice');

delete from device_tokens where profile_id = pg_temp.fx('ali');
select pg_temp.login('admin');
select reactivate_barber(pg_temp.fx('barber'));
select pg_temp.logout();
select is((select count(*)::int from notification_outbox), 0, 'a barber without a device gets nothing queued');

-- the salon owner renames the salon; the name is never blank or too long

select pg_temp.login('ali');
select lives_ok($$ update salons set name = 'صالون النخبة' where id = pg_temp.fx('salon') $$, 'the owner renames the salon');
select is((select name from salons where id = pg_temp.fx('salon')), 'صالون النخبة', 'and the new name is stored');
select throws_ok($$ update salons set name = '   ' where id = pg_temp.fx('salon') $$, '23514', null, 'a blank name is refused');
select throws_ok($$ update salons set name = repeat('ص', salon_name_max_length() + 1) where id = pg_temp.fx('salon') $$,
  '23514', null, 'a name over the limit is refused');
select pg_temp.logout();

select pg_temp.login('murad');
update salons set name = 'صالون مراد' where id = pg_temp.fx('salon');
select is((select name from salons where id = pg_temp.fx('salon')), 'صالون النخبة', 'a barber who joined the salon cannot rename it');
select pg_temp.logout();

-- sign-up keeps the salon name the barber typed

select pg_temp.login('nadia');
select register_barber('نادية', null, '  صالون الياسمين ');
select is((select s.name from barbers b join salons s on s.id = b.salon_id where b.profile_id = pg_temp.fx('nadia')),
  'صالون الياسمين', 'register_barber names the new salon after what the barber typed');
select pg_temp.logout();

select pg_temp.login('samir');
select throws_ok($$ select register_barber('سمير', null, repeat('ص', salon_name_max_length() + 1)) $$,
  'salon_name_too_long', 'a typed salon name over the limit is refused');
select register_barber(repeat('س', full_name_max_length()));
select is((select char_length(s.name) from barbers b join salons s on s.id = b.salon_id where b.profile_id = pg_temp.fx('samir')),
  salon_name_max_length(), 'without a typed name the fallback name is cut to the limit');
select pg_temp.logout();

select * from finish();
rollback;
