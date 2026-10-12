begin;
select plan(65);
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
  insert into fx values ('salon2', v_salon2);

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
    (v_barber, pg_temp.fx('beard'), 15, 20),
    (v_barber2, pg_temp.fx('haircut'), 20, 30);

  insert into working_hours (barber_id, weekday, opens_at, closes_at, is_closed)
  select b, d, '10:00', '22:00', d = 5 from unnest(array[v_barber, v_barber2]) b, generate_series(0, 6) d;

  insert into breaks (barber_id, name, starts_at, ends_at) values (v_barber, 'غداء وصلاة', '13:30', '14:30');
end $$;

select pg_temp.setup();
select pg_temp.new_user('nadia', '218990000006', 'Nadia', 'barber');
select pg_temp.new_user('omar', '218990000007', 'Omar', 'barber');
select pg_temp.new_user('sami', '218990000008', 'Sami', 'barber');
select pg_temp.new_user('lina', '218990000009', 'Lina', 'customer');

-- bookings are placed inside the time left until local midnight, so the test passes at any hour
create function pg_temp.later_today(p_fraction float) returns timestamptz language sql stable as $$
  select now() + (((now() at time zone 'Africa/Tripoli')::date + 1)::timestamp at time zone 'Africa/Tripoli' - now()) * p_fraction
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

insert into bookings (id, barber_id, customer_id, customer_name, service_id, price, duration_min, time_range, source) values
  ('00000000-0000-0000-0000-00000000d001', pg_temp.fx('barber'), pg_temp.fx('khaled'), null, pg_temp.fx('haircut'), 25, 30,
   tstzrange(now() - interval '2 hours', now() - interval '90 minutes', '[)'), 'app'),
  ('00000000-0000-0000-0000-00000000d002', pg_temp.fx('barber'), pg_temp.fx('khaled'), null, pg_temp.fx('haircut'), 25, 30,
   tstzrange(pg_temp.local_ts(pg_temp.next_saturday(), '10:00'), pg_temp.local_ts(pg_temp.next_saturday(), '10:30'), '[)'), 'app'),
  ('00000000-0000-0000-0000-00000000d003', pg_temp.fx('barber'), null, 'يوسف', pg_temp.fx('haircut'), 25, 30,
   tstzrange(pg_temp.local_ts(pg_temp.next_saturday(), '15:00'), pg_temp.local_ts(pg_temp.next_saturday(), '15:30'), '[)'), 'manual'),
  ('00000000-0000-0000-0000-00000000d004', pg_temp.fx('barber'), pg_temp.fx('salem'), null, pg_temp.fx('haircut'), 25, 30,
   tstzrange(pg_temp.later_today(0.1), pg_temp.later_today(0.15), '[)'), 'app'),
  ('00000000-0000-0000-0000-00000000d005', pg_temp.fx('barber'), pg_temp.fx('salem'), null, pg_temp.fx('haircut'), 25, 30,
   tstzrange(now() - interval '25 minutes', least(now() + interval '5 minutes', pg_temp.later_today(0.05)), '[)'), 'app');

-- status changes are for the booking's barber only

select pg_temp.login('khaled');
select throws_ok($$ select set_booking_status('00000000-0000-0000-0000-00000000d001', 'completed') $$,
  'booking_not_found', 'a customer cannot change the status of their own booking');
select pg_temp.login('salem');
select throws_ok($$ select set_booking_status('00000000-0000-0000-0000-00000000d001', 'no_show') $$,
  'booking_not_found', 'a customer cannot mark another customer as no-show');
select pg_temp.login('murad');
select throws_ok($$ select set_booking_status('00000000-0000-0000-0000-00000000d001', 'no_show') $$,
  'booking_not_found', 'another barber cannot change the status');
select pg_temp.logout();
select is((select status from bookings where id = '00000000-0000-0000-0000-00000000d001'), 'confirmed', 'the booking is untouched');

select pg_temp.login('ali');
select throws_ok($$ select set_booking_status('00000000-0000-0000-0000-00000000d002', 'completed') $$,
  'booking_not_started', 'attended cannot be set before the booking starts');
select throws_ok($$ select set_booking_status('00000000-0000-0000-0000-00000000d002', 'no_show') $$,
  'booking_not_started', 'no-show cannot be set before the booking starts');
select lives_ok($$ select set_booking_status('00000000-0000-0000-0000-00000000d001', 'completed') $$,
  'the barber marks a started booking as attended');

-- cancellations are for the two parties only

select pg_temp.login('salem');
select throws_ok($$ select cancel_booking('00000000-0000-0000-0000-00000000d002') $$,
  'booking_not_found', 'a customer cannot cancel another customer''s booking');
