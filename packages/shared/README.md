# shared

Dart package used by both Flutter apps (`barber_app`, `customer_app`). Anything both apps need lives here instead of being copied into an app.

| Folder | Contents |
|---|---|
| `lib/src/theme` | Colour, type, spacing, radius and size tokens, `ThemeData`, the focus ring border |
| `lib/src/widgets` | Buttons, text fields, phone field, badges, cards, switch, headers, logo, bottom sheet helper, login screen |
| `lib/src/models` | Profiles, salons, barbers, services, working hours, bookings, reviews, stats |
| `lib/src/repositories` | Supabase queries and RPC calls |
| `lib/src/errors` | Arabic messages for database and auth errors |
| `lib/src/format` | Arabic dates, numbers and prices; `AppTime` for Libya time |
| `lib/src/constants.dart` | Constants that mirror the SQL functions |
| `assets/fonts` | Cairo variable font |
| `tool` | Script that renders the app icon |

## Rules

- Times and days are always Libya time (`AppConstants.timezone`) through `AppTime`, never the device zone.
- RPCs raise fixed error codes; `bookingErrorMessage` and `authErrorMessage` turn them into Arabic and fall back to one generic message. Raw database text never reaches the user.
- Cairo is a variable font: use `AppText.weight` when changing a text style's weight.

## Tests

```
flutter analyze
flutter test
```
