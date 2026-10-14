# حلّاقي (Hallaqi) — Barber Booking SaaS for Libya

Customers find a nearby barber, pick a service and a time slot, and pay cash at the salon. Barbers manage their services, hours, location and daily bookings. An admin panel activates barber subscriptions and manages salons.

The approved UI is `design/design.html` (a Claude Design bundle). Rendered screenshots of every board are in `design/screens/`. **All UI work must follow the design system and screen list below.** If the code and the design disagree, the design wins unless this file says otherwise.

## Stack

| Part | Tech |
|---|---|
| `apps/barber_app` | Flutter, Riverpod, `supabase_flutter` |
| `apps/customer_app` | Flutter, Riverpod, `supabase_flutter` |
| `apps/admin` | Next.js admin dashboard |
| Backend | Supabase: Postgres, Auth, Row Level Security, Edge Functions |

## Monorepo structure

```
barber-saas/
├── apps/
│   ├── barber_app/        Flutter app for barbers
│   ├── customer_app/      Flutter app for customers
│   └── admin/             Next.js admin dashboard
├── packages/
│   ├── shared/            Dart package used by both Flutter apps
│   └── test_support/      Widget-test helpers and fakes used by both apps' tests
├── supabase/
│   ├── migrations/        SQL migrations (schema, RLS, functions)
│   └── functions/         Edge Functions (Deno / TypeScript)
├── design/
│   ├── design.html        Approved design (source of truth)
│   └── screens/           PNG renders: barber/, customer/, admin/
├── CLAUDE.md
└── ROADMAP.md
```

### `packages/shared` rule

Anything both Flutter apps need lives in `packages/shared`. **Never duplicate it inside an app.** That includes:

- **Theme**: `ThemeData`, color tokens, text styles, spacing, radii, shadows, and the Cairo font setup
- **Shared widgets** from the design system: buttons, inputs, phone field, status badges, VIP badges, cards, switches
- **Models**: profiles, salons, barbers, services, working hours, bookings, ratings, subscriptions
- **Supabase**: client initialisation, the phone-to-email auth helper, and repositories or queries used by both apps
- **Providers**: the core Riverpod providers (Supabase client, auth, barber and booking repositories, current user and profile, location, cities, areas)
- **Navigation**: `TabShell` with `AppBottomNav(variant:)`, dark for the barber app and light for the customer app
- **Utilities**: Arabic date and number formatting, LYD price formatting

The apps depend on it through a path dependency (`shared: { path: ../../packages/shared }`). App-specific screens and providers stay in their own app.

Test helpers both apps need (`pumpPhone`, `wrapApp`, `fieldLabelled`, `FakeAuthRepo`, `FakeLocationService`, `FakeLauncher`, the Cairo font loader) live in `packages/test_support`, a dev dependency. App-specific fakes stay in each app's `test/support`.

The Next.js admin cannot use the Dart package. It keeps its own TypeScript types and theme tokens, which must mirror the same design tokens and database schema.

## Business rules

