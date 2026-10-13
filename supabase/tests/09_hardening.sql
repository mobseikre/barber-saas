begin;
select plan(46);
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

create function pg_temp.error_detail(p_sql text) returns text language plpgsql as $$
declare
  v_detail text;
begin
  execute p_sql;
  return null;
exception when others then
  get stacked diagnostics v_detail = pg_exception_detail;
  return v_detail;
end $$;

create function pg_temp.auth_email(p_email text) returns text language sql as $$
  select format($f$ insert into auth.users (id, instance_id, aud, role, email, encrypted_password, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, email_confirmed_at)
    values (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', %L, 'x',
            '{"provider":"email","providers":["email"]}', '{"full_name":"x","role":"customer"}', now(), now(), now()) $f$, p_email)
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
  perform pg_temp.new_user('nadia', '218990000006', 'Nadia', 'barber');

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
  insert into fx values ('area', v_area);

  insert into barber_services (barber_id, service_id, price, duration_min) values
    (v_barber, pg_temp.fx('haircut'), 25, 30),
    (v_barber2, pg_temp.fx('haircut'), 20, 30);

  insert into working_hours (barber_id, weekday, opens_at, closes_at, is_closed)
  select b, d, '10:00', '22:00', d = 5 from unnest(array[v_barber, v_barber2]) b, generate_series(0, 6) d;
end $$;

select pg_temp.setup();

insert into bookings (id, barber_id, customer_id, service_id, price, duration_min, time_range, source) values
  ('00000000-0000-0000-0000-00000000e001', pg_temp.fx('barber'), pg_temp.fx('khaled'), pg_temp.fx('haircut'), 25, 30,
   tstzrange(pg_temp.local_ts(pg_temp.next_saturday(), '10:00'), pg_temp.local_ts(pg_temp.next_saturday(), '10:30'), '[)'), 'app'),
  ('00000000-0000-0000-0000-00000000e002', pg_temp.fx('barber'), pg_temp.fx('khaled'), pg_temp.fx('haircut'), 25, 30,
   tstzrange(pg_temp.local_ts(pg_temp.next_saturday(), '11:00'), pg_temp.local_ts(pg_temp.next_saturday(), '11:30'), '[)'), 'app');

-- the seed refuses to run outside the local stack

select set_config('app.settings.jwt_secret', 'a-real-production-secret', true);
select throws_ok($$ do $b$ begin
  if current_setting('app.settings.jwt_secret', true) is distinct from 'super-secret-jwt-token-with-at-least-32-characters-long' then
    raise exception 'seed.sql is for the local stack only';
  end if;
end $b$ $$, 'seed.sql is for the local stack only', 'the seed guard raises when the JWT secret is not the local default');
select set_config('app.settings.jwt_secret', 'super-secret-jwt-token-with-at-least-32-characters-long', true);
select lives_ok($$ do $b$ begin
  if current_setting('app.settings.jwt_secret', true) is distinct from 'super-secret-jwt-token-with-at-least-32-characters-long' then
    raise exception 'seed.sql is for the local stack only';
  end if;
end $b$ $$, 'and passes on the local stack');

-- sign-up accepts only the app's internal emails

select throws_ok(pg_temp.auth_email('someone@gmail.com'), 'invalid_auth_email', 'a real email cannot sign up');
select throws_ok(pg_temp.auth_email('0912345678@app.local'), 'invalid_auth_email', 'the prefix must be the normalised phone');
select throws_ok(pg_temp.auth_email('218912345678@evil.local'), 'invalid_auth_email', 'the domain must be app.local');
select throws_ok(pg_temp.auth_email('2189123456789@app.local'), 'invalid_auth_email', 'the phone has exactly 9 digits after 218');
select lives_ok(pg_temp.auth_email('218990000050@app.local'), 'a normalised phone at app.local signs up');
select is((select phone from profiles where id = (select id from auth.users where email = '218990000050@app.local')), '218990000050',
  'and gets a profile with that phone');

-- extensions live in their own schema and are not writable by clients

select is((select n.nspname::text from pg_extension e join pg_namespace n on n.oid = e.extnamespace where e.extname = 'postgis'),
  'extensions', 'postgis is installed in the extensions schema');
