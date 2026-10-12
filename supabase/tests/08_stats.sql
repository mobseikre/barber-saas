begin;
select plan(14);
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

create function pg_temp.book(p_barber text, p_service text, p_date date, p_time time, p_price numeric, p_status text) returns void language plpgsql as $$
begin
  insert into bookings (barber_id, customer_name, service_id, price, duration_min, time_range, source, status, cancelled_at)
  values (pg_temp.fx(p_barber), 'زبون', pg_temp.fx(p_service), p_price, 30,
          tstzrange(pg_temp.local_ts(p_date, p_time), pg_temp.local_ts(p_date, p_time) + interval '30 minutes', '[)'),
          'manual', p_status::booking_status, case when p_status = 'cancelled' then now() end);
end $$;

select pg_temp.new_user('ali', '218990000002', 'Ali', 'barber');
select pg_temp.new_user('murad', '218990000003', 'Murad', 'barber');
select pg_temp.new_user('khaled', '218990000004', 'Khaled', 'customer');

do $$
declare
  v_area uuid := (select id from areas where name = 'حي الأندلس');
  v_salon uuid;
  v_b uuid;
begin
  insert into salons (name, owner_id, area_id) values ('صالون', pg_temp.fx('ali'), v_area) returning id into v_salon;
  insert into barbers (profile_id, salon_id, display_name, status, subscription_ends_at)
  values (pg_temp.fx('ali'), v_salon, 'علي', 'active', now() + interval '30 days') returning id into v_b;
  insert into fx values ('barber', v_b);
  insert into barbers (profile_id, salon_id, display_name, status, subscription_ends_at)
  values (pg_temp.fx('murad'), v_salon, 'مراد', 'active', now() + interval '30 days') returning id into v_b;
  insert into fx values ('other', v_b);
  insert into fx select 'haircut', id from service_catalog where code = 'haircut';
  insert into fx select 'beard', id from service_catalog where code = 'beard';
  insert into fx select 'kids', id from service_catalog where code = 'kids';
end $$;

-- the reference day is 15 October 2026; the clock is passed in so the test never depends on today's date
select pg_temp.book('barber', 'haircut', '2026-10-15', '09:00', 25, 'completed');
select pg_temp.book('barber', 'haircut', '2026-10-15', '10:00', 25, 'completed');
select pg_temp.book('barber', 'beard', '2026-10-15', '11:00', 15, 'completed');
select pg_temp.book('barber', 'haircut', '2026-10-15', '12:00', 25, 'no_show');
select pg_temp.book('barber', 'beard', '2026-10-15', '13:00', 15, 'cancelled');
select pg_temp.book('barber', 'kids', '2026-10-15', '18:00', 15, 'confirmed');
select pg_temp.book('barber', 'haircut', '2026-10-15', '23:30', 25, 'confirmed');
select pg_temp.book('barber', 'beard', '2026-10-14', '23:30', 15, 'completed');
select pg_temp.book('barber', 'haircut', '2026-10-03', '10:00', 25, 'completed');
select pg_temp.book('barber', 'beard', '2026-10-03', '11:00', 15, 'completed');
select pg_temp.book('barber', 'haircut', '2026-10-31', '23:30', 25, 'completed');
select pg_temp.book('barber', 'haircut', '2026-09-30', '23:30', 25, 'completed');
select pg_temp.book('barber', 'haircut', '2026-11-01', '00:30', 25, 'completed');
select pg_temp.book('other', 'haircut', '2026-10-15', '09:00', 99, 'completed');

create function pg_temp.stats(p_at timestamptz) returns jsonb language sql as $$ select barber_stats(p_at) $$;

select pg_temp.login('ali');
set local timezone = 'UTC';

select is((pg_temp.stats(pg_temp.local_ts('2026-10-15', '12:00')) ->> 'today_customers')::int, 6,
  'today counts every booking that is not cancelled');
select is((pg_temp.stats(pg_temp.local_ts('2026-10-15', '12:00')) ->> 'today_completed')::int, 3, 'completed today');
select is((pg_temp.stats(pg_temp.local_ts('2026-10-15', '12:00')) ->> 'today_no_show')::int, 1, 'no-shows today');
select is((pg_temp.stats(pg_temp.local_ts('2026-10-15', '12:00')) ->> 'today_income')::numeric, 65::numeric,
  'income today comes from completed bookings only');
select is((pg_temp.stats(pg_temp.local_ts('2026-10-15', '12:00')) ->> 'month_customers')::int, 10,
  'the month counts bookings from the 1st to the 31st in Libya time');
select is((pg_temp.stats(pg_temp.local_ts('2026-10-15', '12:00')) ->> 'month_income')::numeric, 145::numeric,
  'income for the month: completed only, no cancelled, no-show or confirmed');
select is((pg_temp.stats(pg_temp.local_ts('2026-10-15', '00:30')) ->> 'today_customers')::int, 6,
  'just after local midnight is still the same Libya day, even in a UTC session');
select is((pg_temp.stats(pg_temp.local_ts('2026-10-14', '23:50')) ->> 'today_customers')::int, 1,
  'the booking at 23:30 belongs to the day before');

select results_eq(
  $$ select s ->> 'name_ar', (s ->> 'count')::int from jsonb_array_elements(pg_temp.stats(pg_temp.local_ts('2026-10-15', '12:00')) -> 'top_services') s $$,
  $$ values ('قص شعر', 6), ('لحية', 3), ('أطفال', 1) $$,
  'top services of the month by number of bookings');

select is((pg_temp.stats(pg_temp.local_ts('2026-11-15', '12:00')) ->> 'month_customers')::int, 1, 'another month only sees its own bookings');
select is(pg_temp.stats(pg_temp.local_ts('2027-01-15', '12:00')) -> 'top_services', '[]'::jsonb, 'an empty month has no top services');

select pg_temp.login('murad');
select is((pg_temp.stats(pg_temp.local_ts('2026-10-15', '12:00')) ->> 'today_income')::numeric, 99::numeric,
  'a barber sees only their own numbers');

select pg_temp.login('khaled');
select throws_ok($$ select barber_stats() $$, 'not_a_barber', 'customers have no statistics');
select pg_temp.logout();
select ok(not has_function_privilege('anon', 'public.barber_stats(timestamptz)', 'execute'), 'anon cannot call barber_stats');

select * from finish();
rollback;