- **Market**: Libya. Phone country code is `+218`. Currency is Libyan dinar, written `د.ل` (e.g. `25 د.ل`).
- **Language**: Arabic only, RTL everywhere. Back arrows point right.
- **Payments**: cash only, paid at the salon. No online payment, no payment gateway.
- **Barber subscriptions**: barbers pay a monthly subscription in cash. An admin activates or extends it manually in the admin panel. Each barber has their own subscription, even inside a salon.
- **Visibility**: barbers without an active subscription are hidden from search and cannot be booked. On a salon page they may still be listed as "غير متاح للحجز" (not bookable), as the design shows.
- **New barbers**: after sign-up a barber stays in "بانتظار التفعيل" (pending activation) until an admin activates them.
- **Salons**: a salon has several barbers. At sign-up a barber picks an existing salon or a new one is created in their name. Admins can add unsubscribed barbers to a salon by name only (no account).
- **Auth**: phone + password, no SMS or OTP. The phone is normalised and turned into an internal email for Supabase Auth: `0912345678` → `218912345678@app.local`. Users never see this email.
- **Forgot password**: there is no self-service reset. "نسيت كلمة المرور؟" opens WhatsApp to the support number, and an admin resets the password from the dashboard. The support number is a placeholder for now and must be a single shared constant, not hardcoded per screen.
- **Cancellation**: customers can cancel a booking up to **2 hours** before its start time. Enforce this on the server (RLS or a database function), not only in the UI.
- **Ranking**: within the same area, VIP barbers appear first. VIP is a barber attribute only; salons have no VIP flag.
- **Upcoming bookings**: a customer can hold at most `2` upcoming confirmed bookings. Enforced in `create_booking`, with the limit in `upcoming_booking_limit()`.
- **Cities and areas** are lookup tables (`cities`, `areas`) editable by admins. Salons reference an `area_id`.
- **Salon hours** shown on the salon page are derived from its bookable barbers (earliest open to latest close) via the `salon_hours` view.
- **Booking statuses**: confirmed (مؤكد), completed (مكتمل), no-show (لم يحضر), cancelled (ملغي). Barbers mark attendance as حضر or لم يحضر and can add manual bookings.
- **Instant confirmation**: a booking is confirmed the moment it is created. There is no barber approval step.
- **Barber cancellations** need a reason: sick (مريض), emergency (طارئ) or other (أخرى) with an optional note. The reason is stored on the booking. Customer cancellations have no reason.
- **Blocking time**: a barber can block time quickly, e.g. "close the rest of today". This is a day closure, either a whole day or from a given time. Existing bookings inside the blocked window are not cancelled automatically; the barber cancels them with a reason.
- **No-shows**: barbers mark a booking as no-show. No-shows are counted per customer. After `3` no-shows the customer is blocked from creating bookings until an admin unblocks them. The limit lives in one SQL constant function and one shared Dart constant, never inline. Reverting a no-show lowers the count but never lifts the block: only `unblock_customer` (admin) does, and it resets the count to 0.
- **Pending barbers** (status `pending`) can set up their services, working hours, breaks and profile, but `create_manual_booking`, `close_rest_of_today`, `reopen_today` and `barber_stats` require status `active` and raise `barber_not_active` otherwise.
- **Lapsed or suspended barbers** (status `active` with an ended subscription, or `suspended`) enter the barber app with a red banner and the WhatsApp support button. They see, mark and cancel their existing bookings, but cannot add manual bookings: `create_manual_booking` also requires `is_barber_bookable` and raises `barber_not_bookable`. Only `pending` and `rejected` barbers get the activation screen.
- **Browsing without an account**: anyone can read `barber_directory`, `salon_barbers` and `salon_hours` and call `get_available_slots` so a customer can look around before signing up. `anon` also reads the lookup tables and, through RLS, the public columns of bookable barbers (`barbers` without `profile_id` and `subscription_ends_at`, `salons` without `owner_id`, `day_closures` without `reason`, plus `barber_services`, `working_hours` and `breaks`). Clients that may run without a session must select those columns explicitly, never `*`. `anon` cannot read `reviews` or list the `avatars` bucket. Booking needs a session: every other RPC and table requires `authenticated`.
- **Reviews** are readable only by the customer who wrote them, the reviewed barber and admins. Tags must come from `review_tags()` (mirrored by `AppConstants.reviewTags`), at most `review_max_tags()` = 5 of them. `created_at` on `reviews` and `profiles` is set by the database; clients hold no insert or update privilege on it. Only `completed` bookings can be reviewed.
- **Passwords**: at least `8` characters (`AppConstants.passwordMinLength`, `minimum_password_length` in `config.toml`). Production Auth settings must use the same minimum.
- **Free-text limits**: manual customer names are at most `60` characters and cancel notes / closure reasons at most `200` (`customer_name_max_length()`, `note_max_length()`, mirrored in `AppConstants`). The RPCs raise `customer_name_too_long` / `cancel_note_too_long`; the columns carry check constraints as well.
- **Admin visibility**: the admin can see each barber's cancellation count and reasons.
- **Estimated income** in barber stats is computed only from completed bookings' prices.

## Database

Migrations live in `supabase/migrations/`, pgTAP tests in `supabase/tests/` (`supabase test db`). Run `supabase db reset` after changing a migration. Once a migration has been applied to any remote database, never edit it: add a new migration instead.