select is((select n.nspname::text from pg_extension e join pg_namespace n on n.oid = e.extnamespace where e.extname = 'btree_gist'),
  'extensions', 'btree_gist is installed in the extensions schema');
select ok(not (
  select bool_or(has_table_privilege(r, 'extensions.spatial_ref_sys', p))
  from unnest(array['anon', 'authenticated']) r, unnest(array['insert', 'update', 'delete', 'truncate']) p),
  'spatial_ref_sys is not writable by clients');

create function pg_temp.register_without_extensions() returns uuid language sql set search_path = public as $$
  select (register_barber('نادية', null, 'صالون نادية', pg_temp.fx('area'), null, 32.8872, 13.1913)).id
$$;
select pg_temp.login('nadia');
select lives_ok($$ select pg_temp.register_without_extensions() $$,
  'register_barber finds PostGIS without the extensions schema on the search path');
select pg_temp.logout();
select is((select round(extensions.st_y(location::extensions.geometry)::numeric, 4) from salons where owner_id = pg_temp.fx('nadia')), 32.8872::numeric,
  'and the salon carries the location');

-- admin_barber_cancellations is for admins

select pg_temp.login('ali');
select is((select count(*) from admin_barber_cancellations)::int, 0, 'a barber sees no rows in admin_barber_cancellations');
select pg_temp.login('admin');
select is((select count(*) from admin_barber_cancellations)::int, (select count(*) from barbers)::int, 'an admin sees every barber');
select pg_temp.logout();

-- the directory lists active and suspended barbers only

select ok(has_table_privilege('anon', 'public.barber_directory', 'select')
  and has_function_privilege('anon', 'public.get_available_slots(uuid,date,int)', 'execute'),
  'anon may browse the directory and the free slots');
select pg_temp.anon();
select is((select count(*) from barber_directory where id = pg_temp.fx('barber'))::int, 1, 'anon sees the active barber in the directory');
select is((select count(*) from barber_directory where id = pg_temp.fx('barber_pending'))::int, 0, 'but not a pending barber');
select ok((select count(*) from get_available_slots(pg_temp.fx('barber'), pg_temp.next_saturday(), 30)) > 0, 'anon sees free slots');
select throws_ok($$ select create_booking(pg_temp.fx('barber'), pg_temp.fx('haircut'), pg_temp.local_ts(pg_temp.next_saturday(), '12:00'), gen_random_uuid()) $$,
  '42501', null, 'anon cannot book');
select pg_temp.logout();
update barbers set status = 'suspended' where id = pg_temp.fx('barber_pending');
select pg_temp.login('khaled');
select is((select count(*) from barber_directory where id = pg_temp.fx('barber_pending'))::int, 1, 'a suspended barber stays listed');
select pg_temp.logout();
update barbers set status = 'rejected' where id = pg_temp.fx('barber_pending');
select pg_temp.login('khaled');
select is((select count(*) from barber_directory where id = pg_temp.fx('barber_pending'))::int, 0, 'a rejected barber is not listed');
select pg_temp.logout();
update barbers set status = 'pending' where id = pg_temp.fx('barber_pending');

-- a pending barber prepares the chair but cannot run a day

select pg_temp.login('murad');
select lives_ok($$ insert into barber_services (barber_id, service_id, price, duration_min) values (pg_temp.fx('barber_pending'), pg_temp.fx('beard'), 15, 20) $$,
  'a pending barber adds a service');
select lives_ok($$ update working_hours set closes_at = '20:00' where barber_id = pg_temp.fx('barber_pending') and weekday = 1 $$,
  'and edits working hours');
select lives_ok($$ update barbers set display_name = 'مراد' where id = pg_temp.fx('barber_pending') $$, 'and their profile');
select throws_ok($$ select create_manual_booking(pg_temp.fx('haircut'), pg_temp.local_ts(pg_temp.next_saturday(), '12:00'), 'x') $$,
  'barber_not_active', 'but cannot add a manual booking');