select pg_temp.login('khaled');
select throws_ok($$ select cancel_booking('00000000-0000-0000-0000-00000000d003') $$,
  'booking_not_found', 'a customer cannot cancel a manual booking');
select pg_temp.login('murad');
select throws_ok($$ select cancel_booking('00000000-0000-0000-0000-00000000d003') $$,
  'booking_not_found', 'another barber cannot cancel a manual booking');
select pg_temp.logout();
select is((select count(*) from bookings where id in ('00000000-0000-0000-0000-00000000d002', '00000000-0000-0000-0000-00000000d003') and status = 'cancelled')::int,
  0, 'nothing was cancelled');

select pg_temp.login('salem');
select throws_ok($$ select cancel_booking('00000000-0000-0000-0000-00000000d004') $$,
  'cancellation_window_passed', 'the 2-hour rule applies to the customer');
select is(pg_temp.error_detail($$ select cancel_booking('00000000-0000-0000-0000-00000000d004') $$),
  'cancellation_window_minutes=120', 'the window is reported in DETAIL');

-- views are read-only

select pg_temp.login('khaled');
select throws_ok($$ update salon_barbers set display_name = 'x' $$, '42501', null, 'salon_barbers cannot be updated');
select throws_ok($$ insert into salon_barbers (id, salon_id, display_name, is_vip, rating_avg, rating_count)
  values (gen_random_uuid(), pg_temp.fx('salon'), 'x', true, 5, 999) $$, '42501', null, 'salon_barbers cannot be inserted into');
select throws_ok($$ delete from salon_barbers $$, '42501', null, 'salon_barbers cannot be deleted from');
select pg_temp.logout();
select ok(not (
  select bool_or(has_table_privilege(r, v, p))
  from unnest(array['anon', 'authenticated']) r,
       unnest(array['public.salon_barbers', 'public.salon_hours', 'public.admin_barber_cancellations', 'public.barber_directory']) v,
       unnest(array['insert', 'update', 'delete', 'truncate']) p), 'clients hold no write privilege on any view');
select is((select display_name from barbers where id = pg_temp.fx('barber')), 'علي القماطي', 'barber rows are unchanged');

-- barber row insert and registration

select pg_temp.login('nadia');
select throws_ok($$ insert into barbers (profile_id, salon_id, display_name, rating_avg, rating_count)
  values (pg_temp.fx('nadia'), pg_temp.fx('salon'), 'نادية', 5, 999) $$, '42501', null, 'a barber cannot insert a row with a rating');
select lives_ok($$ select register_barber('نادية', null, 'صالون نادية', pg_temp.fx('area'), 'شارع الزاوية', 32.8872, 13.1913) $$,
  'register_barber creates the salon and the barber row');
select pg_temp.logout();
select results_eq(
  $$ select b.status::text, s.owner_id = pg_temp.fx('nadia'), s.area_id = pg_temp.fx('area'), s.address, round(st_y(s.location::geometry)::numeric, 4)
     from barbers b join salons s on s.id = b.salon_id where b.profile_id = pg_temp.fx('nadia') $$,
  $$ values ('pending', true, true, 'شارع الزاوية', 32.8872::numeric) $$,
  'the new salon is owned by the barber and carries the location');
insert into fx select 'salon_nadia', salon_id from barbers where profile_id = pg_temp.fx('nadia');

select pg_temp.login('nadia');
select is((select id from register_barber('اسم آخر')), (select id from barbers where profile_id = pg_temp.fx('nadia')),
  'calling register_barber again returns the existing row');
select pg_temp.logout();
select is((select count(*) from barbers where profile_id = pg_temp.fx('nadia'))::int, 1, 'and creates nothing');
select is((select count(*) from salons where owner_id = pg_temp.fx('nadia'))::int, 1, 'not even a second salon');

select pg_temp.login('omar');
select lives_ok($$ select register_barber('عمر', pg_temp.fx('salon_nadia')) $$, 'a barber joins an existing salon');
select pg_temp.logout();
select is((select salon_id from barbers where profile_id = pg_temp.fx('omar')), pg_temp.fx('salon_nadia'), 'and is listed under it');

select pg_temp.login('khaled');
select throws_ok($$ select register_barber('خالد') $$, 'not_a_barber', 'a customer cannot register as a barber');
select pg_temp.login('sami');
select throws_ok($$ select register_barber('  ') $$, 'display_name_required', 'a name is required');
select throws_ok($$ select register_barber('سامي', gen_random_uuid()) $$, 'salon_not_found', 'joining an unknown salon fails');

-- salon location: owner or admin only

