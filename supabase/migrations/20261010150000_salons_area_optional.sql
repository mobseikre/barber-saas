-- A barber creates their salon at sign-up and sets the location on a later screen.
alter table public.salons alter column area_id drop not null;
