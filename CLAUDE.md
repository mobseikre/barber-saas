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
│   └── shared/            Dart package used by both Flutter apps
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
- **Utilities**: Arabic date and number formatting, LYD price formatting

The apps depend on it through a path dependency (`shared: { path: ../../packages/shared }`). App-specific screens and providers stay in their own app.

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
- **No-shows**: barbers mark a booking as no-show. No-shows are counted per customer. After `3` no-shows the customer is blocked from creating bookings until an admin unblocks them. The limit lives in one SQL constant function and one shared Dart constant, never inline.
- **Admin visibility**: the admin can see each barber's cancellation count and reasons.
- **Estimated income** in barber stats is computed only from completed bookings' prices.

## Database

Migrations live in `supabase/migrations/`, pgTAP tests in `supabase/tests/` (`supabase test db`). Run `supabase db reset` after changing a migration.

- **Tables**: `cities`, `areas`, `profiles`, `salons`, `barbers`, `service_catalog`, `barber_services`, `working_hours`, `breaks`, `day_closures`, `bookings`, `reviews`, `subscription_payments`, `device_tokens`.
- **`barbers` is separate from `profiles`**: `profile_id` is nullable so admins can list barbers without an account. Bookable = `is_barber_bookable(id)`: status `active`, has an account, `subscription_ends_at` in the future.
- **Bookings are never written directly from the apps.** RLS allows only reads. Use the RPCs: `create_booking`, `create_manual_booking`, `set_booking_status`, `cancel_booking`, `close_rest_of_today`. Admin-only: `activate_subscription`, `unblock_customer`.
- **Availability**: `get_available_slots(barber_id, date, duration_min)` returns 15-minute slots in `Africa/Tripoli`, minus working hours, breaks, closures, existing bookings and the past. `create_booking` only accepts a start time that this function returns.
- **Overlaps** are impossible at the database level: `EXCLUDE USING gist (barber_id WITH =, time_range WITH &&) WHERE (status <> 'cancelled')`.
- **Constants** are SQL functions: `no_show_limit()` = 3, `upcoming_booking_limit()` = 2, `cancellation_window()` = 2 hours, `app_timezone()`. Mirror them in `packages/shared`, never inline.
- **Views**: `salon_barbers` (public listing including non-bookable barbers, with `is_bookable`), `salon_hours`, `admin_barber_cancellations`.
- **Security: the service role key never ships to a client.** It must not appear in the Flutter apps or in browser code of the admin panel. Only Edge Functions and server-side code may use it. The apps use the anon/publishable key with RLS; privileged admin actions (password reset, anything bypassing RLS) go through an Edge Function that checks `is_admin()` first.
- **Auth metadata**: sign-up must pass `full_name`, `phone` (as `218XXXXXXXXX`) and `role` (`customer` or `barber`) in the user metadata; a trigger creates the profile. `admin` can't be set from metadata.

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