select pg_temp.login('nadia');
select lives_ok($$ update salons set address = 'شارع عمر المختار' where id = pg_temp.fx('salon_nadia') $$, 'the owner edits the salon');
select pg_temp.login('omar');
update salons set address = 'x' where id = pg_temp.fx('salon_nadia');
select pg_temp.logout();
select is((select address from salons where id = pg_temp.fx('salon_nadia')), 'شارع عمر المختار', 'a barber who joined the salon cannot edit it');
select pg_temp.login('admin');
select lives_ok($$ update salons set address = 'تعديل الإدارة' where id = pg_temp.fx('salon_nadia') $$, 'an admin edits the salon');
select pg_temp.logout();
select is((select address from salons where id = pg_temp.fx('salon_nadia')), 'تعديل الإدارة', 'and the change is saved');

-- column guards

select pg_temp.login('ali');
select throws_ok($$ update barbers set salon_id = pg_temp.fx('salon2') where profile_id = pg_temp.fx('ali') $$,
  'admin_only', 'a barber cannot move themselves to another salon');
select pg_temp.login('khaled');
select throws_ok($$ update profiles set phone = '218990000099' where id = pg_temp.fx('khaled') $$,
  'admin_only', 'a user cannot change their own phone');
select pg_temp.logout();

-- the profile phone comes from the auth email, not from metadata

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, email_confirmed_at)
values (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '218990000050@app.local', 'x',
        '{"provider":"email","providers":["email"]}', jsonb_build_object('full_name', 'Mismatch', 'role', 'customer', 'phone', '218990000099'), now(), now(), now());
select is((select phone from profiles where full_name = 'Mismatch'), '218990000050', 'metadata phone is ignored');

-- manual bookings follow the schedule

select pg_temp.login('ali');
select throws_ok($$ select create_manual_booking(pg_temp.fx('haircut'), pg_temp.local_ts(pg_temp.next_saturday(), '13:45'), 'x') $$,
  'inside_break', 'a manual booking inside a break is refused');
select throws_ok($$ select create_manual_booking(pg_temp.fx('haircut'), pg_temp.local_ts(pg_temp.next_saturday(), '21:45'), 'x') $$,
  'outside_working_hours', 'a manual booking ending after closing time is refused');
select throws_ok($$ select create_manual_booking(pg_temp.fx('haircut'), pg_temp.local_ts(pg_temp.next_saturday() + 6, '12:00'), 'x') $$,
  'outside_working_hours', 'a manual booking on a day off is refused');
select pg_temp.logout();
insert into day_closures (barber_id, date, from_time) values (pg_temp.fx('barber'), pg_temp.next_saturday(), '18:00');
select pg_temp.login('ali');
select throws_ok($$ select create_manual_booking(pg_temp.fx('haircut'), pg_temp.local_ts(pg_temp.next_saturday(), '18:30'), 'x') $$,
  'day_closed', 'a manual booking after a partial closure is refused');
select lives_ok($$ select create_manual_booking(pg_temp.fx('haircut'), pg_temp.local_ts(pg_temp.next_saturday(), '17:00'), 'x') $$,
  'a manual booking ending before the closure is accepted');
select pg_temp.logout();
update day_closures set from_time = null where barber_id = pg_temp.fx('barber') and date = pg_temp.next_saturday();
select pg_temp.login('ali');
select throws_ok($$ select create_manual_booking(pg_temp.fx('haircut'), pg_temp.local_ts(pg_temp.next_saturday(), '11:00'), 'x') $$,
  'day_closed', 'a manual booking on a closed day is refused');
select pg_temp.logout();
delete from day_closures where barber_id = pg_temp.fx('barber') and date = pg_temp.next_saturday();

-- error codes carry their numbers in DETAIL, and the limit check is serialised

update profiles set blocked_at = now() where id = pg_temp.fx('salem');
select pg_temp.login('salem');
select throws_ok($$ select create_booking(pg_temp.fx('barber'), pg_temp.fx('haircut'), pg_temp.local_ts(pg_temp.next_saturday(), '12:00')) $$,
  'customer_blocked', 'a blocked customer gets a fixed code');
select is(pg_temp.error_detail($$ select create_booking(pg_temp.fx('barber'), pg_temp.fx('haircut'), pg_temp.local_ts(pg_temp.next_saturday(), '12:00')) $$),
  'no_show_limit=3', 'with the limit in DETAIL');
select pg_temp.logout();
update profiles set blocked_at = null where id = pg_temp.fx('salem');

select pg_temp.login('lina');
select is((select xmax::text from profiles where id = pg_temp.fx('lina')), '0', 'the customer profile row is not locked yet');
select create_booking(pg_temp.fx('barber'), pg_temp.fx('haircut'), pg_temp.local_ts(pg_temp.next_saturday(), '19:00'));
select isnt((select xmax::text from profiles where id = pg_temp.fx('lina')), '0', 'create_booking locks the customer profile row');
select pg_temp.login('khaled');
select lives_ok($$ select create_booking(pg_temp.fx('barber'), pg_temp.fx('haircut'), pg_temp.local_ts(pg_temp.next_saturday(), '12:00')) $$,
  'a second upcoming booking is allowed');
