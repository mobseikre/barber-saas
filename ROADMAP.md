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

- [ ] Today's bookings header: the avatar circle uses `blue800`; the design uses `bluePressed` `#2A45A3`
- [ ] Stats income cards: white card with a 1px `#DCE1EC` border instead of the shadow, value 26/800, unit 14/700 `text2`. Top-service tile 48px r14 `red100` / `vipText`, title 18/800
- [ ] Pending activation steps: current-step label `red300` `#FF8A8F` with a 10px `poleRed` dot; hero circle 128 instead of 132
- [ ] Working hours time chips: h36 r10 14/700 instead of h40 r12
- [ ] Location bottom sheet: top radius 28 (`AppRadius.header`) instead of 20
- [ ] BookingCard cancel: the design system has no outlined X icon button; use the "إلغاء الحجز" text button (`ActionButton.cancel`)
- [ ] Customer home: the filter button does nothing yet; wire it up
- [ ] Customer salon page: show the next free time on each barber tile
- [ ] Move iOS Firebase from CocoaPods to Swift Package Manager in both apps
- [ ] Per-customer booking cooldown if book-and-cancel spam appears
- [ ] Periodic cleanup of `cron.job_run_details`

## Ongoing

| Task | Model |
|---|---|
| Bug fixing | Sonnet 5.5. Switch to Opus 5.5 after 2 failed attempts |
| Security review before launch | Fable 5.1 |