select throws_ok($$ select close_rest_of_today() $$, 'barber_not_active', 'nor close the day');
select throws_ok($$ select reopen_today() $$, 'barber_not_active', 'nor reopen it');
select throws_ok($$ select barber_stats() $$, 'barber_not_active', 'nor read statistics');
select pg_temp.logout();
update barbers set status = 'suspended' where id = pg_temp.fx('barber_pending');
select pg_temp.login('murad');
select throws_ok($$ select close_rest_of_today() $$, 'barber_not_active', 'a suspended barber cannot close the day either');
select pg_temp.logout();

-- photos are storage paths, never full URLs

select pg_temp.login('ali');
select throws_ok($$ update barbers set photo_url = 'https://example.com/avatar.jpg' where id = pg_temp.fx('barber') $$,
  '23514', null, 'photo_url must be a storage path');
select lives_ok($$ update barbers set photo_url = 'avatars/' || pg_temp.fx('ali') || '/avatar.jpg?v=1' where id = pg_temp.fx('barber') $$,
  'a path under avatars/ is accepted');
select pg_temp.login('khaled');
select throws_ok($$ update profiles set avatar_url = 'http://127.0.0.1:54321/storage/v1/object/public/avatars/x.jpg' where id = pg_temp.fx('khaled') $$,
  '23514', null, 'avatar_url must be a storage path');
select lives_ok($$ update profiles set avatar_url = 'avatars/' || pg_temp.fx('khaled') || '/avatar.png?v=2' where id = pg_temp.fx('khaled') $$,
  'a path under avatars/ is accepted');
select pg_temp.logout();

-- free text has a length limit

select is(customer_name_max_length(), 60, 'customer names are at most 60 characters');
select is(note_max_length(), 200, 'notes and closure reasons are at most 200 characters');

select pg_temp.login('ali');
select throws_ok($$ select create_manual_booking(pg_temp.fx('haircut'), pg_temp.local_ts(pg_temp.next_saturday(), '12:00'), repeat('ي', 61)) $$,
  'customer_name_too_long', 'a 61-character customer name is refused');
select is(pg_temp.error_detail($$ select create_manual_booking(pg_temp.fx('haircut'), pg_temp.local_ts(pg_temp.next_saturday(), '12:00'), repeat('ي', 61)) $$),
  'customer_name_max_length=60', 'with the limit in DETAIL');
select lives_ok($$ select create_manual_booking(pg_temp.fx('haircut'), pg_temp.local_ts(pg_temp.next_saturday(), '12:00'), ' ' || repeat('ي', 60) || ' ') $$,
  'a 60-character name is accepted, surrounding spaces ignored');
select throws_ok($$ select cancel_booking('00000000-0000-0000-0000-00000000e001', 'sick', repeat('م', 201)) $$,
  'cancel_note_too_long', 'a 201-character cancel note is refused');
select is(pg_temp.error_detail($$ select cancel_booking('00000000-0000-0000-0000-00000000e001', 'sick', repeat('م', 201)) $$),
  'note_max_length=200', 'with the limit in DETAIL');
select lives_ok($$ select cancel_booking('00000000-0000-0000-0000-00000000e001', 'sick', repeat('م', 200) || '  ') $$,
  'a 200-character note is accepted');
select lives_ok($$ select cancel_booking('00000000-0000-0000-0000-00000000e002', 'other', '   ') $$,
  'a blank note is accepted');
select pg_temp.logout();
select results_eq(
  $$ select char_length(cancel_note), cancel_note is null from bookings where id in ('00000000-0000-0000-0000-00000000e001', '00000000-0000-0000-0000-00000000e002') order by id $$,
  $$ values (200, false), (null::int, true) $$,
  'notes are trimmed and blank notes stored as null');
select throws_ok($$ insert into day_closures (barber_id, date, reason) values (pg_temp.fx('barber'), pg_temp.next_saturday(), repeat('س', 201)) $$,
  '23514', null, 'a 201-character closure reason is refused');
select lives_ok($$ insert into day_closures (barber_id, date, reason) values (pg_temp.fx('barber'), pg_temp.next_saturday(), repeat('س', 200)) $$,
  'a 200-character closure reason is accepted');

select * from finish();
rollback;
