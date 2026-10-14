# Roadmap

Mark each step `[x]` when it is finished.

| Done | Step | Scope | Model |
|---|---|---|---|
| [x] | 1. Project setup | Monorepo folders, `.gitignore`, `CLAUDE.md`, design system, screen list | Opus 5.5 Medium |
| [x] | 2. Database | Supabase schema, RLS, auth (phone → internal email), booking rules | Fable 5.1 (or Opus 5.5 High) |
| [x] | 3. Barber app | `apps/barber_app` and `packages/shared` | Opus 5.5 for the first screens, then Sonnet 5.5 |
| [x] | 4. Customer app | `apps/customer_app`. Add a migration granting `anon` select on `salon_barbers` and `salon_hours` so visitors can browse salon pages before signing up | Opus 5.5 for the booking flow, Sonnet 5.5 for the rest |
| [x] | 5. Notifications and QR | Push notifications, QR check-in | Opus 5.5 |
| [x] | 6. Admin dashboard | `apps/admin` (Next.js), including password reset for barbers and customers. When approving a barber, show the salon location on a map with the option to correct it | Sonnet 5.5 |

## Polish before launch

Design token items left over from the Step 3 review. Fix them against `design/design.html`.

- [x] Today's bookings header: the avatar circle uses `blue800`; the design uses `bluePressed` `#2A45A3`
- [x] Stats income cards: white card with a 1px `#DCE1EC` border instead of the shadow, value 26/800, unit 14/700 `text2`. Top-service tile 48px r14 `red100` / `vipText`, title 18/800
- [x] Pending activation steps: current-step label `red300` `#FF8A8F` with a 10px `poleRed` dot; hero circle 128 instead of 132
- [x] Working hours time chips: h36 r10 14/700 instead of h40 r12
- [x] Location bottom sheet: top radius 28 (`AppRadius.header`) instead of 20
- [x] BookingCard cancel: the design system has no outlined X icon button; use the "إلغاء الحجز" text button (`ActionButton.cancel`)
- [x] Customer home: the filter button does nothing yet; wire it up
- [x] Customer salon page: show the next free time on each barber tile
- [ ] Move iOS Firebase from CocoaPods to Swift Package Manager in both apps: needs a Flutter upgrade; do it on its own branch after launch
- [ ] Per-customer booking cooldown if book-and-cancel spam appears
- [x] Periodic cleanup of `cron.job_run_details`

Items from the app review on the `polish-ui` branch.

- [x] Expired or suspended barbers enter the app with a red banner and the WhatsApp support button; they manage existing bookings but cannot add manual bookings (enforced in `create_manual_booking`)
- [x] Keyboard: a tap outside a field or a scroll closes it in both apps, and saving closes it
- [x] QR link to a barber who cannot be booked says so instead of selecting another barber
- [x] The salon name typed at sign-up is kept, and the salon owner can rename the salon
- [x] Barber account tab: profile card (photo, name, phone, salon, area) that opens the salon location, the real plan name, and change password
- [x] Attended / no-show can be undone
- [x] Pending barbers can set up working hours, breaks, location and photo
- [x] Push to the barber on activation through the outbox; the pending screen refreshes when the app resumes
- [x] Working hours: leaving with unsaved changes asks first
- [x] Working hours and location go back after a successful save
- [x] Barber bookings: day picker for the next 14 days; manual bookings and cancellations on any of them
- [x] Customer home search: the keyboard does not come back after visiting a barber, and scrolling closes it
- [x] Barber stats refresh after attended, no-show, cancel and manual booking
- [x] "إغلاق بقية اليوم" is a visible action
- [x] Barber bottom sheets scroll so the keyboard never hides the confirm button
- [x] Barber location: "open settings" when location permission is denied, and a back button while loading
- [x] Sign-out asks for confirmation and does not hang offline
- [x] حجوزاتي refreshes when the tab opens and when the app resumes
- [x] Customer salon page: loading, error and unavailable states have a back button
- [x] Customer cancel booking: busy state and no double cancel
- [x] Booking: a slot taken by someone else (`23P01`) refreshes the slots, and `barber_not_bookable` disables confirm
- [x] Home search looks in every city
- [x] Booking confirmed screen: "عرض حجوزاتي"
- [x] Change password cannot be sent twice
- [x] Signing in to the customer app with an admin account shows a neutral message

## Before Ramadan 2027

- [ ] Working hours that close after midnight (e.g. 14:00 to 00:30). Needs a schema change (`working_hours` allows `closes_at > opens_at` only), an overnight window in `get_available_slots`, `create_manual_booking`, `close_rest_of_today` and `salon_hours`, a decision on which day a booking after midnight belongs to in the barber's day view and stats, and a time picker in the app that allows the next day

## Ongoing

| Task | Model |
|---|---|
| Bug fixing | Sonnet 5.5. Switch to Opus 5.5 after 2 failed attempts |
| Security review before launch | Fable 5.1 |
