begin;
select plan(49);
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

create function pg_temp.setup() returns void language plpgsql as $$
declare
  v_area uuid := (select id from areas where name = 'حي الأندلس');
  v_salon uuid;
  v_barber uuid;
  v_barber2 uuid;
  v_barber3 uuid;
  v_haircut uuid := (select id from service_catalog where code = 'haircut');
begin
  perform pg_temp.new_user('admin', '218990000001', 'Admin', 'customer');
  update profiles set role = 'admin' where id = pg_temp.fx('admin');

  perform pg_temp.new_user('ali', '218990000002', 'Ali', 'barber');
  perform pg_temp.new_user('murad', '218990000003', 'Murad', 'barber');
  perform pg_temp.new_user('khaled', '218990000004', 'Khaled', 'customer');
  perform pg_temp.new_user('salem', '218990000005', 'Salem', 'customer');
  perform pg_temp.new_user('nadia', '218990000006', 'Nadia', 'barber');

  insert into salons (name, owner_id, area_id) values ('صالون الأناقة', pg_temp.fx('ali'), v_area) returning id into v_salon;
  insert into fx values ('salon', v_salon);

  insert into barbers (profile_id, salon_id, display_name, status, subscription_ends_at)
  values (pg_temp.fx('ali'), v_salon, 'علي القماطي', 'active', now() + interval '30 days') returning id into v_barber;
  insert into fx values ('barber', v_barber);

  insert into barbers (profile_id, salon_id, display_name, status)
  values (pg_temp.fx('murad'), v_salon, 'مراد الزنتاني', 'pending') returning id into v_barber2;
  insert into fx values ('barber_pending', v_barber2);

  insert into barbers (profile_id, salon_id, display_name, status, subscription_ends_at)
  values (pg_temp.fx('nadia'), v_salon, 'نادية', 'suspended', now() - interval '1 day') returning id into v_barber3;
  insert into fx values ('barber_suspended', v_barber3);

  insert into fx values ('haircut', v_haircut);

  insert into working_hours (barber_id, weekday, opens_at, closes_at, is_closed)
  select b, d, '10:00', '22:00', false from unnest(array[v_barber, v_barber2, v_barber3]) b, generate_series(0, 6) d;

  insert into day_closures (barber_id, date, reason) values (v_barber, pg_temp.next_saturday() + 1, 'سفر');

  insert into bookings (id, barber_id, customer_id, service_id, price, duration_min, time_range, status, cancelled_at, cancelled_by) values
    ('00000000-0000-0000-0000-00000000c001', v_barber, pg_temp.fx('khaled'), v_haircut, 25, 30,
     tstzrange(now() - interval '3 hours', now() - interval '2 hours 30 minutes'), 'completed', null, null),
    ('00000000-0000-0000-0000-00000000c002', v_barber, pg_temp.fx('khaled'), v_haircut, 25, 30,
     tstzrange(now() - interval '5 hours', now() - interval '4 hours 30 minutes'), 'completed', null, null),
    ('00000000-0000-0000-0000-00000000c003', v_barber, pg_temp.fx('khaled'), v_haircut, 25, 30,
     tstzrange(now() - interval '7 hours', now() - interval '6 hours 30 minutes'), 'no_show', null, null),
    ('00000000-0000-0000-0000-00000000c004', v_barber, pg_temp.fx('khaled'), v_haircut, 25, 30,
     tstzrange(now() - interval '9 hours', now() - interval '8 hours 30 minutes'), 'cancelled', now() - interval '1 day', pg_temp.fx('khaled'));
end $$;

select pg_temp.setup();

-- a review is written once by the customer, within the limits

select is(review_max_tags(), 5, 'a review carries at most 5 tags');
select is(cardinality(review_tags()), 5, 'the allowed tags are listed in one SQL constant');

select pg_temp.login('khaled');
select throws_ok($$ insert into reviews (booking_id, customer_id, rating)
  values ('00000000-0000-0000-0000-00000000c001', auth.uid(), 0) $$,
  '23514', null, 'a rating of 0 is rejected');
select throws_ok($$ insert into reviews (booking_id, customer_id, rating, tags)
  values ('00000000-0000-0000-0000-00000000c001', auth.uid(), 5, array['النظافة', 'رائع']) $$,
  '23514', null, 'a tag outside the allowed list is rejected');
select throws_ok(format($$ insert into reviews (booking_id, customer_id, rating, tags)
  values ('00000000-0000-0000-0000-00000000c001', auth.uid(), 5, array[%L]) $$, repeat('ا', 101)),
  '23514', null, 'tags longer than 100 characters in total are rejected');
