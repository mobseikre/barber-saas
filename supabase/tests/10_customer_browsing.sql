begin;
select plan(24);
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

create function pg_temp.anon() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('role', 'anon', true);
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

create function pg_temp.book(p_time time, p_key uuid) returns uuid language sql as $$
  select (create_booking(pg_temp.fx('barber'), pg_temp.fx('haircut'), pg_temp.local_ts(pg_temp.next_saturday(), p_time), p_key)).id
$$;

create function pg_temp.setup() returns void language plpgsql as $$
declare
  v_area uuid := (select id from areas where name = 'حي الأندلس');
  v_salon uuid;
  v_barber uuid;
  v_barber2 uuid;
begin
  perform pg_temp.new_user('ali', '218990000002', 'Ali', 'barber');
  perform pg_temp.new_user('murad', '218990000003', 'Murad', 'barber');
  perform pg_temp.new_user('khaled', '218990000004', 'Khaled', 'customer');
  perform pg_temp.new_user('salem', '218990000005', 'Salem', 'customer');

  insert into salons (name, owner_id, area_id) values ('صالون الأناقة', pg_temp.fx('ali'), v_area) returning id into v_salon;
  insert into fx values ('salon', v_salon);

  insert into barbers (profile_id, salon_id, display_name, status, subscription_ends_at)
  values (pg_temp.fx('ali'), v_salon, 'علي القماطي', 'active', now() + interval '30 days') returning id into v_barber;
  insert into fx values ('barber', v_barber);

  insert into barbers (profile_id, salon_id, display_name, status)
  values (pg_temp.fx('murad'), v_salon, 'مراد الزنتاني', 'pending') returning id into v_barber2;
  insert into fx values ('barber_pending', v_barber2);

  insert into fx select 'haircut', id from service_catalog where code = 'haircut';

  insert into barber_services (barber_id, service_id, price, duration_min) values
    (v_barber, pg_temp.fx('haircut'), 25, 30),
    (v_barber2, pg_temp.fx('haircut'), 20, 30);

  insert into working_hours (barber_id, weekday, opens_at, closes_at, is_closed)
  select b, d, '10:00', '22:00', d = 5 from unnest(array[v_barber, v_barber2]) b, generate_series(0, 6) d;
end $$;

select pg_temp.setup();

-- a visitor browses a salon page without an account

select ok(has_table_privilege('anon', 'public.salon_barbers', 'select')
  and has_table_privilege('anon', 'public.salon_hours', 'select'),
  'anon may read salon_barbers and salon_hours');
select ok(not (
  select bool_or(has_table_privilege('anon', v, p))
  from unnest(array['public.salon_barbers', 'public.salon_hours']) v, unnest(array['insert', 'update', 'delete', 'truncate']) p),
  'the views stay read-only for anon');

select pg_temp.anon();
select results_eq(
  $$ select display_name, is_bookable from salon_barbers where salon_id = pg_temp.fx('salon') order by display_name $$,
  $$ values ('علي القماطي', true) $$,
  'anon lists the salon barbers, without the pending one');
select results_eq(
  $$ select opens_at, closes_at from salon_hours where salon_id = pg_temp.fx('salon') and weekday = 6 $$,
  $$ values ('10:00'::time, '22:00'::time) $$,
  'anon reads the salon hours');
select is((select count(*) from salon_hours where salon_id = pg_temp.fx('salon') and weekday = 5)::int, 0,
  'a day off has no hours');
select is((select count(*) from barber_services where barber_id = pg_temp.fx('barber'))::int, 1,
  'anon reads the services of a bookable barber');
select is((select count(*) from barber_services where barber_id = pg_temp.fx('barber_pending'))::int, 0,
  'but not of a pending one');
select is((select count(*) from working_hours where barber_id = pg_temp.fx('barber'))::int, 7,
  'anon reads the working hours of a bookable barber');
select ok((select count(*) from cities) > 0 and (select count(*) from areas) > 0 and (select count(*) from service_catalog) > 0,
  'anon reads cities, areas and the service catalog');
select throws_ok($$ select pg_temp.book('12:00', gen_random_uuid()) $$, '42501', null, 'anon still cannot book');
select pg_temp.logout();

-- create_booking is idempotent per customer and key

select is((select count(*) from pg_proc where proname = 'create_booking' and pronamespace = 'public'::regnamespace)::int, 1,
  'only the keyed create_booking exists');

select pg_temp.login('khaled');
select throws_ok($$ select create_booking(pg_temp.fx('barber'), pg_temp.fx('haircut'), pg_temp.local_ts(pg_temp.next_saturday(), '10:00'), null) $$,
  'idempotency_key_required', 'the key is required');

select is(pg_temp.book('10:00', '00000000-0000-0000-0000-0000000000a1'), pg_temp.book('10:00', '00000000-0000-0000-0000-0000000000a1'),
  'a retry with the same key returns the same booking');
select is((select count(*) from bookings where customer_id = pg_temp.fx('khaled'))::int, 1, 'and creates one row');
select lives_ok($$ select pg_temp.book('12:00', '00000000-0000-0000-0000-0000000000a2') $$, 'a second booking with a new key');
select is(pg_temp.book('12:00', '00000000-0000-0000-0000-0000000000a2'),
  (select id from bookings where customer_id = pg_temp.fx('khaled') and idempotency_key = '00000000-0000-0000-0000-0000000000a2'),
  'a retry at the upcoming limit still returns the booking instead of booking_limit_reached');
select throws_ok($$ select pg_temp.book('14:00', gen_random_uuid()) $$, 'booking_limit_reached', 'a new key at the limit is refused');
select throws_ok($$ select pg_temp.book('16:00', '00000000-0000-0000-0000-0000000000a1') $$,
  'idempotency_key_reused', 'a key reused for another slot is refused');

select lives_ok($$ select cancel_booking((select id from bookings where idempotency_key = '00000000-0000-0000-0000-0000000000a1')) $$,
  'the customer cancels the first booking');
select is((select status::text from bookings where id = pg_temp.book('10:00', '00000000-0000-0000-0000-0000000000a1')), 'cancelled',
  'a late retry returns the cancelled booking and does not book again');
select is((select count(*) from bookings where customer_id = pg_temp.fx('khaled'))::int, 2, 'still two rows');

select pg_temp.login('salem');
select throws_ok($$ select pg_temp.book('12:00', '00000000-0000-0000-0000-0000000000a2') $$,
  'slot_not_available', 'another customer with the same key gets their own attempt');
select lives_ok($$ select pg_temp.book('16:00', '00000000-0000-0000-0000-0000000000a2') $$,
  'and books with it');
select pg_temp.logout();

select is((select count(distinct customer_id) from bookings where idempotency_key = '00000000-0000-0000-0000-0000000000a2')::int, 2,
  'keys are scoped to the customer');

select * from finish();
rollback;
