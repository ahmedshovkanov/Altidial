# Energy Clock

Plan your day by energy, not just time.

Energy Clock puts a day on a 24-hour dial. You drag out events around the ring and give each one a **tone**:

| Tone | Colour | Meaning |
|---|---|---|
| Focus | Purple | Deep, demanding work |
| Life | Green | Body and rest |
| Inbox | Orange | Routine and reactive work |

Reading the ring tells you what kind of day you have committed to before you read a single word. Everything stays on the device: no account, no backend.

## Run it

```bash
flutter pub get
flutter run
```

It runs on iPhone (portrait) and iPad (all orientations). The dial planner, the week strip, the Now card, the event sheets, the session timer, repeating events, day templates, Copy yesterday, the Calendar, Stats (week/month tone balance, planned-vs-actual, focus depth, heatmap) and Profile (level and streaks, energy score, badges, weekly roundups, settings, export) are done; notifications arrive in Step 5.

## Test it

```bash
flutter analyze
flutter test
```

Dial goldens live in `test/features/clock/goldens`. After a deliberate visual change, regenerate them with `flutter test --update-goldens test/features/clock/dial_golden_test.dart` and look at the images.

Drift generates code for the database. After changing a table or DAO, run it with the Flutter SDK's `dart`:

```bash
"$(dirname "$(which flutter)")/dart" run build_runner build --delete-conflicting-outputs
```

## Project layout

```
lib/
  app/          app shell, theme tokens, tab bar, onboarding
  core/         pure logic: time, dial geometry, strings, tones
  data/         Drift database, DAOs, repositories
  features/     clock, session, calendar, stats, progress (profile)
  shared/       widgets and layout helpers used by every feature
tool/brand/     generates the app icon and launch logo
docs/superpowers/
  specs/        design specs
  plans/        implementation plans
```

Features never import each other; they share data through repositories exposed as Riverpod providers. Feature code never hard-codes a colour (a test enforces it).

## Design and plans

- `docs/superpowers/specs/2026-08-23-energy-clock-design.md`: the product spec (Phases 1–5).
- `docs/superpowers/specs/2026-10-03-step-1-foundation-design.md`: the Step 1 design (look, dial v2, Clock screen, iPad, brand, onboarding).
- `docs/superpowers/plans/`: the implementation plans.

## Fonts

The app bundles [Nunito](https://fonts.google.com/specimen/Nunito) under the SIL Open Font Licence (`assets/fonts/OFL.txt`).