- **Tables**: `cities`, `areas`, `profiles`, `salons`, `barbers`, `service_catalog`, `barber_services`, `working_hours`, `breaks`, `day_closures`, `bookings`, `reviews`, `subscription_plans`, `subscription_payments`, `device_tokens`, `notification_outbox`, `admin_actions`.
- **`barbers` is separate from `profiles`**: `profile_id` is nullable so admins can list barbers without an account. Bookable = `is_barber_bookable(id)`: status `active`, has an account, `subscription_ends_at` in the future.
- **Bookings are never written directly from the apps.** RLS allows only reads. Use the RPCs: `create_booking` (with an idempotency key per booking attempt; a retry with the same key returns the booking it already made), `create_manual_booking`, `set_booking_status`, `cancel_booking`, `close_rest_of_today`, `reopen_today`. Admin-only: `activate_subscription`, `unblock_customer`.
- **Subscription plans** live in `subscription_plans` (`months` unique, `price`, `is_active`; seeded 1, 3, 6 and 12 months). `authenticated` reads active plans; admins edit them only through `admin_save_subscription_plan(months, price, is_active)`. `activate_subscription(barber_id, months, amount, note, override_reason)` sells the active plan with that many months (`plan_not_found` otherwise), requires `1 ≤ months ≤ subscription_months_max()` (`invalid_months`) and `0 ≤ amount ≤ subscription_amount_max()` (`invalid_amount`), and when the amount differs from the plan price it needs a non-blank `override_reason` (`override_reason_required`, with `plan_price` in `DETAIL`). The payment stores `plan_id` and `override_reason`.
- **Admin audit log**: `admin_actions` (`actor_id`, `action`, `target_id`, `details`, `created_at`) is written by `log_admin_action()` inside `admin_set_barber_status`, `activate_subscription`, `unblock_customer` and `admin_save_subscription_plan`, and by the `admin-reset-password` function (`reset_password`). Admins read it; clients cannot write it.
- **Forced password change**: after an admin reset the user carries `app_metadata.must_change_password = true` and every session is revoked. `change_password(new_password)` (`authenticated`, at least `password_min_length()` = 8 characters, `password_too_short`) stores the new bcrypt hash and clears the flag in one step; the app then refreshes the session. Both Flutter apps put `PasswordChangeGate` (`packages/shared`) in `MaterialApp.builder`: while `mustChangePasswordProvider` is true the app's navigator stays mounted but hidden under `ChangePasswordRequiredScreen`, which calls `AuthRepository.completePasswordChange` and then lets the user continue where they were. `admin_revoke_sessions(profile_id)` (admin-only, refuses admin targets) is what the reset function uses to sign the target out everywhere.
- **Barber sign-up** calls `register_barber(display_name, salon_id | salon_name + area + address + location)`, which creates or joins the salon and the barber row in one transaction and is safe to retry. A new salon takes the name typed in the salon search (at most `salon_name_max_length()` = 60, `salon_name_too_long`), or `صالون <barber name>` when nothing was typed. The salon owner (the barber who created it) or an admin edits the salon, name included, from the location screen; barbers who joined it cannot. `salons.name` carries a check constraint (not blank, at most 60). Only active barbers may insert salons directly.
- **Errors from RPCs are fixed codes** (`customer_blocked`, `booking_limit_reached`, `cancellation_window_passed`, `slot_not_available`, `booking_not_started`, `day_closed`, …) with any number in `DETAIL` as `key=value`. The apps map codes to Arabic messages; never parse the message text.
- **Attended / no-show** can only be set once the booking has started. Manual bookings must fall inside working hours, outside breaks and outside day closures.
- **Storage**: bucket `avatars` is public, so files are served by URL, but only `authenticated` may list it; each user writes only under `<user_id>/`. `photo_url` / `avatar_url` store `avatars/<user_id>/avatar.<ext>?v=<time>`, not a full URL, so every client builds the URL from its own Supabase address with `publicStorageUrl`. Both columns have a check constraint requiring the `avatars/` prefix.
- **Extensions** (`postgis`, `btree_gist`) are installed in the `extensions` schema, never in `public`, so `spatial_ref_sys` is not exposed through the API. Functions that call PostGIS set `search_path = public, extensions`. `pg_net` and `pg_cron` keep their own `net` and `cron` schemas.
- **Availability**: `get_available_slots(barber_id, date, duration_min)` returns 15-minute slots in `Africa/Tripoli`, minus working hours, breaks, closures, existing bookings and the past. `create_booking` only accepts a start time that this function returns.
- **Overlaps** are impossible at the database level: `EXCLUDE USING gist (barber_id WITH =, time_range WITH &&) WHERE (status <> 'cancelled')`.
- **Constants** are SQL functions: `no_show_limit()` = 3, `upcoming_booking_limit()` = 2, `cancellation_window()` = 2 hours, `customer_name_max_length()` = 60, `full_name_max_length()` = 60, `salon_name_max_length()` = 60, `note_max_length()` = 200, `review_comment_max_length()` = 300, `review_max_tags()` = 5, `review_tags()`, `app_timezone()`, `reminder_lead_time()` = 1 hour, `password_min_length()` = 8. Mirror them in `packages/shared`, never inline. Server-only constants need no mirror: `device_token_limit()` = 5, `notification_max_attempts()` = 5, `notification_retry_delay(attempts)`, `subscription_months_max()` = 24, `subscription_amount_max()` = 10000, `cron_history_retention()` = 7 days (the `cron-history-cleanup` job deletes older `cron.job_run_details` rows daily at 03:17).
- **Views**: `salon_barbers` (public listing of `active` and `suspended` barbers with `is_bookable`, so a lapsed barber shows as not bookable while a pending one is not listed), `salon_hours`, `admin_barber_cancellations` (admins only, empty for everyone else), `my_booking_barbers` (the barber and salon of each of the signed-in customer's bookings, whatever the barber's status, so past bookings keep their names and directions; `authenticated` only), `barber_directory` (barber + salon columns and the barber's phone, for the customer app; lists `active` and `suspended` barbers only, so a lapsed subscription keeps a barber visible while pending and rejected barbers never appear; readable by `anon`). Views are read-only for clients.
- **Security: the service role key never ships to a client.** It must not appear in the Flutter apps or in browser code of the admin panel. Only Edge Functions and server-side code may use it. The apps use the anon/publishable key with RLS; privileged admin actions (password reset, anything bypassing RLS) go through an Edge Function that checks `is_admin()` first.
- **Production keys live only in environment variables or Supabase secrets**, never in any committed file. That covers the production URL and publishable key, the service role key, the JWT secret, database passwords and any third-party token. This repository is public. Committed files may hold only the local Supabase defaults (`env/*.json`, `seed.sql`).
- **Auth metadata**: sign-up must pass `full_name`, `phone` (as `218XXXXXXXXX`) and `role` (`customer` or `barber`) in the user metadata; a trigger creates the profile. `admin` can't be set from metadata. The trigger rejects any email that is not `218XXXXXXXXX@app.local` with `invalid_auth_email` and a `full_name` over `full_name_max_length()` with `full_name_too_long`; the profile phone always comes from the email. A second trigger on `auth.users` rejects any change of the email with `email_change_not_allowed`.
- **`seed.sql` is local only**: its first statement raises unless the database's JWT secret is the local default, so it can never run against a real project.
- **Push notifications**: the `bookings_notify` trigger and `send_booking_reminders()` (pg_cron job `booking-reminders`, every minute) insert rows into `notification_outbox`; they never call the network. A new app booking notifies the barber; a cancellation notifies the other side (both sides when an admin cancels), with the reason and note when the barber cancels; the reminder goes to the customer `reminder_lead_time()` before the start, only for bookings made earlier than that. The `barbers_notify_activation` trigger tells a barber when an admin activates or reactivates them, or renews a lapsed subscription (`barber_activated`, with `bookable` and `renewed`); the barber app reloads the barber on that notice and whenever it resumes on the activation screen. Nothing is queued for a recipient without a `device_tokens` row.
- **Outbox**: `deliver_notifications()` (pg_cron job `notification-outbox`, every 10 seconds) posts pending rows through pg_net to the `send-notification` Edge Function with the Vault secrets `notification_function_url` and `notification_webhook_secret` (`seed.sql` sets the local ones), then reads each answer from `net._http_response` on a later run. Only a 2xx marks the row `sent` and sets `sent_at`, and for a reminder `bookings.reminder_sent_at`. Any other answer, a timeout or no answer within 5 minutes puts the row back after `notification_retry_delay` (1, 2, 4, 8 minutes); after `notification_max_attempts()` = 5 it is `failed` for good. A reminder has one outbox row per booking (`reminder_for` is unique), so it is never sent twice. Rows about a booking that has started, and reminders for a booking no longer confirmed, become `expired` instead of going out late. While the Vault secrets are missing, rows wait as `pending`. Clients have no access to the outbox.
- **Device tokens**: clients write tokens only through `register_device_token(token, platform)`, which moves a token to whoever signed in on the device last and keeps at most `device_token_limit()` = 5 per user, deleting the least recently registered. Clients delete their own row on sign-out.
- **No TRUNCATE for clients**: TRUNCATE ignores RLS, so `anon` and `authenticated` hold it on no table in `public`, including tables created later (default privileges).
- **`send-notification`** runs with `verify_jwt = false` and accepts only `Authorization: Bearer <NOTIFICATION_WEBHOOK_SECRET>`. It writes the Arabic text (Tripoli time, Latin digits), sends with the FCM HTTP v1 API using the service account in `FCM_SERVICE_ACCOUNT`, and deletes tokens FCM reports as `UNREGISTERED`, `SENDER_ID_MISMATCH` or `INVALID_ARGUMENT`. A missing or malformed service account answers 503, and a request where no device received the message answers 502, so the outbox retries both. Its secrets are set with `supabase secrets set`, never committed; locally they come from the git-ignored `supabase/functions/.env` (copy `.env.example`). Tests: `deno test --allow-net` in `supabase/functions/send-notification` (a fake FCM server checks the signed JWT and the message).
- **Production notification secrets**: `NOTIFICATION_WEBHOOK_SECRET` (and the matching Vault `notification_webhook_secret`) must be at least 32 random bytes, e.g. `openssl rand -base64 32`, never a word or the local default. The function URL lives only in Vault: it never appears in the Flutter apps, the admin panel's browser code or any committed file.
- **After every deploy, verify the Vault URL**: `notification_function_url` must be `https://<project ref>.supabase.co/functions/v1/send-notification` of the project just deployed. Check it with `select decrypted_secret from vault.decrypted_secrets where name = 'notification_function_url'`, then make a test booking and confirm its outbox row reaches `sent`. A wrong URL fails silently: rows retry and end as `failed`.

## Running locally

```
supabase start                      # once per session; Studio at http://127.0.0.1:54323
supabase db reset                   # applies migrations + supabase/seed.sql
supabase test db                    # pgTAP suite
cp supabase/functions/.env.example supabase/functions/.env   # once, then restart the stack
cd apps/barber_app
flutter run -d <device> --dart-define-from-file=env/local.json     # iOS simulator / Chrome
flutter run -d <device> --dart-define-from-file=env/android.json   # Android emulator (10.0.2.2)
```

`env/*.json` holds only the local URL and the publishable key. Seeded accounts (password `password123`): active barber `0912345678`, pending barber `0924107733`, admin `0910000001`, customers `0911002030` / `0925554410`, blocked customer `0941207788`. More active barbers (`0913330001`–`0913330005`) have salons with locations in Tripoli and Benghazi.

### Admin dashboard

Node 22 (`.nvmrc` at the repo root, `engines` in `package.json`). With Homebrew: `brew install node@22` and put `/opt/homebrew/opt/node@22/bin` first on `PATH`, or `nvm use`.

```
cd apps/admin
cp .env.example .env.local                      # once; local URL and publishable key only
npm install
supabase functions serve                        # in another terminal, serves admin-reset-password
npm run dev                                     # http://localhost:3000, sign in with 0910000001 / password123
npm run lint                                    # ESLint with eslint-config-next
npm run typecheck
npm test                                        # Vitest + Testing Library (components and helpers)
npm run test:e2e                                # Playwright in Google Chrome, needs the local stack and `functions serve`
```

The panel talks to Supabase from the browser with the publishable key and RLS; only admins get past the gate. It never holds the service role key: password reset goes through the `admin-reset-password` Edge Function, which checks `is_admin()` with the caller's JWT, refuses admin targets, and only then sets a random 12-character password and `app_metadata.must_change_password` with the service role key from the function's own environment, signs the target out everywhere through `admin_revoke_sessions` and records the reset in `admin_actions`. Allowed browser origins come from `ADMIN_ALLOWED_ORIGINS`. **On deploy, set `ADMIN_ALLOWED_ORIGINS` to the panel's production origin** (`supabase secrets set ADMIN_ALLOWED_ORIGINS=https://admin.example`); otherwise the browser blocks the call and the panel shows its "تعذّر الوصول إلى خدمة إعادة التعيين" message. The panel calls the function with `functions.invoke`. Deno tests: `deno test --allow-net` in `supabase/functions/admin-reset-password`. Admin RPCs: `approve_barber`, `reject_barber`, `suspend_barber`, `reactivate_barber` (wrappers around `admin_set_barber_status`, which clients cannot call directly), `admin_set_salon_location`, `admin_save_subscription_plan`, `admin_revoke_sessions`, `admin_today_counts` (today's bookings by start time on the Tripoli day: total without cancelled, confirmed, completed, cancelled, no-show), `admin_bookings_per_day`, `admin_revenue_per_month`; read models: `admin_barbers` (with `bookings_month` per barber), `admin_salons`, `admin_subscription_payments` (with plan and override reason), `admin_barber_cancellations`, `admin_actions` (all empty for non-admins). Beyond the seven designed sidebar items it adds التقارير, الباقات (edits `subscription_plans`), المدن والمناطق and سجل الإجراءات (reads `admin_actions`). The activate and renew dialogs prefill the amount from the chosen plan and lock it; "تعديل المبلغ" unlocks it and requires a reason sent as `p_override_reason`. `next.config.mjs` sends security headers (no framing, `nosniff`, no referrer, HSTS).

