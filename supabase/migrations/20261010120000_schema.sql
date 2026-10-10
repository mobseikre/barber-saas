create extension if not exists btree_gist;
create extension if not exists postgis;

create type public.user_role as enum ('customer', 'barber', 'admin');
create type public.barber_status as enum ('pending', 'active', 'suspended', 'rejected');
create type public.booking_status as enum ('confirmed', 'completed', 'no_show', 'cancelled');
create type public.booking_source as enum ('app', 'manual');
create type public.barber_cancel_reason as enum ('sick', 'emergency', 'other');
create type public.device_platform as enum ('android', 'ios');

create table public.cities (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create table public.areas (
  id uuid primary key default gen_random_uuid(),
  city_id uuid not null references public.cities (id) on delete cascade,
  name text not null,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  unique (city_id, name)
);

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  role public.user_role not null default 'customer',
  full_name text not null,
  phone text not null unique check (phone ~ '^218[0-9]{9}$'),
  avatar_url text,
  city_id uuid references public.cities (id),
  no_show_count int not null default 0 check (no_show_count >= 0),
  blocked_at timestamptz,
  blocked_by uuid references public.profiles (id),
  created_at timestamptz not null default now()
);

create table public.salons (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  owner_id uuid references public.profiles (id) on delete set null,
  area_id uuid not null references public.areas (id),
  address text,
  location geography(point, 4326),
  photos text[] not null default '{}',
  created_at timestamptz not null default now()
);
create index salons_area_idx on public.salons (area_id);
create index salons_location_idx on public.salons using gist (location);

create table public.barbers (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid unique references public.profiles (id) on delete set null,
  salon_id uuid not null references public.salons (id),
  display_name text not null,
  photo_url text,
  is_vip boolean not null default false,
  status public.barber_status not null default 'pending',
  subscription_ends_at timestamptz,
  rating_avg numeric(3, 2) not null default 0,
  rating_count int not null default 0,
  created_at timestamptz not null default now()
);
create index barbers_salon_idx on public.barbers (salon_id);

create table public.service_catalog (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name_ar text not null,
  description_ar text,
  default_duration_min int not null check (default_duration_min > 0),
  sort_order int not null default 0
);

create table public.barber_services (
  barber_id uuid not null references public.barbers (id) on delete cascade,
  service_id uuid not null references public.service_catalog (id),
  price numeric(8, 2) not null check (price >= 0),
  duration_min int not null check (duration_min > 0),
  is_enabled boolean not null default true,
  primary key (barber_id, service_id)
);

create table public.working_hours (
  barber_id uuid not null references public.barbers (id) on delete cascade,
  weekday smallint not null check (weekday between 0 and 6),
  opens_at time not null,
  closes_at time not null,
  is_closed boolean not null default false,
  primary key (barber_id, weekday),
  check (closes_at > opens_at)
);

create table public.breaks (
  id uuid primary key default gen_random_uuid(),
  barber_id uuid not null references public.barbers (id) on delete cascade,
  weekday smallint check (weekday between 0 and 6),
  name text not null,
  starts_at time not null,
  ends_at time not null,
  check (ends_at > starts_at)
);
create index breaks_barber_idx on public.breaks (barber_id);

create table public.day_closures (
  id uuid primary key default gen_random_uuid(),
  barber_id uuid not null references public.barbers (id) on delete cascade,
  date date not null,
  from_time time,
  reason text,
  created_at timestamptz not null default now(),
  unique (barber_id, date)
);

create table public.bookings (
  id uuid primary key default gen_random_uuid(),
  barber_id uuid not null references public.barbers (id),
  customer_id uuid references public.profiles (id),
  customer_name text,
  service_id uuid not null references public.service_catalog (id),
  price numeric(8, 2) not null check (price >= 0),
  duration_min int not null check (duration_min > 0),
  time_range tstzrange not null check (not isempty(time_range) and lower_inc(time_range) and not upper_inc(time_range)),
  status public.booking_status not null default 'confirmed',
  source public.booking_source not null default 'app',
  cancelled_at timestamptz,
  cancelled_by uuid references public.profiles (id),
  cancel_reason public.barber_cancel_reason,
  cancel_note text,
  created_at timestamptz not null default now(),
  check ((source = 'app' and customer_id is not null) or (source = 'manual' and customer_name is not null)),
  check ((status = 'cancelled') = (cancelled_at is not null)),
  check (cancel_reason is null or status = 'cancelled'),
  exclude using gist (barber_id with =, time_range with &&) where (status <> 'cancelled')
);
create index bookings_customer_idx on public.bookings (customer_id);
create index bookings_barber_start_idx on public.bookings (barber_id, lower(time_range));

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.bookings (id) on delete cascade,
  barber_id uuid not null references public.barbers (id),
  salon_id uuid not null references public.salons (id),
  customer_id uuid not null references public.profiles (id),
  rating smallint not null check (rating between 1 and 5),
  tags text[] not null default '{}',
  comment text,
  created_at timestamptz not null default now()
);
create index reviews_barber_idx on public.reviews (barber_id);
create index reviews_salon_idx on public.reviews (salon_id);

create table public.subscription_payments (
  id uuid primary key default gen_random_uuid(),
  barber_id uuid not null references public.barbers (id),
  amount numeric(8, 2) not null check (amount >= 0),
  paid_at timestamptz not null default now(),
  period_start timestamptz not null,
  period_end timestamptz not null,
  recorded_by uuid not null references public.profiles (id),
  note text,
  check (period_end > period_start)
);
create index subscription_payments_barber_idx on public.subscription_payments (barber_id);

create table public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  token text not null unique,
  platform public.device_platform not null,
  updated_at timestamptz not null default now()
);
create index device_tokens_profile_idx on public.device_tokens (profile_id);
