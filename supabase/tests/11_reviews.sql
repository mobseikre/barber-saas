begin;
select plan(12);
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

create function pg_temp.setup() returns void language plpgsql as $$
declare
  v_area uuid := (select id from areas where name = 'حي الأندلس');
  v_salon uuid;
  v_barber uuid;
  v_haircut uuid := (select id from service_catalog where code = 'haircut');
begin
  perform pg_temp.new_user('ali', '218990000002', 'Ali', 'barber');
  perform pg_temp.new_user('khaled', '218990000004', 'Khaled', 'customer');
  perform pg_temp.new_user('salem', '218990000005', 'Salem', 'customer');

  insert into salons (name, owner_id, area_id) values ('صالون الأناقة', pg_temp.fx('ali'), v_area) returning id into v_salon;
  insert into barbers (profile_id, salon_id, display_name, status, subscription_ends_at)
  values (pg_temp.fx('ali'), v_salon, 'علي القماطي', 'active', now() + interval '30 days') returning id into v_barber;
  insert into fx values ('barber', v_barber);

  insert into bookings (id, barber_id, customer_id, service_id, price, duration_min, time_range, status) values
    ('00000000-0000-0000-0000-00000000b001', v_barber, pg_temp.fx('khaled'), v_haircut, 25, 30,
     tstzrange(now() - interval '3 hours', now() - interval '2 hours 30 minutes'), 'completed'),
    ('00000000-0000-0000-0000-00000000b002', v_barber, pg_temp.fx('khaled'), v_haircut, 25, 30,
     tstzrange(now() + interval '1 day', now() + interval '1 day 30 minutes'), 'confirmed'),
    ('00000000-0000-0000-0000-00000000b003', v_barber, pg_temp.fx('khaled'), v_haircut, 25, 30,
     tstzrange(now() - interval '5 hours', now() - interval '4 hours 30 minutes'), 'completed');
end $$;

select pg_temp.setup();

select pg_temp.login('khaled');
select lives_ok($$ insert into reviews (booking_id, customer_id, rating, tags, comment)
  values ('00000000-0000-0000-0000-00000000b001', auth.uid(), 5, array['النظافة', 'جودة القص'], 'ممتاز') $$,
  'a customer reviews their completed booking');
select is((select barber_id from reviews where booking_id = '00000000-0000-0000-0000-00000000b001'), pg_temp.fx('barber'),
  'the barber is filled from the booking');
select is((select rating_count from barbers where id = pg_temp.fx('barber')), 1, 'the barber rating is refreshed');
select throws_ok($$ insert into reviews (booking_id, customer_id, rating)
  values ('00000000-0000-0000-0000-00000000b001', auth.uid(), 4) $$,
  '23505', null, 'a booking is reviewed once');
select throws_ok($$ insert into reviews (booking_id, customer_id, rating)
  values ('00000000-0000-0000-0000-00000000b002', auth.uid(), 4) $$,
  'booking_not_completed', 'a booking that is not completed cannot be reviewed');
select throws_ok($$ insert into reviews (booking_id, customer_id, rating)
  values ('00000000-0000-0000-0000-00000000b003', auth.uid(), 6) $$,
  '23514', null, 'the rating is between 1 and 5');
select throws_ok(format($$ insert into reviews (booking_id, customer_id, rating, comment)
  values ('00000000-0000-0000-0000-00000000b003', auth.uid(), 4, %L) $$, repeat('ا', 301)),
  '23514', null, 'a comment is at most 300 characters');
select throws_ok($$ insert into reviews (booking_id, customer_id, rating, tags)
  values ('00000000-0000-0000-0000-00000000b003', auth.uid(), 4, array['1', '2', '3', '4', '5', '6']) $$,
  '23514', null, 'a review carries at most 5 tags');
select lives_ok(format($$ insert into reviews (booking_id, customer_id, rating, comment)
  values ('00000000-0000-0000-0000-00000000b003', auth.uid(), 4, %L) $$, repeat('ا', 300)),
  'a comment of exactly 300 characters is accepted');

select pg_temp.login('salem');
select throws_ok($$ insert into reviews (booking_id, customer_id, rating)
  values ('00000000-0000-0000-0000-00000000b001', auth.uid(), 1) $$,
  'review_customer_mismatch', 'another customer cannot review it');
delete from reviews where booking_id = '00000000-0000-0000-0000-00000000b001';
select pg_temp.logout();
select is((select count(*) from reviews where booking_id = '00000000-0000-0000-0000-00000000b001')::int, 1,
  'customers cannot delete reviews');

select is(review_comment_max_length(), 300, 'review comments are at most 300 characters');

select * from finish();
rollback;