### Firebase files

`google-services.json` (in `apps/<app>/android/app/`) and `GoogleService-Info.plist` (in `apps/<app>/ios/Runner/`) come from the Firebase console and are git-ignored. **Never commit them.** Without them both apps build and run with push off: Gradle applies the Google Services plugin only when the JSON exists, and an Xcode build phase copies the plist only when it is there. Push code lives in `packages/shared` (`initPush`, `PushTokens`). Always sign out through `signOut(ref)`, which deletes the device token while the session is still valid and gives up on the network after `PushTokens.unregisterTimeout` (5 seconds). The account tabs and the activation screen ask first through `confirmSignOut`.

### Barber links

`https://<AppConstants.appLinkHost>/b/<barber id>` (`barberLink`, `barberIdFromLink`) opens the customer app on the barber's salon page; the barber app shows it as a QR code. The host is the placeholder `hallaqi.example.com` in three places that change together: `AppConstants.appLinkHost`, the customer app's Android intent filter and its iOS associated domains entitlement. The real domain must serve `/.well-known/assetlinks.json` and `/.well-known/apple-app-site-association`. `initSupabase` passes `detectSessionInUri: false`, so no link, even one carrying `access_token` or `code`, can change the session. On mobile the link stream replays the launch link, so `launchThenIncomingLinks` drops that first repeat and a cold start opens the salon page once.

