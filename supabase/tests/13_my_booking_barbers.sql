begin;
select plan(8);
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

create function pg_temp.setup() returns void language plpgsql as $$
declare
  v_area uuid := (select id from areas where name = 'حي الأندلس');
  v_salon uuid;
  v_barber uuid;
  v_other uuid;
  v_haircut uuid := (select id from service_catalog where code = 'haircut');
begin
  perform pg_temp.new_user('ali', '218990000002', 'Ali', 'barber');
  perform pg_temp.new_user('murad', '218990000003', 'Murad', 'barber');
  perform pg_temp.new_user('khaled', '218990000004', 'Khaled', 'customer');
  perform pg_temp.new_user('salem', '218990000005', 'Salem', 'customer');

  insert into salons (name, owner_id, area_id, address, location)
  values ('صالون الأناقة', pg_temp.fx('ali'), v_area, 'شارع الزاوية',
          extensions.st_setsrid(extensions.st_makepoint(13.1146, 32.8752), 4326)::extensions.geography)
  returning id into v_salon;

  insert into barbers (profile_id, salon_id, display_name, status, subscription_ends_at)
  values (pg_temp.fx('ali'), v_salon, 'علي القماطي', 'active', now() + interval '30 days') returning id into v_barber;
  insert into fx values ('barber', v_barber);
  insert into barbers (profile_id, salon_id, display_name, status, subscription_ends_at)
  values (pg_temp.fx('murad'), v_salon, 'مراد الزنتاني', 'active', now() + interval '30 days') returning id into v_other;

  insert into bookings (barber_id, customer_id, service_id, price, duration_min, time_range, status) values
    (v_barber, pg_temp.fx('khaled'), v_haircut, 25, 30,
     tstzrange(now() - interval '3 hours', now() - interval '2 hours 30 minutes'), 'completed'),
    (v_other, pg_temp.fx('salem'), v_haircut, 25, 30,
     tstzrange(now() - interval '3 hours', now() - interval '2 hours 30 minutes'), 'completed');
end $$;

select pg_temp.setup();

select ok(not has_table_privilege('anon', 'public.my_booking_barbers', 'select'), 'anon cannot read my_booking_barbers');
select ok(not (
  select bool_or(has_table_privilege('authenticated', 'public.my_booking_barbers', p))
  from unnest(array['insert', 'update', 'delete', 'truncate']) p),
  'the view is read-only');

select pg_temp.login('khaled');
select results_eq(
  $$ select barber_id, display_name, salon_name, address, round(latitude::numeric, 4), round(longitude::numeric, 4) from my_booking_barbers $$,
  $$ values (pg_temp.fx('barber'), 'علي القماطي', 'صالون الأناقة', 'شارع الزاوية', 32.8752::numeric, 13.1146::numeric) $$,
  'a customer reads the barber and salon of their own bookings');
select pg_temp.logout();

update barbers set status = 'pending' where id = pg_temp.fx('barber');
select pg_temp.login('khaled');
select is((select count(*) from barber_directory where id = pg_temp.fx('barber'))::int, 0, 'a pending barber leaves the directory');
select is((select display_name from my_booking_barbers), 'علي القماطي', 'but the customer still sees his name');
select pg_temp.logout();

update barbers set status = 'rejected' where id = pg_temp.fx('barber');
select pg_temp.login('khaled');
select is((select salon_name from my_booking_barbers), 'صالون الأناقة', 'a rejected barber keeps the salon on the booking too');

select pg_temp.login('salem');
select is((select count(*) from my_booking_barbers where barber_id = pg_temp.fx('barber'))::int, 0,
  'another customer does not see barbers they never booked');
select is((select count(*) from my_booking_barbers)::int, 1, 'only their own');
select pg_temp.logout();

select * from finish();
rollback;