select throws_ok($$ select create_booking(pg_temp.fx('barber'), pg_temp.fx('beard'), pg_temp.local_ts(pg_temp.next_saturday(), '16:00')) $$,
  'booking_limit_reached', 'the upcoming limit is a fixed code');
select is(pg_temp.error_detail($$ select create_booking(pg_temp.fx('barber'), pg_temp.fx('beard'), pg_temp.local_ts(pg_temp.next_saturday(), '16:00')) $$),
  'upcoming_booking_limit=2', 'with the limit in DETAIL');

-- only active barbers create salons directly

select pg_temp.login('murad');
select throws_ok($$ insert into salons (name, owner_id) values ('x', pg_temp.fx('murad')) $$, '42501', null, 'a pending barber cannot create a salon');
select pg_temp.login('ali');
select lives_ok($$ insert into salons (name, owner_id) values ('فرع ثانٍ', pg_temp.fx('ali')) $$, 'an active barber can');
select pg_temp.logout();

-- RPCs and the directory need a session

select ok((
  select bool_and(not has_function_privilege('anon', f, 'execute') and has_function_privilege('authenticated', f, 'execute'))
  from unnest(array[
    'public.register_barber(text,uuid,text,uuid,text,double precision,double precision)',
    'public.reopen_today()',
    'public.activate_subscription(uuid,int,numeric,text)',
    'public.unblock_customer(uuid)',
    'public.create_booking(uuid,uuid,timestamptz)',
    'public.create_manual_booking(uuid,timestamptz,text)',
    'public.set_booking_status(uuid,public.booking_status)',
    'public.cancel_booking(uuid,public.barber_cancel_reason,text)',
    'public.close_rest_of_today()'
  ]) f), 'RPCs are executable by authenticated users only');
select ok(has_table_privilege('anon', 'public.barber_directory', 'select'), 'anon can browse the directory');

-- closing and reopening the day

select pg_temp.login('ali');
select results_eq($$ select id from close_rest_of_today() $$, $$ values ('00000000-0000-0000-0000-00000000d004'::uuid) $$,
  'the booking in progress is not listed for cancellation');
select pg_temp.logout();
select is((select reason from day_closures where barber_id = pg_temp.fx('barber') and date = (now() at time zone app_timezone())::date),
  'closed_early', 'the closure reason is a code');
select pg_temp.login('ali');
select ok(reopen_today(), 'reopen_today removes the closure');
select ok(not reopen_today(), 'and reports when there was none');
select pg_temp.logout();
select is((select count(*) from day_closures where barber_id = pg_temp.fx('barber'))::int, 0, 'no closure is left');
select pg_temp.login('khaled');
select throws_ok($$ select reopen_today() $$, 'not_a_barber', 'customers cannot reopen a day');
select pg_temp.logout();

-- the directory keeps lapsed barbers visible, with a phone

update barbers set status = 'active', subscription_ends_at = now() - interval '1 day' where id = pg_temp.fx('barber_pending');
select pg_temp.login('khaled');
select is((select count(*) from barbers where id = pg_temp.fx('barber_pending'))::int, 0, 'a lapsed barber is hidden from the barbers table');
select results_eq(
  $$ select display_name, phone, is_bookable, salon_name from barber_directory where id = pg_temp.fx('barber_pending') $$,
  $$ values ('مراد الزنتاني', '218990000003', false, 'حلاق الملوك') $$,
  'but visible in the directory with the salon and phone');
select pg_temp.logout();

-- avatars: public bucket, own folder only

select is((select public from storage.buckets where id = 'avatars'), true, 'the avatars bucket is public');
select pg_temp.login('khaled');
select lives_ok($$ insert into storage.objects (bucket_id, name, owner_id)
  values ('avatars', pg_temp.fx('khaled') || '/avatar.jpg', pg_temp.fx('khaled')::text) $$, 'a user uploads into their own folder');
select lives_ok($$ update storage.objects set metadata = '{}' where bucket_id = 'avatars' and name = pg_temp.fx('khaled') || '/avatar.jpg' $$,
  'and replaces it');
select throws_ok($$ insert into storage.objects (bucket_id, name, owner_id)
  values ('avatars', pg_temp.fx('salem') || '/avatar.jpg', pg_temp.fx('khaled')::text) $$, '42501', null, 'but not into another user''s folder');
select pg_temp.logout();

select * from finish();
rollback;