`packages/shared` is a path dependency; run `flutter pub get` in each app after changing its `pubspec.yaml`. Dates and prices are formatted by `ArabicFormat` (Arabic words, Latin digits). Constants shared with SQL live in `AppConstants`.

## Design system

Extracted from the "نظام التصميم — الأساسيات" and "نظام التصميم — المكوّنات" boards. Use these tokens and do not introduce new colors, sizes or radii.

### Colors

**Blue, primary (from the barber pole)**

| Token | Hex | Use |
|---|---|---|
| `blue-950` | `#0A1540` | Dark background |
| `blue-900` | `#13225A` | Primary, headers, primary button, main text |
| `blue-800` | `#1B3180` | Dark surface, avatar tiles |
| `pole-blue` | `#2448B8` | Pole stripe |
| `blue-pressed` | `#2A45A3` | Primary button pressed, chip borders on dark |
| `blue-300` | `#93A2D3` | Disabled |
| `blue-100` | `#E7ECFA` | Light background, disabled button bg |

**Red, accent (from the barber pole)**

| Token | Hex | Use |
|---|---|---|
| `red-700` | `#B3141C` | Red text, prices, text links |
| `red-600` | `#C81E26` | Red button pressed |
| `pole-red` | `#D62828` | Accent, "احجز الآن" button, filter button |
| `red-400` | `#FF5C62` | Accent on dark surfaces, active nav, focus border, stars |
| `red-100` | `#FBE0E1` | VIP background, customer nav active pill |
| `red-50` | `#FEF1F1` | Highlight, input focus ring |

