# Roadmap

Mark each step `[x]` when it is finished.

| Done | Step | Scope | Model |
|---|---|---|---|
| [x] | 1. Project setup | Monorepo folders, `.gitignore`, `CLAUDE.md`, design system, screen list | Opus 5.5 Medium |
| [ ] | 2. Database | Supabase schema, RLS, auth (phone → internal email), booking rules | Fable 5.1 (or Opus 5.5 High) |
| [ ] | 3. Barber app | `apps/barber_app` and `packages/shared` | Opus 5.5 for the first screens, then Sonnet 5.5 |
| [ ] | 4. Customer app | `apps/customer_app` | Opus 5.5 for the booking flow, Sonnet 5.5 for the rest |
| [ ] | 5. Notifications and QR | Push notifications, QR check-in | Opus 5.5 |
| [ ] | 6. Admin dashboard | `apps/admin` (Next.js), including password reset for barbers and customers | Sonnet 5.5 |

## Ongoing

| Task | Model |
|---|---|
| Bug fixing | Sonnet 5.5. Switch to Opus 5.5 after 2 failed attempts |
| Security review before launch | Fable 5.1 |
