-- A customer's bookings keep their barber and salon details whatever the barber's status

create view public.my_booking_barbers with (security_invoker = false) as
  select b.id as barber_id, b.display_name, s.name as salon_name, s.address,
         extensions.st_y(s.location::extensions.geometry) as latitude,
         extensions.st_x(s.location::extensions.geometry) as longitude
  from barbers b
  join salons s on s.id = b.salon_id
  where exists (select 1 from bookings k where k.barber_id = b.id and k.customer_id = auth.uid());

revoke all on public.my_booking_barbers from public, anon;
revoke insert, update, delete, truncate on public.my_booking_barbers from authenticated;
grant select on public.my_booking_barbers to authenticated;