**Neutrals**

| Token | Hex | Use |
|---|---|---|
| `text` | `#13225A` | Primary text |
| `text-2` | `#4B5565` | Secondary text |
| `text-3` | `#5E6878` | Helper text, captions, placeholders |
| `border` | `#DCE1EC` | Borders, dividers |
| `divider-soft` | `#E8ECF4` | Row separators |
| `bg` | `#F4F6FB` | App background |
| `surface` | `#FFFFFF` | Cards, inputs |
| `switch-off` | `#D4D8DF` | Switch track off |
| on-dark muted | `#CBD3EC` / `#A8B5DF` | Subtitles and inactive nav on blue |

**Booking status** (each status has its own icon too, never color alone)

| Status | Text | Background | Icon |
|---|---|---|---|
| Confirmed (مؤكد) `info` | `#1E4FB8` | `#E5EDFC` | clock |
| Completed (مكتمل) `success` | `#16794A` | `#E3F4EA` | check |
| No-show (لم يحضر) `warning` | `#A4520B` | `#FCEEDC` | exclamation circle |
| Cancelled (ملغي) `danger` | `#B42318` | `#FDE8E7` | X |

`danger` `#B42318` is also the input error color.

### Typography

Font: **Cairo** (weights 400, 500, 600, 700, 800). Use it for every text, numbers included.

| Style | Size / line height | Weight | Example |
|---|---|---|---|
| Display | 32 / 44 | 800 | احجز موعدك |
| H1 | 24 / 36 | 700 | حجوزات اليوم |
| H2 | 20 / 30 | 700 | الخدمات المتاحة |
| H3 | 17 / 26 | 600 | صالون الأناقة |
| Body | 15 / 24 | 400 | قص شعر كلاسيكي مع تصفيف |
| Body Strong | 15 / 24 | 600 | ٢٥ د.ل · ٣٠ دقيقة |
| Caption | 13 / 20 | 500 | حي الأندلس، طرابلس |
| Label | 12 / 18 | 700 | الخطوة ٢ من ٤ |

Buttons use 16/700 (large) or 15/700 (44px buttons). Card titles use 16/700. Input labels use 14/600.

### Spacing

4px grid with the scale `4, 8, 12, 16, 20, 24, 32`. Screen side padding is **20px** and the gap between cards is **12px**. Mobile frame is 390 × 844.

### Radius and shadow

| Radius | Use |
|---|---|
| 8 | Badges (status) |
| 10 | Small in-card buttons (40px tall) |
| 12 | Buttons, inputs, icon buttons, image tiles |
| 16 | Cards |
| 20 | Bottom nav, large panels and sections |
| 999 | Chips, VIP pill, switches, avatars |

Card shadow: `0 6px 20px rgba(19,34,90,0.08)` (design-system tile uses `0.10`).

### Buttons

| Variant | Spec |
|---|---|
| Primary | h52, r12, bg `#13225A`, text white 16/700. Pressed bg `#2A45A3` |
| Disabled | h52, r12, bg `#E7ECFA`, text `#5E6878` |
| Accent (red) | h52, r12, bg `#D62828`, text white. For the standout action, e.g. "احجز الآن" or "إضافة حجز يدوي" |
| Secondary | h52, r12, white bg, border 1.5px `#13225A`, text `#13225A` |
| Text link | transparent, text `#B3141C` 16/700 |
| Attended / No-show | h44, r12, 15/700 with icon: green `#E3F4EA` / `#16794A`, orange `#FCEEDC` / `#A4520B`. In cards h40 r10 14/700 |
| Cancel booking | h44, r12, white bg, border 1.5px `#DCE1EC`, text `#B42318` |
| Icon buttons | 44×44, r12: call (bg `#13225A`, icon `#FF5C62`), add (bg `#D62828`, white icon), back (white, border `#DCE1EC`) |

### Inputs

- h52, r12, border 1.5px `#DCE1EC`, padding 0 16, text 15px, white background
- Focus: border `#FF5C62` with a 4px ring `#FEF1F1`
- Error: border `#B42318` and a 13/500 `#B42318` message below
- Phone field: LTR number with a `+218` prefix block (bg `#F4F6FB`, 15/600) separated by a 1px `#DCE1EC` border
- Switch: 50×30 pill. On: track `#13225A`, thumb `#D62828`. Off: track `#D4D8DF`, thumb white

### Badges

