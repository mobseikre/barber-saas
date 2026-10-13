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

create function pg_temp.logout() returns void language plpgsql as $$
begin
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
end $$;

create function pg_temp.status_of(p_key text) returns barber_status language sql as $$
  select status from barbers where id = pg_temp.fx(p_key)
$$;

select pg_temp.new_user('admin', '218990000001', 'الإدارة', 'customer');
update profiles set role = 'admin' where id = pg_temp.fx('admin');
select pg_temp.new_user('ali', '218990000002', 'علي', 'barber');
select pg_temp.new_user('murad', '218990000003', 'مراد', 'barber');
select pg_temp.new_user('khaled', '218990000004', 'خالد المقريف', 'customer');

insert into fx select 'area', id from areas where name = 'حي الأندلس';
insert into fx select 'haircut', id from service_catalog where code = 'haircut';

insert into salons (name, owner_id, area_id, address, location)
values ('صالون الأناقة', pg_temp.fx('ali'), pg_temp.fx('area'), 'شارع الجمهورية',
        extensions.st_setsrid(extensions.st_makepoint(13.1146, 32.8752), 4326)::extensions.geography);
insert into fx select 'salon', id from salons;

insert into barbers (profile_id, salon_id, display_name, status)
values (pg_temp.fx('ali'), pg_temp.fx('salon'), 'علي القماطي', 'pending');
insert into fx select 'ali_barber', id from barbers where profile_id = pg_temp.fx('ali');
insert into barbers (profile_id, salon_id, display_name, status)
values (pg_temp.fx('murad'), pg_temp.fx('salon'), 'مراد الزنتاني', 'pending');
insert into fx select 'murad_barber', id from barbers where profile_id = pg_temp.fx('murad');
insert into barbers (salon_id, display_name, status) values (pg_temp.fx('salon'), 'وليد الشريف', 'pending');
insert into fx select 'walid_barber', id from barbers where profile_id is null;

-- Only admins can call the actions

select pg_temp.login('ali');
select throws_ok(format('select approve_barber(%L)', pg_temp.fx('ali_barber')), 'admin_only', 'a barber cannot approve themselves');
select throws_ok(format('select reject_barber(%L)', pg_temp.fx('murad_barber')), 'admin_only', 'a barber cannot reject another barber');
select throws_ok(format('select suspend_barber(%L)', pg_temp.fx('murad_barber')), 'admin_only', 'a barber cannot suspend another barber');
select throws_ok(format('select admin_set_salon_location(%L, 32.8, 13.1)', pg_temp.fx('salon')), 'admin_only', 'a barber cannot move a salon pin through the admin action');
select throws_ok('select * from admin_bookings_per_day(7)', 'admin_only', 'reports are admin only: bookings per day');
select throws_ok('select * from admin_revenue_per_month(6)', 'admin_only', 'reports are admin only: revenue');
select is((select count(*) from admin_barbers), 0::bigint, 'admin_barbers is empty for a barber');
select is((select count(*) from admin_salons), 0::bigint, 'admin_salons is empty for a barber');
select is((select count(*) from admin_subscription_payments), 0::bigint, 'the payments log is empty for a barber');
select pg_temp.logout();

select pg_temp.login('khaled');
select throws_ok(format('select approve_barber(%L)', pg_temp.fx('ali_barber')), 'admin_only', 'a customer cannot approve a barber');
select pg_temp.logout();

set local role anon;
select throws_ok(format('select approve_barber(%L)', pg_temp.fx('ali_barber')), '42501', null, 'anon cannot call the actions');
select throws_ok('select * from admin_barbers', '42501', null, 'anon cannot read admin_barbers');
select throws_ok('select * from admin_salons', '42501', null, 'anon cannot read admin_salons');
select throws_ok('select * from admin_subscription_payments', '42501', null, 'anon cannot read the payments log');
select throws_ok('select * from admin_today_counts()', '42501', null, 'anon cannot call the today counts');
reset role;

select ok(not has_function_privilege('authenticated', 'public.admin_set_barber_status(uuid,public.barber_status,public.barber_status)', 'execute'),
  'the status primitive is not callable directly; only its wrappers are');
select ok(has_function_privilege('authenticated', 'public.approve_barber(uuid)', 'execute'), 'the wrappers stay callable');

-- Approve, reject, suspend, reactivate

select pg_temp.login('admin');
select is((select count(*) from admin_barbers where status = 'pending'), 3::bigint, 'the queue lists the pending barbers');
select is((select phone from admin_barbers where id = pg_temp.fx('ali_barber')), '218990000002', 'the queue shows the phone');
select is((select latitude from admin_barbers where id = pg_temp.fx('ali_barber')), 32.8752::double precision, 'the queue shows the salon latitude');

