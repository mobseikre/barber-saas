# حلّاقي — Customer app

Flutter app for customers: find a nearby barber, open the salon page, pick a service and a free time, and confirm. Payment is cash at the salon. Arabic only, RTL. Barbers use `apps/barber_app`; admins use `apps/admin`.

| Screen | Where |
|---|---|
| Home: nearby barbers, city and area filters, search, nearest / top rated | `lib/features/home` |
| Salon page and barber choice | `lib/features/salon` |
| Booking: service, day, time, confirm | `lib/features/booking` |
| Login and sign-up (asked for only when confirming a booking) | `lib/features/auth` |
| Account | `lib/features/account` |

Visitors browse without an account through `barber_directory`, `salon_barbers`, `salon_hours` and `get_available_slots`. Confirming a booking opens the login screen and then returns to the same booking. `create_booking` takes an idempotency key per choice, so retrying after a dropped connection never books twice.

Ranking: barbers are grouped by area, with the nearest area first. Inside an area, VIP barbers come first, then the nearest. Without location permission the areas follow their admin order.

## Run it locally

Same requirements as the barber app (see `apps/barber_app/README.md`).

```
supabase start
supabase db reset                    # migrations + seed data
cd apps/customer_app
flutter pub get

open -a Simulator
xcrun simctl location booted set 32.8720,13.1100     # somewhere in Tripoli, near the seeded salons
flutter run -d <simulator id> --dart-define-from-file=env/local.json

flutter run -d <emulator id> --dart-define-from-file=env/android.json   # Android emulator
```

Seeded accounts (password `password123`):

| Phone | Account |
|---|---|
| `0925554410` | Customer with one upcoming booking (one more reaches the limit of 2) |
| `0911002030` | Customer with one upcoming booking |
| `0941207788` | Customer blocked after 3 no-shows |
| `0912345678` | Barber (refused by this app) |

Seeded barbers: علي القماطي (VIP) and محمد السويحلي at صالون الأناقة (حي الأندلس), plus وليد الشريف there without an account (shown as not bookable); أيمن الفيتوري (VIP, opens at 16:00) at ستايل مان (حي الأندلس); سالم الترهوني at حلاق الملوك (قرقارش); حسن الككلي at صالون الوسيم (سوق الجمعة); عمر البرعصي at صالون النخبة (بنغازي).

## Tests

```
flutter analyze
flutter test
TZ=UTC flutter test
```

End-to-end flows on a device against the local stack (run `supabase db reset` first; the flows book real slots):

```
flutter test integration_test -d <emulator id> --dart-define-from-file=env/android.json
```

Add `--dart-define=WATCH=true` to pause after every step and follow along on the device.

## App icon

```
python3 packages/shared/tool/generate_app_icons.py apps/customer_app
```