- Status badge: h30, r8, padding 0 12, 13/700, icon 14px, colors from the status table
- VIP pill: h30, r999, bg `#13225A`, text `#FF5C62` 13/800, crown icon
- Customer VIP: bg `#FBE0E1`, text `#8A1016`, border 1px `#FF5C62`
- VIP dot on avatar: 28×28 circle `#D62828`, white crown, 2px white border

### Cards

- **Barber / salon card**: white, r16, card shadow, padding 14, gap 12. A 72×72 r12 tile (bg `#1B3180`, icon or letter in `#FF5C62`), title 16/700, rating 13/700 with a `#FF5C62` star, meta 13px `#5E6878`, price 14/700 `#B3141C`
- **Booking card**: white, r16, card shadow, padding 14. Name 16/700, service 13px `#5E6878`, time 18/800 LTR, attended / no-show buttons below. The next booking gets a red outline
- **Stat card**: bg `#13225A`, r16, padding 16. Label 13px `#CBD3EC`, value 32/800 white, sub-line 13/600 `#FF8A8F`

### Navigation

- **Barber app bottom nav**: 4 tabs (الحجوزات، الخدمات، الإحصائيات، حسابي), h76, r20, bg `#13225A`. Active `#FF5C62` 12/700, inactive `#A8B5DF` 12/600
- **Customer app bottom nav**: 3 tabs (الرئيسية، حجوزاتي، حسابي), h76, r20, white with a `#DCE1EC` border. Active is `#13225A` 12/800 with a 48×30 `#FBE0E1` pill behind the icon. Inactive is `#5E6878`
- **Admin**: dark blue `#13225A` sidebar on the right (RTL) with the logo and these items: نظرة عامة، طلبات التفعيل (count badge)، الصالونات، الحلاقون، الاشتراكات، الحجوزات، الزبائن. Desktop frame is 1440 wide

### Icons and brand

- Line icons, 24px, stroke 1.8, round caps and joins. Back arrows point right in RTL
- Icon set: scissors, home, calendar, chart, user, map pin, clock, crown (VIP), phone, star (filled), send, location target, check, X, plus, cash
- Screen headers are dark blue `#13225A` with large rounded bottom corners
- Barber pole stripe: `repeating-linear-gradient(-45deg, #D62828 0 14px, #FFFFFF 14px 21px, #2448B8 21px 35px, #FFFFFF 35px 42px)`
- App icon: a barber pole on `#13225A` (see `design/screens/00-app-icon.png`)

## Screens

PNG renders are in `design/screens/<part>/`.

### Barber app (`apps/barber_app`)

| # | Screen | Arabic title | File |
|---|---|---|---|
| 0 | Login (not in the design, see below) | تسجيل الدخول | — |
| 1 | Sign up: name, phone, password, confirm password, optional photo, salon picker | حلاق ١ — التسجيل | `barber/01-register.png` |
| 2 | Pending activation: status steps, contact admin | حلاق ٢ — بانتظار التفعيل | `barber/02-pending-activation.png` |
| 3 | My services: toggle, price, duration per service | حلاق ٣ — الخدمات | `barber/03-services.png` |
| 4 | Working hours: per-day hours, day off, breaks | حلاق ٤ — أوقات العمل | `barber/04-working-hours.png` |
| 5 | Salon location: map pin, city, area | حلاق ٥ — الموقع | `barber/05-location.png` |
| 6 | Today's bookings: stats, attended / no-show, manual booking | حلاق ٦ — حجوزات اليوم | `barber/06-today-bookings.png` |
| 7 | Stats: daily and monthly customers, estimated income, top services | حلاق ٧ — الإحصائيات | `barber/07-stats.png` |
| 8 | Subscription / account: plan, expiry, admin contact, logout | حلاق ٨ — الاشتراك | `barber/08-subscription.png` |
| 9 | QR code (not in the design, see below) | رمز QR | — |

### Customer app (`apps/customer_app`)

| # | Screen | Arabic title | File |
|---|---|---|---|
| 0 | Login (not in the design, see below) | تسجيل الدخول | — |
| 1 | Sign up: name, phone, password | زبون ١ — التسجيل | `customer/01-register.png` |
| 2 | Home: city, search, area chips, nearby salons (nearest / top rated) | زبون ٢ — الرئيسية | `customer/02-home.png` |
| 3 | Salon page and barber choice: photos, hours, barbers, services | زبون ٣ — صفحة الصالون واختيار الحلاق | `customer/03-salon-and-barber.png` |
| 4 | Booking: barber, service, day, time slot, confirm | زبون ٤ — الحجز | `customer/04-booking.png` |
| 5 | My bookings: upcoming and past, directions, cancel, rate | زبون ٥ — حجوزاتي | `customer/05-my-bookings.png` |
| 6 | Rating: stars, tags, comment | زبون ٦ — التقييم | `customer/06-rating.png` |

### Admin dashboard (`apps/admin`)

| # | Screen | Arabic title | File |
|---|---|---|---|
| 1 | Overview: KPIs, activation requests, expiring subscriptions, salons table | الإدارة ١ — نظرة عامة | `admin/01-overview.png` |
| 2 | Salon and its barbers: per-barber subscription status, extend, pause, add barber | الإدارة ٢ — صالون وحلاقوه | `admin/02-salon-and-barbers.png` |