select throws_ok($$ insert into reviews (booking_id, customer_id, rating, tags)
  values ('00000000-0000-0000-0000-00000000c001', auth.uid(), 5, array['النظافة', 'النظافة', 'النظافة', 'النظافة', 'النظافة', 'النظافة']) $$,
  '23514', null, 'more than 5 tags are rejected');
select throws_ok($$ insert into reviews (booking_id, customer_id, rating, created_at)
  values ('00000000-0000-0000-0000-00000000c001', auth.uid(), 5, now() - interval '1 year') $$,
  '42501', null, 'a customer cannot set created_at on a review');
select throws_ok($$ insert into reviews (booking_id, customer_id, rating)
  values ('00000000-0000-0000-0000-00000000c003', auth.uid(), 5) $$,
  'booking_not_completed', 'a no-show booking cannot be reviewed');
select throws_ok($$ insert into reviews (booking_id, customer_id, rating)
  values ('00000000-0000-0000-0000-00000000c004', auth.uid(), 5) $$,
  'booking_not_completed', 'a cancelled booking cannot be reviewed');
select lives_ok($$ insert into reviews (booking_id, customer_id, rating, tags)
  values ('00000000-0000-0000-0000-00000000c001', auth.uid(), 5, review_tags()) $$,
  'every allowed tag at once is accepted');
select lives_ok($$ insert into reviews (booking_id, customer_id, rating, tags)
  values ('00000000-0000-0000-0000-00000000c002', auth.uid(), 3, '{}') $$,
  'a review without tags is accepted');
select is((select rating_avg from barbers where id = pg_temp.fx('barber')), 4.00::numeric, 'the average covers both reviews');
select pg_temp.logout();

delete from reviews where booking_id = '00000000-0000-0000-0000-00000000c002';
select results_eq(
  $$ select rating_avg, rating_count from barbers where id = pg_temp.fx('barber') $$,
  $$ values (5.00::numeric, 1) $$,
  'deleting a review refreshes the average and the count');
delete from reviews where booking_id = '00000000-0000-0000-0000-00000000c001';
select results_eq(
  $$ select rating_avg, rating_count from barbers where id = pg_temp.fx('barber') $$,
  $$ values (0.00::numeric, 0) $$,
  'a barber without reviews is back to zero');
insert into reviews (booking_id, customer_id, rating, tags)
values ('00000000-0000-0000-0000-00000000c001', pg_temp.fx('khaled'), 5, array['النظافة']);

-- reviews are read by the two parties and the admin

select ok(not has_table_privilege('anon', 'public.reviews', 'select'), 'anon holds no select privilege on reviews');
select pg_temp.anon();
select throws_ok($$ select count(*) from reviews $$, '42501', null, 'anon cannot read reviews');
select pg_temp.login('khaled');
select is((select count(*) from reviews)::int, 1, 'the customer reads their own review');
select pg_temp.login('salem');
select is((select count(*) from reviews)::int, 0, 'another customer does not');
select pg_temp.login('ali');
select is((select count(*) from reviews)::int, 1, 'the reviewed barber reads it');
select pg_temp.login('murad');
select is((select count(*) from reviews)::int, 0, 'another barber does not');
select pg_temp.login('admin');
select is((select count(*) from reviews)::int, 1, 'the admin reads it');
select pg_temp.logout();

-- free slots exist only for bookable barbers

select pg_temp.anon();
select ok((select count(*) from get_available_slots(pg_temp.fx('barber'), pg_temp.next_saturday(), 30)) > 0,
  'an active barber has free slots');
select is((select count(*) from get_available_slots(pg_temp.fx('barber_pending'), pg_temp.next_saturday(), 30))::int, 0,
  'a pending barber has none');
select is((select count(*) from get_available_slots(pg_temp.fx('barber_suspended'), pg_temp.next_saturday(), 30))::int, 0,
  'nor a suspended one');
select pg_temp.logout();
update barbers set subscription_ends_at = now() - interval '1 day' where id = pg_temp.fx('barber');
select is((select count(*) from get_available_slots(pg_temp.fx('barber'), pg_temp.next_saturday(), 30))::int, 0,
  'nor a barber whose subscription lapsed');
update barbers set subscription_ends_at = now() + interval '30 days' where id = pg_temp.fx('barber');

-- the auth email never changes

select throws_ok($$ update auth.users set email = '218990000099@app.local' where id = pg_temp.fx('khaled') $$,
  'email_change_not_allowed', 'the auth email cannot be changed');
