-- Local development data. Applied by `supabase db reset`, never in production.
-- All accounts use the password `password123`.

do $$
begin
  if current_setting('app.settings.jwt_secret', true) is distinct from 'super-secret-jwt-token-with-at-least-32-characters-long' then
    raise exception 'seed.sql is for the local stack only';
  end if;
end $$;

create or replace function pg_temp.seed_user(p_id uuid, p_phone text, p_name text, p_role text) returns void
language plpgsql as $$
begin
  insert into auth.users (
    id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change,
    email_change_token_current, phone_change, phone_change_token, reauthentication_token
  ) values (
    p_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
    p_phone || '@app.local', extensions.crypt('password123', extensions.gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}',
    jsonb_build_object('full_name', p_name, 'phone', p_phone, 'role', p_role),
    now(), now(), '', '', '', '', '', '', '', ''
  );
  insert into auth.identities (id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at)
  values (gen_random_uuid(), p_id, p_id::text, 'email',
          jsonb_build_object('sub', p_id::text, 'email', p_phone || '@app.local', 'email_verified', true),
          now(), now(), now());
end $$;

select pg_temp.seed_user('10000000-0000-0000-0000-000000000001', '218910000001', 'الإدارة', 'customer');
update public.profiles set role = 'admin' where id = '10000000-0000-0000-0000-000000000001';

select pg_temp.seed_user('10000000-0000-0000-0000-000000000002', '218912345678', 'علي القماطي', 'barber');
select pg_temp.seed_user('10000000-0000-0000-0000-000000000003', '218924107733', 'مراد الزنتاني', 'barber');
select pg_temp.seed_user('10000000-0000-0000-0000-000000000004', '218911002030', 'خالد المقريف', 'customer');
select pg_temp.seed_user('10000000-0000-0000-0000-000000000005', '218925554410', 'سالم بن عامر', 'customer');
select pg_temp.seed_user('10000000-0000-0000-0000-000000000006', '218941207788', 'عبدالله الزوي', 'customer');

insert into public.salons (id, name, owner_id, area_id, address)
select '20000000-0000-0000-0000-000000000001', 'صالون الأناقة', '10000000-0000-0000-0000-000000000002', a.id, 'شارع الجمهورية'
from public.areas a where a.name = 'حي الأندلس';

insert into public.salons (id, name, owner_id, area_id)
select '20000000-0000-0000-0000-000000000002', 'حلاق الملوك', '10000000-0000-0000-0000-000000000003', a.id
from public.areas a where a.name = 'قرقارش';

-- Active, subscribed barber: the one to log in with (phone 0912345678)
insert into public.barbers (id, profile_id, salon_id, display_name, status, subscription_ends_at, is_vip)
values ('30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002',
        '20000000-0000-0000-0000-000000000001', 'علي القماطي', 'active', now() + interval '12 days', true);

-- Pending barber: shows the "بانتظار التفعيل" screen (phone 0924107733)
insert into public.barbers (id, profile_id, salon_id, display_name, status)
values ('30000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000003',
        '20000000-0000-0000-0000-000000000002', 'مراد الزنتاني', 'pending');

insert into public.barber_services (barber_id, service_id, price, duration_min)
select '30000000-0000-0000-0000-000000000001', s.id, v.price, v.duration
from (values ('haircut', 25, 30), ('beard', 15, 20), ('kids', 15, 20), ('facial', 60, 40), ('vip', 100, 75))
  as v (code, price, duration)
join public.service_catalog s on s.code = v.code;

insert into public.working_hours (barber_id, weekday, opens_at, closes_at, is_closed)
select '30000000-0000-0000-0000-000000000001', d, '10:00'::time, (case when d = 4 then '23:00' else '22:00' end)::time, d = 5
from generate_series(0, 6) d;

insert into public.breaks (barber_id, name, starts_at, ends_at)
values ('30000000-0000-0000-0000-000000000001', 'غداء وصلاة', '13:30', '14:30');

insert into public.subscription_payments (barber_id, amount, period_start, period_end, recorded_by, note)
values ('30000000-0000-0000-0000-000000000001', 50, now() - interval '18 days', now() + interval '12 days',
        '10000000-0000-0000-0000-000000000001', 'نقداً');

-- Today's bookings, relative to the time of `db reset`
create or replace function pg_temp.today_at(p_time time) returns timestamptz
language sql stable as $$
  select ((now() at time zone app_timezone())::date + p_time) at time zone app_timezone()
$$;

insert into public.bookings (barber_id, customer_id, customer_name, service_id, price, duration_min, time_range, status, source)
select '30000000-0000-0000-0000-000000000001', v.customer_id::uuid, v.customer_name, s.id, v.price, v.duration,
       tstzrange(v.starts_at, v.starts_at + make_interval(mins => v.duration), '[)'), v.status::public.booking_status, v.source::public.booking_source
from (values
  ('10000000-0000-0000-0000-000000000005', null, 'haircut', 25, 30, pg_temp.today_at('09:00'), 'completed', 'app'),
  ('10000000-0000-0000-0000-000000000006', null, 'beard', 15, 20, pg_temp.today_at('09:30'), 'no_show', 'app'),
  ('10000000-0000-0000-0000-000000000004', null, 'vip', 100, 75, now() + interval '30 minutes', 'confirmed', 'app'),
  ('10000000-0000-0000-0000-000000000005', null, 'haircut', 25, 30, now() + interval '2 hours', 'confirmed', 'app'),
  (null, 'يوسف المصراتي', 'kids', 15, 20, now() + interval '3 hours', 'confirmed', 'manual')
) as v (customer_id, customer_name, code, price, duration, starts_at, status, source)
join public.service_catalog s on s.code = v.code;

-- A few past bookings for the stats screen later
insert into public.bookings (barber_id, customer_id, service_id, price, duration_min, time_range, status)
select '30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000004', s.id, 25, 30,
       tstzrange(pg_temp.today_at('11:00') - (d || ' days')::interval, pg_temp.today_at('11:30') - (d || ' days')::interval, '[)'), 'completed'
from generate_series(1, 5) d
join public.service_catalog s on s.code = 'haircut';