### Design reference boards

- `design/screens/00-design-system-foundations.png`: colors, type, spacing, radii, icons
- `design/screens/00-design-system-components.png`: buttons, inputs, badges, cards, bottom navs
- `design/screens/00-app-icon.png`: app icon

## Design decisions beyond the HTML

These were agreed after the design was approved and override `design/design.html` where they differ.

### Barber sign-up

Add **كلمة المرور** (password) and **تأكيد كلمة المرور** (confirm password) fields after the phone field, before the optional section. Use the standard input and error styles. Show the mismatch error under the confirm field.

### Login screen (both apps)

One layout shared from `packages/shared`, built from existing tokens and widgets:

- The same dark blue header as the sign-up screens (`#13225A`, large rounded bottom corners) with the app icon, the title "تسجيل الدخول" (H1, white) and a `#CBD3EC` subtitle
- Phone field with the `+218` prefix, then the password field
- "نسيت كلمة المرور؟" as a text link (`#B3141C`) aligned to the start, under the password field. It opens WhatsApp to the support number
- A primary button "تسجيل الدخول" (h52)
- At the bottom: "ليس لديك حساب؟ إنشاء حساب" linking to sign-up, in the same style as the sign-up screen's login link
- Wrong phone or password shows one error message under the password field, in the input error style

### Customer home lists barbers

The home screen lists barbers, not salons, even though the design board is titled "nearby salons". VIP and subscriptions are per barber, so ranking and visibility only work at barber level; each card still shows the salon name and area. A search looks in every city: while it has text, the city and area filters and the area chips step aside and the heading reads "نتائج البحث في كل المدن".

### Customer app additions from the polish review

- حجوزاتي reloads whenever its tab opens and whenever the app resumes (`homeTabProvider` drives the controlled `TabShell`). The confirmed screen adds "عرض حجوزاتي", which switches to that tab.
- A barber link or salon page for a barber who cannot be booked shows "<name> غير متاح للحجز حالياً" and selects nobody; the customer picks another barber.
- On booking, `23P01` counts as a taken slot, and `barber_not_bookable` disables confirm and offers "العودة لاختيار حلاق".
- The home filter button (the red button beside the search field, as designed) opens a sheet with "مفتوح الآن فقط" and "حلاقون VIP فقط"; a dot on the button shows an active filter. The salon page shows each bookable barber's next free start (today or tomorrow, for their shortest service) on the tile.
- The cancel button shows a spinner while the cancellation and the list refresh run. The salon page's loading, error and unavailable states have a back button. An admin signing in to the customer app gets `admin_account`.

### Light theme only

Both Flutter apps ship a light theme only. The design has no dark variant, so there is no dark `ThemeData` and no `prefers-color-scheme` handling.

### QR code screen and sticker

Opened from the account tab. A `PageTitle` with the back button, an `AppCard` with the QR of the barber link in `blue900`, the barber name (H2) and salon (caption), and one primary button that shares an A5 PDF sticker. The sticker has the dark blue header with «حلّاقي» and «احجز موعدك», the name, salon and QR, a scan hint and the barber pole stripe at the bottom. Its text is laid out by Flutter and embedded as 360 dpi images, because the `pdf` package cannot shape Arabic pairs such as «ري» correctly.

### Barber app additions from the polish review

- **Bookings tab**: a strip of `DayTile`s (`packages/shared`) under the header picks a day among the next `AppConstants.bookingDays` = 14, today by default. Manual bookings and cancellations work on any of them. "إغلاق بقية اليوم" is a visible button under the strip (the cancel-booking button style), and it and "إعادة الفتح" appear only on today. Attended and no-show show a snackbar with "تراجع".
- **Lapsed or suspended barbers** see a red banner with "تواصل مع الإدارة" above their bookings, and no manual booking button.
- **Account tab**: a profile card (photo, name, phone, salon · area) above the plan card opens the salon screen, where the owner can rename the salon. The plan card names the plan from the payment (`ArabicFormat.planName`). The menu adds "تغيير الصورة" and "تغيير كلمة المرور" (`ChangePasswordScreen` in `packages/shared`).
- **Pending activation**: the accent button reads "جهّز حسابك أثناء الانتظار" and opens a sheet with services, working hours and breaks, salon location and photo.
- Working hours ask before discarding unsaved changes; working hours and the salon screen go back after a successful save.

### Account tabs and undesigned screens

The customer and barber "حسابي" tabs (beyond the barber subscription screen) get simple versions built from the design system when we reach Steps 3 and 4.

### Admin sidebar sections without a design

Decide the content of each section in Step 6, then build simple versions from the existing table, card and badge styles:

1. طلبات التفعيل: activation requests
2. الحلاقون: barbers
3. الاشتراكات: subscriptions
4. الحجوزات: bookings
5. الزبائن: customers

The admin also needs a password reset action for barbers and customers (see "Forgot password" above).

The overview design shows a notification button in the header. It is left out: the panel has no notifications to show.