select lives_ok($$ update auth.users set email = '218990000004@app.local', updated_at = now() where id = pg_temp.fx('khaled') $$,
  'an update that keeps the email passes');
select is((select phone from profiles where id = pg_temp.fx('khaled')), '218990000004', 'the profile phone is untouched');

-- visitors read only the public columns

select ok(not has_column_privilege('anon', 'public.barbers', 'profile_id', 'select')
  and not has_column_privilege('anon', 'public.barbers', 'subscription_ends_at', 'select')
  and not has_column_privilege('anon', 'public.salons', 'owner_id', 'select')
  and not has_column_privilege('anon', 'public.day_closures', 'reason', 'select'),
  'anon cannot read profile_id, subscription_ends_at, owner_id or closure reasons');
select pg_temp.anon();
select is((select display_name from barbers where id = pg_temp.fx('barber')), 'علي القماطي', 'anon still reads a bookable barber''s name');
select throws_ok($$ select profile_id from barbers $$, '42501', null, 'but not their account id');
select throws_ok($$ select subscription_ends_at from barbers $$, '42501', null, 'nor their subscription end');
select is((select name from salons where id = pg_temp.fx('salon')), 'صالون الأناقة', 'anon reads the salon name');
select throws_ok($$ select owner_id from salons $$, '42501', null, 'but not its owner');
select is((select count(*) from day_closures where barber_id = pg_temp.fx('barber'))::int, 1, 'anon sees that a day is closed');
select throws_ok($$ select reason from day_closures $$, '42501', null, 'but not why');
select results_eq(
  $$ select display_name, is_bookable from salon_barbers where salon_id = pg_temp.fx('salon') order by display_name $$,
  $$ values ('علي القماطي', true), ('نادية', false) $$,
  'salon_barbers lists active and suspended barbers only, never a pending one');
select pg_temp.logout();

-- only signed-in users list the avatars bucket

insert into storage.objects (bucket_id, name, owner_id)
values ('avatars', pg_temp.fx('khaled') || '/avatar.jpg', pg_temp.fx('khaled')::text);
select pg_temp.anon();
select is((select count(*) from storage.objects where bucket_id = 'avatars')::int, 0, 'anon cannot list avatars');
select pg_temp.login('salem');
select is((select count(*) from storage.objects where bucket_id = 'avatars')::int, 1, 'a signed-in user can');
select pg_temp.logout();

-- created_at belongs to the database

select ok(not has_column_privilege('authenticated', 'public.profiles', 'created_at', 'update')
  and not has_column_privilege('authenticated', 'public.profiles', 'created_at', 'insert')
  and not has_column_privilege('authenticated', 'public.reviews', 'created_at', 'update')
  and not has_column_privilege('authenticated', 'public.reviews', 'created_at', 'insert'),
  'clients cannot set created_at on profiles or reviews');
select pg_temp.login('khaled');
select throws_ok($$ update profiles set created_at = now() - interval '1 year' where id = pg_temp.fx('khaled') $$,
  '42501', null, 'a customer cannot change their profile created_at');
select throws_ok($$ update reviews set created_at = now() - interval '1 year' where customer_id = pg_temp.fx('khaled') $$,
  '42501', null, 'nor a review''s');
select lives_ok($$ update profiles set full_name = 'خالد' where id = pg_temp.fx('khaled') $$,
  'but still edits their name');

-- names are bounded

select is(full_name_max_length(), 60, 'full names are at most 60 characters');
select throws_ok(format($$ update profiles set full_name = %L where id = pg_temp.fx('khaled') $$, repeat('ا', 61)),
  '23514', null, 'a 61-character name is refused');
select lives_ok(format($$ update profiles set full_name = %L where id = pg_temp.fx('khaled') $$, repeat('ا', 60)),
  'a 60-character name is accepted');
select pg_temp.logout();
select throws_ok(format($$ select pg_temp.new_user('long', '218990000050', %L, 'customer') $$, repeat('ا', 61)),
  'full_name_too_long', 'sign-up with a 61-character name is refused');
select is(pg_temp.error_detail(format($$ select pg_temp.new_user('long', '218990000050', %L, 'customer') $$, repeat('ا', 61))),
  'full_name_max_length=60', 'with the limit in DETAIL');
select lives_ok(format($$ select pg_temp.new_user('fits', '218990000051', %L, 'customer') $$, repeat('ا', 60)),
  'sign-up with a 60-character name passes');

select * from finish();
rollback;
