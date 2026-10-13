begin;
select plan(52);
-- Tests use only the reference data; the local dev seed is removed inside this transaction.
delete from public.bookings;
delete from public.subscription_payments;
delete from public.admin_actions;
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

select pg_temp.new_user('admin', '218990000001', 'الإدارة', 'customer');
update profiles set role = 'admin' where id = pg_temp.fx('admin');
select pg_temp.new_user('ali', '218990000002', 'علي', 'barber');
select pg_temp.new_user('khaled', '218990000004', 'خالد المقريف', 'customer');

insert into fx select 'area', id from areas where name = 'حي الأندلس';
insert into salons (name, owner_id, area_id, address)
values ('صالون الأناقة', pg_temp.fx('ali'), pg_temp.fx('area'), 'شارع الجمهورية');
insert into fx select 'salon', id from salons;
insert into barbers (profile_id, salon_id, display_name, status)
values (pg_temp.fx('ali'), pg_temp.fx('salon'), 'علي القماطي', 'pending');
insert into fx select 'ali_barber', id from barbers where profile_id = pg_temp.fx('ali');

-- Plans: seeded prices, readable by signed-in users, edited by admins only

select results_eq($$ select months, price from subscription_plans order by months $$,
  $$ values (1, 50::numeric), (3, 150::numeric), (6, 280::numeric), (12, 500::numeric) $$,
  'the four plans are seeded with their prices');

set local role anon;
select throws_ok('select * from subscription_plans', '42501', null, 'anon cannot read the plans');
select throws_ok('select * from admin_actions', '42501', null, 'anon cannot read the audit log');
reset role;

select pg_temp.login('ali');
select is((select count(*) from subscription_plans), 4::bigint, 'a barber sees the active plans');
select throws_ok('select admin_save_subscription_plan(3, 160)', 'admin_only', 'a barber cannot edit plans');
select throws_ok($$ update subscription_plans set price = 1 where months = 1 $$, '42501', null, 'plans are not writable directly');
select throws_ok($$ insert into admin_actions (actor_id, action) values (pg_temp.fx('ali'), 'x') $$, '42501', null, 'the audit log is not writable by clients');
select throws_ok($$ select log_admin_action('x', null) $$, '42501', null, 'the audit helper is not callable by clients');
select is((select count(*) from admin_actions), 0::bigint, 'the audit log is empty for a barber');
select pg_temp.logout();

select pg_temp.login('admin');
select is((select (admin_save_subscription_plan(3, 160)).price), 160::numeric, 'the admin changes a plan price');
select is((select (admin_save_subscription_plan(3, 160, false)).is_active), false, 'and can deactivate it');
select is((select (admin_save_subscription_plan(2, 90)).months), 2, 'and can add a plan');
select throws_ok('select admin_save_subscription_plan(0, 50)', 'invalid_months', 'plan months start at 1');
select throws_ok('select admin_save_subscription_plan(25, 50)', 'invalid_months', 'and end at 24');
select throws_ok('select admin_save_subscription_plan(1, 10001)', 'invalid_amount', 'plan prices are capped');
select throws_ok('select admin_save_subscription_plan(1, -1)', 'invalid_amount', 'and cannot be negative');
select is((select count(*) from admin_actions where action = 'save_subscription_plan'), 3::bigint, 'each plan edit is audited');
select is((select details->>'price' from admin_actions where action = 'save_subscription_plan' and details->>'months' = '2'), '90.00', 'with the new values');
select pg_temp.logout();

select pg_temp.login('ali');
select is((select count(*) from subscription_plans), 4::bigint, 'a barber no longer sees the deactivated plan');
select pg_temp.logout();

-- Activation follows the plan price unless a reason is given

select pg_temp.login('admin');
select throws_ok(format('select activate_subscription(%L, 3, 160)', pg_temp.fx('ali_barber')), 'plan_not_found', 'an inactive plan cannot be sold');
select throws_ok(format('select activate_subscription(%L, 4, 160)', pg_temp.fx('ali_barber')), 'plan_not_found', 'nor a duration without a plan');
select throws_ok(format('select activate_subscription(%L, 0, 50)', pg_temp.fx('ali_barber')), 'invalid_months', 'months below 1');
select throws_ok(format('select activate_subscription(%L, 25, 50)', pg_temp.fx('ali_barber')), 'invalid_months', 'months above 24');
select is(pg_temp.error_detail(format('select activate_subscription(%L, 25, 50)', pg_temp.fx('ali_barber'))), 'min=1 max=24', 'with the range in DETAIL');
select throws_ok(format('select activate_subscription(%L, 1, 10001)', pg_temp.fx('ali_barber')), 'invalid_amount', 'the amount is capped');
select throws_ok(format('select activate_subscription(%L, 1, -5)', pg_temp.fx('ali_barber')), 'invalid_amount', 'and cannot be negative');
select throws_ok(format('select activate_subscription(%L, 1, 40)', pg_temp.fx('ali_barber')), 'override_reason_required', 'a different amount needs a reason');
select is(pg_temp.error_detail(format('select activate_subscription(%L, 1, 40)', pg_temp.fx('ali_barber'))), 'plan_price=50.00', 'the plan price is in DETAIL');
select throws_ok(format('select activate_subscription(%L, 1, 40, null, %L)', pg_temp.fx('ali_barber'), '   '), 'override_reason_required', 'a blank reason does not count');
select throws_ok(format('select activate_subscription(%L, 1, 40, null, %L)', pg_temp.fx('ali_barber'), repeat('x', 201)), 'override_reason_too_long', 'the reason is limited');
select is((select count(*) from subscription_payments), 0::bigint, 'nothing was recorded by the refused calls');