select is((select (approve_barber(pg_temp.fx('ali_barber'))).status), 'active'::barber_status, 'approve activates a pending barber');
select throws_ok(format('select approve_barber(%L)', pg_temp.fx('ali_barber')), 'invalid_barber_status', 'approving twice is refused');
select throws_ok(format('select approve_barber(%L)', pg_temp.fx('walid_barber')), 'barber_has_no_account', 'a barber without an account cannot be activated');
select is((select (reject_barber(pg_temp.fx('murad_barber'))).status), 'rejected'::barber_status, 'reject turns a pending barber down');
select throws_ok(format('select suspend_barber(%L)', pg_temp.fx('murad_barber')), 'invalid_barber_status', 'a rejected barber cannot be suspended');
select throws_ok(format('select reject_barber(%L)', pg_temp.fx('ali_barber')), 'invalid_barber_status', 'an active barber cannot be rejected');
select is((select (suspend_barber(pg_temp.fx('ali_barber'))).status), 'suspended'::barber_status, 'suspend pauses an active barber');
select is((select (reactivate_barber(pg_temp.fx('ali_barber'))).status), 'active'::barber_status, 'reactivate brings a suspended barber back');
select throws_ok(format('select reactivate_barber(%L)', pg_temp.fx('ali_barber')), 'invalid_barber_status', 'reactivating an active barber is refused');
select throws_ok(format('select approve_barber(%L)', gen_random_uuid()), 'barber_not_found', 'unknown barber');

-- Salon pin

select is((select st_y((admin_set_salon_location(pg_temp.fx('salon'), 32.9, 13.2)).location::extensions.geometry)), 32.9::double precision, 'the admin corrects the pin');
select throws_ok(format('select admin_set_salon_location(%L, 91, 13)', pg_temp.fx('salon')), 'invalid_location', 'latitude out of range');
select throws_ok(format('select admin_set_salon_location(%L, 32, 181)', pg_temp.fx('salon')), 'invalid_location', 'longitude out of range');
select throws_ok(format('select admin_set_salon_location(%L, null, 13)', pg_temp.fx('salon')), 'invalid_location', 'missing coordinate');
select throws_ok(format('select admin_set_salon_location(%L, 32, 13)', gen_random_uuid()), 'salon_not_found', 'unknown salon');

-- Subscriptions feed the payments log and the reports

select activate_subscription(pg_temp.fx('ali_barber'), 1, 50, 'نقداً');
select is((select amount from admin_subscription_payments where barber_id = pg_temp.fx('ali_barber')), 50::numeric, 'the payments log shows the payment');
select is((select recorded_by_name from admin_subscription_payments where barber_id = pg_temp.fx('ali_barber')), 'الإدارة', 'the log names the admin who recorded it');
select is((select revenue from admin_revenue_per_month(3) order by month desc limit 1), 50::numeric, 'revenue counts this month');
select is((select count(*) from admin_revenue_per_month(12)), 12::bigint, 'one row per month, empty months included');

insert into bookings (barber_id, customer_id, service_id, price, duration_min, time_range, status)
values (pg_temp.fx('ali_barber'), pg_temp.fx('khaled'), pg_temp.fx('haircut'), 25, 30,
        tstzrange(now() - interval '1 day', now() - interval '1 day' + interval '30 minutes', '[)'), 'completed');
select is((select sum(total)::int from admin_bookings_per_day(30)), 1, 'the booking is counted once in the last 30 days');
select throws_ok('select * from admin_bookings_per_day(0)', 'invalid_range', 'range is validated');
select is((select bookings_month from admin_barbers where id = pg_temp.fx('ali_barber')),
  (select count(*) from bookings where barber_id = pg_temp.fx('ali_barber')
     and date_trunc('month', lower(time_range) at time zone app_timezone()) = date_trunc('month', now() at time zone app_timezone())),
  'admin_barbers counts this month''s bookings per barber');
select is((select bookings_month from admin_barbers where id = pg_temp.fx('murad_barber')), 0::bigint, 'a barber without bookings shows 0');

-- Today's counts go by start time, on the Tripoli calendar day
insert into bookings (barber_id, customer_id, service_id, price, duration_min, time_range, status, cancelled_at)
values (pg_temp.fx('ali_barber'), pg_temp.fx('khaled'), pg_temp.fx('haircut'), 25, 30,
        tstzrange(now() + interval '2 hours', now() + interval '2 hours 30 minutes', '[)'), 'confirmed', null),
       (pg_temp.fx('ali_barber'), pg_temp.fx('khaled'), pg_temp.fx('haircut'), 25, 30,
        tstzrange(now() + interval '3 hours', now() + interval '3 hours 30 minutes', '[)'), 'cancelled', now());
select results_eq(
  $$ select total, confirmed, cancelled from admin_today_counts() $$,
  $$ select count(*) filter (where status <> 'cancelled'), count(*) filter (where status = 'confirmed'), count(*) filter (where status = 'cancelled')
     from bookings where (lower(time_range) at time zone app_timezone())::date = (now() at time zone app_timezone())::date $$,
  'today counts exclude cancelled bookings from the total and report them separately');

select is((select barbers_subscribed from admin_salons where id = pg_temp.fx('salon')), 1::bigint, 'the salon counts its subscribed barbers');
select is((select barbers_total from admin_salons where id = pg_temp.fx('salon')), 2::bigint, 'rejected barbers are not counted in the salon');

select * from finish();
rollback;
