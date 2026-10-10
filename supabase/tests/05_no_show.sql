begin;
select plan(10);
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
  perform pg_temp.new_user('admin', '218910000001', 'Admin', 'customer');
  update profiles set role = 'admin' where id = pg_temp.fx('admin');

  perform pg_temp.new_user('ali', '218910000002', 'Ali', 'barber');
  perform pg_temp.new_user('murad', '218910000003', 'Murad', 'barber');
  perform pg_temp.new_user('khaled', '218910000004', 'Khaled', 'customer');
  perform pg_temp.new_user('salem', '218910000005', 'Salem', 'customer');

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

insert into bookings (id, barber_id, customer_id, service_id, price, duration_min, time_range)
select ('00000000-0000-0000-0000-00000000b00' || i)::uuid, pg_temp.fx('barber'), pg_temp.fx('khaled'), pg_temp.fx('haircut'), 25, 30,
       tstzrange(now() - (i || ' days')::interval, now() - (i || ' days')::interval + interval '30 minutes', '[)')
from generate_series(1, 3) i;

select pg_temp.login('ali');
select set_booking_status('00000000-0000-0000-0000-00000000b001', 'no_show');
select set_booking_status('00000000-0000-0000-0000-00000000b002', 'no_show');
select pg_temp.logout();
select results_eq($$ select no_show_count, blocked_at is null from profiles where id = pg_temp.fx('khaled') $$,
  $$ values (2, true) $$, 'two no-shows are counted but do not block');

select pg_temp.login('ali');
select set_booking_status('00000000-0000-0000-0000-00000000b003', 'no_show');
select pg_temp.logout();
select results_eq($$ select no_show_count, blocked_at is not null from profiles where id = pg_temp.fx('khaled') $$,
  $$ values (3, true) $$, 'the third no-show blocks the customer');

select pg_temp.login('khaled');
select throws_ok($$ select create_booking(pg_temp.fx('barber'), pg_temp.fx('haircut'), pg_temp.local_ts(pg_temp.next_saturday(), '10:00')) $$,
  'customer is blocked after 3 no-shows', 'a blocked customer cannot book');

select pg_temp.login('ali');
select set_booking_status('00000000-0000-0000-0000-00000000b003', 'completed');
select pg_temp.logout();
select results_eq($$ select no_show_count, blocked_at is not null from profiles where id = pg_temp.fx('khaled') $$,
  $$ values (2, true) $$, 'reverting a no-show decrements the count but keeps the block');

select pg_temp.login('ali');
select set_booking_status('00000000-0000-0000-0000-00000000b003', 'no_show');
select set_booking_status('00000000-0000-0000-0000-00000000b003', 'no_show');
select pg_temp.logout();
select is((select no_show_count from profiles where id = pg_temp.fx('khaled')), 3, 'setting no_show twice counts once');

select pg_temp.login('salem');
select throws_ok($$ select unblock_customer(pg_temp.fx('khaled')) $$, 'only admins can unblock customers', 'another customer cannot unblock');

select pg_temp.login('admin');
select lives_ok($$ select unblock_customer(pg_temp.fx('khaled')) $$, 'admin unblocks the customer');
select pg_temp.logout();
select results_eq($$ select no_show_count, blocked_at is null from profiles where id = pg_temp.fx('khaled') $$,
  $$ values (0, true) $$, 'unblocking resets the count and the block');

select pg_temp.login('khaled');
select lives_ok($$ select create_booking(pg_temp.fx('barber'), pg_temp.fx('haircut'), pg_temp.local_ts(pg_temp.next_saturday(), '10:00')) $$,
  'unblocked customer can book again');

select pg_temp.login('ali');
select lives_ok($$ select create_manual_booking(pg_temp.fx('haircut'), pg_temp.local_ts(pg_temp.next_saturday(), '15:00'), 'يوسف') $$,
  'barber adds a manual booking');
select pg_temp.logout();

select * from finish();
rollback;
