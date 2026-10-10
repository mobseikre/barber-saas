begin;
select plan(17);
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

insert into bookings (barber_id, customer_id, service_id, price, duration_min, time_range)
values (pg_temp.fx('barber'), pg_temp.fx('khaled'), pg_temp.fx('haircut'), 25, 30,
        tstzrange(pg_temp.local_ts(pg_temp.next_saturday(), '10:00'), pg_temp.local_ts(pg_temp.next_saturday(), '10:30'), '[)'));
insert into bookings (barber_id, customer_id, service_id, price, duration_min, time_range)
values (pg_temp.fx('barber_pending'), pg_temp.fx('salem'), pg_temp.fx('haircut'), 20, 30,
        tstzrange(pg_temp.local_ts(pg_temp.next_saturday(), '10:00'), pg_temp.local_ts(pg_temp.next_saturday(), '10:30'), '[)'));

-- customer
select pg_temp.login('khaled');
select is((select count(*) from barbers)::int, 1, 'customer sees only bookable barbers');
select is((select id from barbers limit 1), pg_temp.fx('barber'), 'the visible barber is the active one');
select is((select count(*) from bookings)::int, 1, 'customer sees only their own bookings');
select is((select count(*) from profiles)::int, 1, 'customer sees only their own profile');
select is((select count(*) from barber_services)::int, 2, 'customer sees services of bookable barbers only');
select is((select count(*) from subscription_payments)::int, 0, 'customer sees no subscription payments');
update bookings set status = 'completed' where customer_id = pg_temp.fx('khaled');
select pg_temp.logout();
select is((select status from bookings where customer_id = pg_temp.fx('khaled')), 'confirmed', 'customer cannot update bookings directly');
select pg_temp.login('khaled');
select throws_ok($$ update profiles set role = 'admin' where id = pg_temp.fx('khaled') $$,
  'only admins can change role or block state', 'customer cannot promote themselves');
select throws_ok($$ select activate_subscription(pg_temp.fx('barber_pending'), 1, 50) $$,
  'only admins can activate subscriptions', 'customer cannot activate subscriptions');
select throws_ok($$ select unblock_customer(pg_temp.fx('khaled')) $$,
  'only admins can unblock customers', 'customer cannot unblock');

-- barber
select pg_temp.login('murad');
select is((select count(*) from barbers)::int, 2, 'barber sees bookable barbers plus their own pending row');
select is((select count(*) from bookings)::int, 1, 'barber sees only bookings for their own chair');
select is((select customer_id from bookings), pg_temp.fx('salem'), 'and that booking is theirs');
select throws_ok($$ update barbers set status = 'active' where profile_id = pg_temp.fx('murad') $$,
  'only admins can change barber status, subscription or VIP', 'barber cannot activate themselves');
select lives_ok($$ update barbers set display_name = 'مراد' where profile_id = pg_temp.fx('murad') $$,
  'barber can edit their own display name');
select throws_ok($$ select activate_subscription(pg_temp.fx('barber_pending'), 1, 50) $$,
  'only admins can activate subscriptions', 'barber cannot activate subscriptions');

-- admin
select pg_temp.login('admin');
select is((select count(*) from bookings)::int, 2, 'admin sees all bookings');
select pg_temp.logout();

select * from finish();
rollback;