select is((select (activate_subscription(pg_temp.fx('ali_barber'), 1, 40, 'نقداً', 'خصم أول شهر')).status), 'active'::barber_status,
  'a discounted first month is accepted with a reason');
select results_eq(format($$ select amount, override_reason, plan_months, plan_price from admin_subscription_payments where barber_id = %L $$, pg_temp.fx('ali_barber')),
  $$ values (40::numeric, 'خصم أول شهر', 1, 50::numeric) $$,
  'the payment keeps the plan, its price and the override reason');
select lives_ok(format('select activate_subscription(%L, 1, 50, null, %L)', pg_temp.fx('ali_barber'), 'غير مطلوب'), 'paying the plan price with a reason is fine');
select is((select override_reason from admin_subscription_payments where barber_id = pg_temp.fx('ali_barber') and amount = 50), null,
  'but the reason is dropped when the price matches');
select is((select count(*) from admin_actions where action = 'activate_subscription' and target_id = pg_temp.fx('ali_barber')), 2::bigint, 'activations are audited');
select is((select details->>'override_reason' from admin_actions where action = 'activate_subscription' and details->>'amount' = '40'), 'خصم أول شهر', 'with the reason');

-- Status changes and unblocks are audited

select is((select (suspend_barber(pg_temp.fx('ali_barber'))).status), 'suspended'::barber_status, 'suspend still works through the wrapper');
select is((select details from admin_actions where action = 'set_barber_status' and target_id = pg_temp.fx('ali_barber')),
  '{"to": "suspended", "from": "active"}'::jsonb, 'the status change is audited with both states');

update profiles set no_show_count = 3, blocked_at = now() where id = pg_temp.fx('khaled');
select lives_ok(format('select unblock_customer(%L)', pg_temp.fx('khaled')), 'the admin unblocks a customer');
select is((select details->>'no_show_count' from admin_actions where action = 'unblock_customer' and target_id = pg_temp.fx('khaled')), '3',
  'the unblock is audited with the count it cleared');
select is((select bool_and(actor_id = pg_temp.fx('admin')) from admin_actions), true, 'every entry names the admin who acted');
select pg_temp.logout();

-- Changing the password clears the forced-change flag

update auth.users set raw_app_meta_data = raw_app_meta_data || '{"must_change_password": true}' where id = pg_temp.fx('khaled');
set local role anon;
select throws_ok($$ select change_password('Str0ngPass!') $$, '42501', null, 'anon cannot change a password');
reset role;
select pg_temp.login('khaled');
select throws_ok($$ select change_password('short') $$, 'password_too_short', 'the minimum length is enforced');
select lives_ok($$ select change_password('Str0ngPass!') $$, 'a signed-in user changes their password');
select pg_temp.logout();
select is((select encrypted_password = extensions.crypt('Str0ngPass!', encrypted_password) from auth.users where id = pg_temp.fx('khaled')), true,
  'the new password is stored as a bcrypt hash');
select is((select raw_app_meta_data ? 'must_change_password' from auth.users where id = pg_temp.fx('khaled')), false, 'and the flag is cleared');

-- The reset function signs the target out of every device through an admin-only RPC

insert into auth.sessions (id, user_id, created_at, updated_at) values (gen_random_uuid(), pg_temp.fx('khaled'), now(), now()), (gen_random_uuid(), pg_temp.fx('khaled'), now(), now());
insert into auth.sessions (id, user_id, created_at, updated_at) values (gen_random_uuid(), pg_temp.fx('admin'), now(), now());
select pg_temp.login('ali');
select throws_ok(format('select admin_revoke_sessions(%L)', pg_temp.fx('khaled')), 'admin_only', 'a barber cannot sign others out');
select pg_temp.login('admin');
select throws_ok(format('select admin_revoke_sessions(%L)', pg_temp.fx('admin')), 'role_not_resettable', 'admin sessions cannot be revoked through it');
select throws_ok(format('select admin_revoke_sessions(%L)', gen_random_uuid()), 'profile_not_found', 'unknown profile');
select is(admin_revoke_sessions(pg_temp.fx('khaled')), 2, 'the admin signs a customer out of both devices');
select pg_temp.logout();
select is((select count(*) from auth.sessions), 1::bigint, 'only the admin session is left');

select * from finish();
rollback;
