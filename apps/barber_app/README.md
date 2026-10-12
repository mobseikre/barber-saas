# حلّاقي — Barber app

Flutter app for barbers: bookings of the day, services, working hours, salon location, statistics and the subscription status. Arabic only, RTL. Customers book in `apps/customer_app`; admins manage subscriptions in `apps/admin`.

| Screen | Where |
|---|---|
| Sign up, login, complete registration, pending / expired / suspended | `lib/features/auth`, `lib/features/registration` |
| Today's bookings, manual booking, cancel with reason, close the rest of today | `lib/features/bookings` |
| Services (price and duration) | `lib/features/services` |
| Working hours and breaks | `lib/features/schedule` |
| Salon location (map, address, city, area) | `lib/features/location` |
| Statistics | `lib/features/stats` |
| Account: subscription, renewal contact, links | `lib/features/account` |

Theme, widgets, models, repositories, error messages and the login screen live in [`packages/shared`](../../packages/shared). Every booking action goes through the database RPCs; the app never writes to `bookings`.

## Requirements

- Flutter 3.38 or newer
- Xcode (iOS Simulator) and/or Android Studio with an emulator
- For Android builds, JDK 17 or 21. Gradle 8.14 does not run on Java 25; point Flutter at a supported JDK once with `flutter config --jdk-dir=<jdk home>`, or set `JAVA_HOME` for the build
- Docker and the [Supabase CLI](https://supabase.com/docs/guides/cli) for the local backend

## Run it locally

1. Start the backend once per session, from the repo root:

   ```
   supabase start
   supabase db reset      # migrations + seed data
   ```

2. Install the packages:

   ```
   cd apps/barber_app
   flutter pub get
   ```

3. Run the app. The URL and publishable key come from `env/*.json`:

   ```
   flutter devices                      # list the device ids

   # iOS Simulator (open one with: open -a Simulator)
   flutter run -d <simulator id> --dart-define-from-file=env/local.json

   # Android emulator (reaches the host as 10.0.2.2)
   flutter emulators --launch <emulator id>
   flutter run -d <emulator id> --dart-define-from-file=env/android.json

   # Chrome
   flutter run -d chrome --dart-define-from-file=env/local.json
   ```

   On a physical phone, copy `env/local.json` to a file of your own with your computer's LAN address as `SUPABASE_URL` (for example `http://192.168.1.20:54321`) and pass that file instead.

Seeded accounts (password `password123`):

| Phone | Account |
|---|---|
| `0912345678` | Active barber with services, hours and bookings |
| `0924107733` | Barber waiting for activation |
| `0910000001` | Admin |
| `0911002030`, `0925554410` | Customers (they cannot sign in to this app) |

To activate a new barber while testing, run `select activate_subscription(<barber id>, 1, 50)` as the admin, or in Studio (`http://127.0.0.1:54323`) set the barber's `status` to `active` and `subscription_ends_at` to a future date.

## Location and map

- **Use my current location** asks for the location permission. The iOS Simulator has no location until you pick one under *Features → Location*; on the Android emulator use *Extended controls → Location*. Without it the barber can still move the map under the pin.
- The map uses the public OpenStreetMap tile server. That server is not meant for production traffic, so switch the tile layer (`lib/features/location/location_map.dart`) to a hosted tile provider before launch.

## Tests

```
flutter analyze
flutter test
TZ=UTC flutter test        # nothing may depend on the device time zone
```

Database tests: `supabase test db` from the repo root.

## App icon

The launcher icons are rendered from the barber pole geometry by `packages/shared/tool/generate_app_icons.py`:

```
python3 packages/shared/tool/generate_app_icons.py apps/barber_app
```
