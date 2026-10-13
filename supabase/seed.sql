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
select pg_temp.seed_user('10000000-0000-0000-0000-000000000007', '218913330001', 'محمد السويحلي', 'barber');
select pg_temp.seed_user('10000000-0000-0000-0000-000000000008', '218913330002', 'أيمن الفيتوري', 'barber');
select pg_temp.seed_user('10000000-0000-0000-0000-000000000009', '218913330003', 'سالم الترهوني', 'barber');
select pg_temp.seed_user('10000000-0000-0000-0000-000000000010', '218913330004', 'حسن الككلي', 'barber');
select pg_temp.seed_user('10000000-0000-0000-0000-000000000011', '218913330005', 'عمر البرعصي', 'barber');

insert into public.salons (id, name, owner_id, area_id, address, location)
select v.id::uuid, v.name, v.owner_id::uuid, a.id, v.address,
       extensions.st_setsrid(extensions.st_makepoint(v.lng, v.lat), 4326)::extensions.geography
from (values
  ('20000000-0000-0000-0000-000000000001', 'صالون الأناقة', '10000000-0000-0000-0000-000000000002', 'حي الأندلس', 'شارع الجمهورية', 32.8752, 13.1146),
  ('20000000-0000-0000-0000-000000000002', 'حلاق الملوك', '10000000-0000-0000-0000-000000000003', 'قرقارش', 'شارع قرقارش الرئيسي', 32.8648, 13.1366),
  ('20000000-0000-0000-0000-000000000003', 'ستايل مان', '10000000-0000-0000-0000-000000000008', 'حي الأندلس', 'طريق قرجي', 32.8697, 13.1022),
  ('20000000-0000-0000-0000-000000000004', 'صالون الوسيم', '10000000-0000-0000-0000-000000000010', 'سوق الجمعة', 'شارع النصر', 32.8996, 13.2357),
  ('20000000-0000-0000-0000-000000000005', 'صالون النخبة', '10000000-0000-0000-0000-000000000011', 'الفويهات', 'شارع دبي', 32.0921, 20.0905)
) as v (id, name, owner_id, area, address, lat, lng)
join public.areas a on a.name = v.area;

-- Active, subscribed barber: the one to log in with (phone 0912345678)
insert into public.barbers (id, profile_id, salon_id, display_name, status, subscription_ends_at, is_vip)
values ('30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002',
        '20000000-0000-0000-0000-000000000001', 'علي القماطي', 'active', now() + interval '12 days', true);

-- Pending barber: shows the "بانتظار التفعيل" screen (phone 0924107733)
insert into public.barbers (id, profile_id, salon_id, display_name, status)
values ('30000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000003',
        '20000000-0000-0000-0000-000000000002', 'مراد الزنتاني', 'pending');

-- More bookable barbers across Tripoli and Benghazi; أيمن is VIP, like علي
insert into public.barbers (id, profile_id, salon_id, display_name, status, subscription_ends_at, is_vip, rating_avg, rating_count)
values
  ('30000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000007',
   '20000000-0000-0000-0000-000000000001', 'محمد السويحلي', 'active', now() + interval '20 days', false, 4.9, 64),
  ('30000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000008',
   '20000000-0000-0000-0000-000000000003', 'أيمن الفيتوري', 'active', now() + interval '25 days', true, 4.6, 140),
  ('30000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000009',
   '20000000-0000-0000-0000-000000000002', 'سالم الترهوني', 'active', now() + interval '9 days', false, 4.7, 98),
  ('30000000-0000-0000-0000-000000000006', '10000000-0000-0000-0000-000000000010',
   '20000000-0000-0000-0000-000000000004', 'حسن الككلي', 'active', now() + interval '15 days', false, 4.4, 57),
  ('30000000-0000-0000-0000-000000000007', '10000000-0000-0000-0000-000000000011',
   '20000000-0000-0000-0000-000000000005', 'عمر البرعصي', 'active', now() + interval '30 days', false, 4.8, 33);

update public.barbers set rating_avg = 4.8, rating_count = 212 where id = '30000000-0000-0000-0000-000000000001';

-- Added by an admin by name only: listed on the salon page as not bookable
insert into public.barbers (id, salon_id, display_name, status)
values ('30000000-0000-0000-0000-000000000008', '20000000-0000-0000-0000-000000000001', 'وليد الشريف', 'active');

insert into public.barber_services (barber_id, service_id, price, duration_min)
select '30000000-0000-0000-0000-000000000001', s.id, v.price, v.duration
from (values ('haircut', 25, 30), ('beard', 15, 20), ('kids', 15, 20), ('facial', 60, 40), ('vip', 100, 75))
  as v (code, price, duration)
join public.service_catalog s on s.code = v.code;

insert into public.barber_services (barber_id, service_id, price, duration_min)
select v.barber_id::uuid, s.id, v.price, v.duration
from (values
  ('30000000-0000-0000-0000-000000000003', 'haircut', 20, 30), ('30000000-0000-0000-0000-000000000003', 'beard', 10, 20),
  ('30000000-0000-0000-0000-000000000004', 'haircut', 30, 30), ('30000000-0000-0000-0000-000000000004', 'beard', 20, 20),
  ('30000000-0000-0000-0000-000000000004', 'vip', 120, 75), ('30000000-0000-0000-0000-000000000004', 'groom', 250, 120),
  ('30000000-0000-0000-0000-000000000005', 'haircut', 20, 30), ('30000000-0000-0000-0000-000000000005', 'kids', 10, 20),
  ('30000000-0000-0000-0000-000000000006', 'haircut', 15, 30), ('30000000-0000-0000-0000-000000000006', 'beard', 10, 20),
  ('30000000-0000-0000-0000-000000000007', 'haircut', 25, 30), ('30000000-0000-0000-0000-000000000007', 'facial', 50, 40)
) as v (barber_id, code, price, duration)
join public.service_catalog s on s.code = v.code;

insert into public.working_hours (barber_id, weekday, opens_at, closes_at, is_closed)
select '30000000-0000-0000-0000-000000000001', d, '10:00'::time, (case when d = 4 then '23:00' else '22:00' end)::time, d = 5
from generate_series(0, 6) d;

-- أيمن opens at 16:00; حسن takes Saturday off
insert into public.working_hours (barber_id, weekday, opens_at, closes_at, is_closed)
select b.id::uuid, d, b.opens::time, b.closes::time, d = b.day_off
from (values
  ('30000000-0000-0000-0000-000000000003', '09:00', '21:00', 5),
  ('30000000-0000-0000-0000-000000000004', '16:00', '23:30', 5),
  ('30000000-0000-0000-0000-000000000005', '10:00', '22:00', 5),
  ('30000000-0000-0000-0000-000000000006', '09:00', '20:00', 6),
  ('30000000-0000-0000-0000-000000000007', '11:00', '23:00', 5)
) as b (id, opens, closes, day_off), generate_series(0, 6) d;

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

-- Blocked after three no-shows (phone 0941207788): booking shows the blocked message
update public.profiles set no_show_count = 3, blocked_at = now() where id = '10000000-0000-0000-0000-000000000006';

-- A few past bookings for the stats screen later
insert into public.bookings (barber_id, customer_id, service_id, price, duration_min, time_range, status)
select '30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000004', s.id, 25, 30,
       tstzrange(pg_temp.today_at('11:00') - (d || ' days')::interval, pg_temp.today_at('11:30') - (d || ' days')::interval, '[)'), 'completed'
from generate_series(1, 5) d
join public.service_catalog s on s.code = 'haircut';
