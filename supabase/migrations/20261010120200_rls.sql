alter table public.cities enable row level security;
alter table public.areas enable row level security;
alter table public.profiles enable row level security;
alter table public.salons enable row level security;
alter table public.barbers enable row level security;
alter table public.service_catalog enable row level security;
alter table public.barber_services enable row level security;
alter table public.working_hours enable row level security;
alter table public.breaks enable row level security;
alter table public.day_closures enable row level security;
alter table public.bookings enable row level security;
alter table public.reviews enable row level security;
alter table public.subscription_payments enable row level security;
alter table public.device_tokens enable row level security;

-- Lookups: readable by everyone, written by admins

create policy cities_read on public.cities for select using (true);
create policy cities_admin on public.cities for all using (is_admin()) with check (is_admin());

create policy areas_read on public.areas for select using (true);
create policy areas_admin on public.areas for all using (is_admin()) with check (is_admin());

create policy service_catalog_read on public.service_catalog for select using (true);
create policy service_catalog_admin on public.service_catalog for all using (is_admin()) with check (is_admin());

-- Profiles

create policy profiles_read_own on public.profiles for select
  using (id = auth.uid());
create policy profiles_read_customers_of_barber on public.profiles for select
  using (exists (select 1 from bookings b where b.customer_id = profiles.id and b.barber_id = current_barber_id()));
create policy profiles_update_own on public.profiles for update
  using (id = auth.uid()) with check (id = auth.uid());
create policy profiles_admin on public.profiles for all
  using (is_admin()) with check (is_admin());

-- Salons

create policy salons_read on public.salons for select using (true);
create policy salons_insert_barber on public.salons for insert
  with check (owner_id = auth.uid() and exists (select 1 from profiles where id = auth.uid() and role = 'barber'));
create policy salons_update_owner on public.salons for update
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy salons_admin on public.salons for all using (is_admin()) with check (is_admin());

-- Barbers

create policy barbers_read_bookable on public.barbers for select
  using (is_barber_bookable(id));
create policy barbers_read_own on public.barbers for select
  using (profile_id = auth.uid());
create policy barbers_insert_own on public.barbers for insert
  with check (
    profile_id = auth.uid()
    and status = 'pending'
    and subscription_ends_at is null
    and not is_vip
    and exists (select 1 from profiles where id = auth.uid() and role = 'barber')
  );
create policy barbers_update_own on public.barbers for update
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());
create policy barbers_admin on public.barbers for all using (is_admin()) with check (is_admin());

-- Barber-owned configuration

create policy barber_services_read on public.barber_services for select
  using (is_barber_bookable(barber_id) or barber_id = current_barber_id());
create policy barber_services_write_own on public.barber_services for all
  using (barber_id = current_barber_id()) with check (barber_id = current_barber_id());
create policy barber_services_admin on public.barber_services for all using (is_admin()) with check (is_admin());

create policy working_hours_read on public.working_hours for select
  using (is_barber_bookable(barber_id) or barber_id = current_barber_id());
create policy working_hours_write_own on public.working_hours for all
  using (barber_id = current_barber_id()) with check (barber_id = current_barber_id());
create policy working_hours_admin on public.working_hours for all using (is_admin()) with check (is_admin());

create policy breaks_read on public.breaks for select
  using (is_barber_bookable(barber_id) or barber_id = current_barber_id());
create policy breaks_write_own on public.breaks for all
  using (barber_id = current_barber_id()) with check (barber_id = current_barber_id());
create policy breaks_admin on public.breaks for all using (is_admin()) with check (is_admin());

create policy day_closures_read on public.day_closures for select
  using (is_barber_bookable(barber_id) or barber_id = current_barber_id());
create policy day_closures_write_own on public.day_closures for all
  using (barber_id = current_barber_id()) with check (barber_id = current_barber_id());
create policy day_closures_admin on public.day_closures for all using (is_admin()) with check (is_admin());

-- Bookings: read by the two parties, written only through functions

create policy bookings_read_customer on public.bookings for select
  using (customer_id = auth.uid());
create policy bookings_read_barber on public.bookings for select
  using (barber_id = current_barber_id());
create policy bookings_admin on public.bookings for all using (is_admin()) with check (is_admin());

-- Reviews

create policy reviews_read on public.reviews for select using (true);
create policy reviews_insert_customer on public.reviews for insert
  with check (
    customer_id = auth.uid()
    and exists (select 1 from bookings b where b.id = booking_id and b.customer_id = auth.uid() and b.status = 'completed')
  );
create policy reviews_admin on public.reviews for all using (is_admin()) with check (is_admin());

-- Subscription payments

create policy subscription_payments_read_own on public.subscription_payments for select
  using (barber_id = current_barber_id());
create policy subscription_payments_admin on public.subscription_payments for all
  using (is_admin()) with check (is_admin());

-- Device tokens

create policy device_tokens_own on public.device_tokens for all
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());
create policy device_tokens_admin on public.device_tokens for select using (is_admin());

-- Views and functions

grant select on public.salon_barbers, public.salon_hours, public.admin_barber_cancellations to authenticated;
revoke all on public.salon_barbers, public.salon_hours, public.admin_barber_cancellations from anon;

revoke execute on function public.activate_subscription(uuid, int, numeric, text) from anon;
revoke execute on function public.unblock_customer(uuid) from anon;
revoke execute on function public.create_booking(uuid, uuid, timestamptz) from anon;
revoke execute on function public.create_manual_booking(uuid, timestamptz, text) from anon;
revoke execute on function public.set_booking_status(uuid, public.booking_status) from anon;
revoke execute on function public.cancel_booking(uuid, public.barber_cancel_reason, text) from anon;
revoke execute on function public.close_rest_of_today() from anon;
