-- Step 6 review: subscription plans, admin audit log, forced password change, admin read-model fixes

-- Constants

create function public.subscription_months_max() returns int
language sql immutable as $$ select 24 $$;

create function public.subscription_amount_max() returns numeric
language sql immutable as $$ select 10000 $$;

create function public.password_min_length() returns int
language sql immutable as $$ select 8 $$;

-- Audit log of admin actions. Admins read it; only the admin RPCs and Edge Functions write it.

create table public.admin_actions (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid not null references public.profiles (id),
  action text not null,
  target_id uuid,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index admin_actions_created_idx on public.admin_actions (created_at desc);
create index admin_actions_target_idx on public.admin_actions (target_id);

alter table public.admin_actions enable row level security;
create policy admin_actions_admin_read on public.admin_actions for select using (is_admin());
revoke all on public.admin_actions from public, anon;
revoke insert, update, delete, truncate on public.admin_actions from authenticated;
grant select on public.admin_actions to authenticated;

create function public.log_admin_action(p_action text, p_target_id uuid, p_details jsonb default '{}'::jsonb)
returns void
language sql security definer set search_path = public as $$
  insert into admin_actions (actor_id, action, target_id, details)
  values (auth.uid(), p_action, p_target_id, coalesce(p_details, '{}'::jsonb))
$$;
revoke execute on function public.log_admin_action(text, uuid, jsonb) from public, anon, authenticated;

-- Subscription plans

create table public.subscription_plans (
  id uuid primary key default gen_random_uuid(),
  months int not null unique check (months between 1 and subscription_months_max()),
  price numeric(8, 2) not null check (price between 0 and subscription_amount_max()),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.subscription_plans enable row level security;
create policy subscription_plans_read on public.subscription_plans for select
  to authenticated using (is_active or is_admin());
revoke all on public.subscription_plans from public, anon;
revoke insert, update, delete, truncate on public.subscription_plans from authenticated;
grant select on public.subscription_plans to authenticated;

insert into public.subscription_plans (months, price)
values (1, 50), (3, 150), (6, 280), (12, 500);

create function public.admin_save_subscription_plan(p_months int, p_price numeric, p_is_active boolean default true)
returns public.subscription_plans
language plpgsql security definer set search_path = public as $$
declare
  v_plan subscription_plans%rowtype;
begin
  if not is_admin() then
    raise exception 'admin_only';
  end if;
  if p_months is null or p_months not between 1 and subscription_months_max() then
    raise exception 'invalid_months' using detail = format('min=1 max=%s', subscription_months_max());
  end if;
  if p_price is null or p_price not between 0 and subscription_amount_max() then
    raise exception 'invalid_amount' using detail = format('max=%s', subscription_amount_max());
  end if;
  insert into subscription_plans (months, price, is_active)
  values (p_months, p_price, coalesce(p_is_active, true))
  on conflict (months) do update
    set price = excluded.price, is_active = excluded.is_active, updated_at = now()
  returning * into v_plan;
  perform log_admin_action('save_subscription_plan', v_plan.id,
    jsonb_build_object('months', v_plan.months, 'price', v_plan.price, 'is_active', v_plan.is_active));
  return v_plan;
end $$;
revoke execute on function public.admin_save_subscription_plan(int, numeric, boolean) from public, anon;

-- Payments record the plan they were sold under and why the price differs, if it does

alter table public.subscription_payments
  add column plan_id uuid references public.subscription_plans (id),
  add column override_reason text check (length(override_reason) <= note_max_length());

drop function public.activate_subscription(uuid, int, numeric, text);

create function public.activate_subscription(
  p_barber_id uuid, p_months int, p_amount numeric, p_note text default null, p_override_reason text default null)
returns public.barbers
language plpgsql security definer set search_path = public as $$
declare
  v_barber barbers%rowtype;
  v_plan subscription_plans%rowtype;
  v_start timestamptz;
  v_end timestamptz;
  v_reason text := nullif(btrim(p_override_reason), '');
begin
  if not is_admin() then
    raise exception 'admin_only';
  end if;
  if p_months is null or p_months not between 1 and subscription_months_max() then
    raise exception 'invalid_months' using detail = format('min=1 max=%s', subscription_months_max());
  end if;
  if p_amount is null or p_amount not between 0 and subscription_amount_max() then
    raise exception 'invalid_amount' using detail = format('max=%s', subscription_amount_max());
  end if;
  select * into v_plan from subscription_plans where months = p_months and is_active;
  if v_plan.id is null then
    raise exception 'plan_not_found';
  end if;
  if p_amount <> v_plan.price and v_reason is null then
    raise exception 'override_reason_required' using detail = format('plan_price=%s', v_plan.price);
  end if;
  if length(v_reason) > note_max_length() then
    raise exception 'override_reason_too_long' using detail = format('max=%s', note_max_length());
  end if;
  if p_amount = v_plan.price then
    v_reason := null;
  end if;
  select * into v_barber from barbers where id = p_barber_id for update;
  if v_barber.id is null then
    raise exception 'barber_not_found';
  end if;
  if v_barber.profile_id is null then
    raise exception 'barber_has_no_account';
  end if;

  v_start := greatest(now(), coalesce(v_barber.subscription_ends_at, now()));
  v_end := v_start + make_interval(months => p_months);
  insert into subscription_payments (barber_id, amount, period_start, period_end, recorded_by, note, plan_id, override_reason)
  values (p_barber_id, p_amount, v_start, v_end, auth.uid(), p_note, v_plan.id, v_reason);

  update barbers
  set status = 'active', subscription_ends_at = v_end
  where id = p_barber_id
  returning * into v_barber;

  perform log_admin_action('activate_subscription', p_barber_id,
    jsonb_build_object('months', p_months, 'amount', p_amount, 'plan_price', v_plan.price,
                       'override_reason', v_reason, 'period_end', v_end));
  return v_barber;
end $$;
revoke execute on function public.activate_subscription(uuid, int, numeric, text, text) from public, anon;

-- Audited barber status changes and unblocks

create or replace function public.admin_set_barber_status(p_barber_id uuid, p_from public.barber_status, p_to public.barber_status)
returns public.barbers
language plpgsql security definer set search_path = public as $$
declare
  v_barber barbers%rowtype;
begin
  if not is_admin() then
    raise exception 'admin_only';
  end if;
  select * into v_barber from barbers where id = p_barber_id for update;
  if v_barber.id is null then
    raise exception 'barber_not_found';
  end if;
  if v_barber.status <> p_from then
    raise exception 'invalid_barber_status';
  end if;
  if p_to = 'active' and v_barber.profile_id is null then
    raise exception 'barber_has_no_account';
  end if;
  update barbers set status = p_to where id = p_barber_id returning * into v_barber;
  perform log_admin_action('set_barber_status', p_barber_id, jsonb_build_object('from', p_from, 'to', p_to));
  return v_barber;
end $$;

revoke execute on function public.admin_set_barber_status(uuid, public.barber_status, public.barber_status) from authenticated;

create or replace function public.unblock_customer(p_profile_id uuid)
returns public.profiles
language plpgsql security definer set search_path = public as $$
declare
  v_profile profiles%rowtype;
  v_no_shows int;
begin
  if not is_admin() then
    raise exception 'admin_only';
  end if;
  select no_show_count into v_no_shows from profiles where id = p_profile_id for update;
  update profiles
  set blocked_at = null, blocked_by = null, no_show_count = 0
  where id = p_profile_id
  returning * into v_profile;
  if v_profile.id is null then
    raise exception 'customer_not_found';
  end if;
  perform log_admin_action('unblock_customer', p_profile_id, jsonb_build_object('no_show_count', v_no_shows));
  return v_profile;
end $$;

-- Forced password change after an admin reset. The Edge Function sets
-- app_metadata.must_change_password; this RPC changes the password and clears it in one step.

create function public.change_password(p_new_password text)
returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  if auth.uid() is null then
    raise exception 'not_signed_in';
  end if;
  if p_new_password is null or length(p_new_password) < password_min_length() then
    raise exception 'password_too_short' using detail = format('min=%s', password_min_length());
  end if;
  update auth.users
  set encrypted_password = crypt(p_new_password, gen_salt('bf', 10)),
      raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) - 'must_change_password',
      updated_at = now()
  where id = auth.uid();
  if not found then
    raise exception 'user_not_found';
  end if;
end $$;
revoke execute on function public.change_password(text) from public, anon;

-- Signs a user out of every device after an admin password reset. Admin targets are refused
-- like in the Edge Function; the function records the reset in the audit log itself.

create function public.admin_revoke_sessions(p_profile_id uuid)
returns int
language plpgsql security definer set search_path = public as $$
declare
  v_role public.user_role;
  v_deleted int;
begin
  if not is_admin() then
    raise exception 'admin_only';
  end if;
  select role into v_role from profiles where id = p_profile_id;
  if v_role is null then
    raise exception 'profile_not_found';
  end if;
  if v_role not in ('barber', 'customer') then
    raise exception 'role_not_resettable';
  end if;
  delete from auth.sessions where user_id = p_profile_id;
  get diagnostics v_deleted = row_count;
  return v_deleted;
end $$;
revoke execute on function public.admin_revoke_sessions(uuid) from public, anon;

-- Read models

create or replace view public.admin_barbers with (security_invoker = true) as
  select b.id, b.display_name, b.status, b.is_vip, b.subscription_ends_at, b.created_at,
         b.rating_avg, b.rating_count, b.profile_id,
         p.phone,
         s.id as salon_id, s.name as salon_name, s.address,
         (s.owner_id is not null and s.owner_id = b.profile_id) as is_salon_owner,
         a.id as area_id, a.name as area_name,
         c.id as city_id, c.name as city_name,
         extensions.st_y(s.location::extensions.geometry) as latitude,
         extensions.st_x(s.location::extensions.geometry) as longitude,
         is_barber_bookable(b.id) as is_bookable,
         (select count(*) from bookings k
           where k.barber_id = b.id
             and k.status <> 'cancelled'
             and date_trunc('month', lower(k.time_range) at time zone app_timezone())
               = date_trunc('month', now() at time zone app_timezone())) as bookings_month
  from barbers b
  join salons s on s.id = b.salon_id
  join areas a on a.id = s.area_id
  join cities c on c.id = a.city_id
  left join profiles p on p.id = b.profile_id
  where is_admin();

create or replace view public.admin_subscription_payments with (security_invoker = true) as
  select sp.id, sp.barber_id, b.display_name as barber_name, sp.amount, sp.paid_at,
         sp.period_start, sp.period_end, sp.note, r.full_name as recorded_by_name,
         sp.plan_id, pl.months as plan_months, pl.price as plan_price, sp.override_reason
  from subscription_payments sp
  join barbers b on b.id = sp.barber_id
  left join profiles r on r.id = sp.recorded_by
  left join subscription_plans pl on pl.id = sp.plan_id
  where is_admin();

-- Today's bookings, bucketed by their start time on the Tripoli calendar day

create function public.admin_today_counts()
returns table (total bigint, confirmed bigint, completed bigint, cancelled bigint, no_show bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_admin() then
    raise exception 'admin_only';
  end if;
  return query
  select count(k.id) filter (where k.status <> 'cancelled'),
         count(k.id) filter (where k.status = 'confirmed'),
         count(k.id) filter (where k.status = 'completed'),
         count(k.id) filter (where k.status = 'cancelled'),
         count(k.id) filter (where k.status = 'no_show')
  from bookings k
  where (lower(k.time_range) at time zone app_timezone())::date = (now() at time zone app_timezone())::date;
end $$;
revoke execute on function public.admin_today_counts() from public, anon;
