begin;
select plan(16);
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
  v_salon2 uuid;
  v_barber uuid;
  v_barber2 uuid;
begin
  perform pg_temp.new_user('admin', '218990000001', 'Admin', 'customer');
  update profiles set role = 'admin' where id = pg_temp.fx('admin');

  perform pg_temp.new_user('ali', '218990000002', 'Ali', 'barber');
  perform pg_temp.new_user('murad', '218990000003', 'Murad', 'barber');
  perform pg_temp.new_user('khaled', '218990000004', 'Khaled', 'customer');
  perform pg_temp.new_user('salem', '218990000005', 'Salem', 'customer');

  insert into salons (name, owner_id, area_id) values ('صالون الأناقة', pg_temp.fx('ali'), v_area) returning id into v_salon;
  insert into fx values ('salon', v_salon);
  insert into salons (name, owner_id, area_id) values ('حلاق الملوك', pg_temp.fx('murad'), v_area) returning id into v_salon2;

  insert into barbers (profile_id, salon_id, display_name, status, subscription_ends_at)
  values (pg_temp.fx('ali'), v_salon, 'علي القماطي', 'active', now() + interval '30 days') returning id into v_barber;
  insert into fx values ('barber', v_barber);

  insert into barbers (profile_id, salon_id, display_name, status)
  values (pg_temp.fx('murad'), v_salon2, 'مراد الزنتاني', 'pending') returning id into v_barber2;
  insert into fx values ('barber_pending', v_barber2);

  insert into fx select 'haircut', id from service_catalog where code = 'haircut';
  insert into fx select 'beard', id from service_catalog where code = 'beard';

  insert into barber_services (barber_id, service_id, price, duration_min) values
    (v_barber, pg_temp.fx('haircut'), 25, 30),
    (v_barber, pg_temp.fx('beard'), 15, 20),
    (v_barber2, pg_temp.fx('haircut'), 20, 30);

  insert into working_hours (barber_id, weekday, opens_at, closes_at, is_closed)
  select b, d, '10:00', '22:00', d = 5 from unnest(array[v_barber, v_barber2]) b, generate_series(0, 6) d;

  insert into breaks (barber_id, name, starts_at, ends_at) values (v_barber, 'غداء وصلاة', '13:30', '14:30');
end $$;

select pg_temp.setup();

select pg_temp.login('khaled');

select lives_ok($$ select create_booking(pg_temp.fx('barber'), pg_temp.fx('haircut'), pg_temp.local_ts(pg_temp.next_saturday(), '10:00')) $$,
  'customer books an available slot');
select is((select status from bookings where customer_id = pg_temp.fx('khaled')), 'confirmed', 'booking is confirmed instantly');
select is((select price from bookings where customer_id = pg_temp.fx('khaled')), 25.00, 'price is snapshotted from barber_services');

select throws_ok($$ select create_booking(pg_temp.fx('barber'), pg_temp.fx('haircut'), pg_temp.local_ts(pg_temp.next_saturday(), '10:15')) $$,
  'slot_not_available', 'a slot overlapping an existing booking is refused');
select throws_ok($$ select create_booking(pg_temp.fx('barber'), pg_temp.fx('haircut'), pg_temp.local_ts(pg_temp.next_saturday(), '13:45')) $$,
  'slot_not_available', 'a slot inside a break is refused');
select throws_ok($$ select create_booking(pg_temp.fx('barber_pending'), pg_temp.fx('haircut'), pg_temp.local_ts(pg_temp.next_saturday(), '11:00')) $$,
  'barber_not_bookable', 'a pending barber cannot be booked');

select lives_ok($$ select create_booking(pg_temp.fx('barber'), pg_temp.fx('beard'), pg_temp.local_ts(pg_temp.next_saturday(), '11:00')) $$,
  'second upcoming booking is allowed');
select throws_ok($$ select create_booking(pg_temp.fx('barber'), pg_temp.fx('haircut'), pg_temp.local_ts(pg_temp.next_saturday(), '12:00')) $$,
  'booking_limit_reached', 'third upcoming booking hits the limit');

select lives_ok($$ select cancel_booking((select id from bookings where customer_id = pg_temp.fx('khaled') and service_id = pg_temp.fx('beard'))) $$,
  'customer cancels a booking more than 2 hours ahead');
select lives_ok($$ select create_booking(pg_temp.fx('barber'), pg_temp.fx('haircut'), pg_temp.local_ts(pg_temp.next_saturday(), '12:00')) $$,
  'cancelling frees a place under the limit');

-- a booking starting in one hour, inserted directly to bypass the slot grid
select pg_temp.logout();
insert into bookings (id, barber_id, customer_id, service_id, price, duration_min, time_range)
values ('00000000-0000-0000-0000-00000000a001', pg_temp.fx('barber'), pg_temp.fx('salem'), pg_temp.fx('haircut'), 25, 30,
        tstzrange(now() + interval '1 hour', now() + interval '90 minutes', '[)'));

select pg_temp.login('salem');
select throws_ok($$ select cancel_booking('00000000-0000-0000-0000-00000000a001') $$,
  'cancellation_window_passed', 'customer cannot cancel within 2 hours');

select pg_temp.login('ali');
select throws_ok($$ select cancel_booking('00000000-0000-0000-0000-00000000a001') $$,
  'cancel_reason_required', 'barber must give a reason');
select lives_ok($$ select cancel_booking('00000000-0000-0000-0000-00000000a001', 'sick', 'flu') $$,
  'barber cancels inside the 2-hour window with a reason');
select pg_temp.logout();
select results_eq(
  $$ select status::text, cancel_reason::text, cancel_note, cancelled_by from bookings where id = '00000000-0000-0000-0000-00000000a001' $$,
  $$ values ('cancelled', 'sick', 'flu', pg_temp.fx('ali')) $$,
  'reason, note and who cancelled are stored on the booking');

select pg_temp.login('admin');
select results_eq(
  $$ select cancelled_total::int, sick::int from admin_barber_cancellations where barber_id = pg_temp.fx('barber') $$,
  $$ values (1, 1) $$,
  'admin sees the barber cancellation count by reason');
select pg_temp.login('ali');
select is((select count(*) from admin_barber_cancellations)::int, 0, 'the cancellations view is empty for a barber');
select pg_temp.logout();

select * from finish();
rollback;
