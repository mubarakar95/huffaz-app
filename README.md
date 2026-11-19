# Huffaz

[![CI](https://github.com/mubarakar95/huffaz-app/actions/workflows/ci.yml/badge.svg)](https://github.com/mubarakar95/huffaz-app/actions/workflows/ci.yml)

A Flutter app for Quran memorisation (Hifz) institutions. Teachers log each student's daily **Sabaq** (new lesson), **Sabqi** (recent revision) and **Manzil** (old revision), and the app tracks progress, streaks and weekly pace across a 604-page mushaf.

## Features

- Teacher login and onboarding, with per-institution data
- Student list with add, edit and detail screens, and per-student daily goals
- Daily logging sheets for Sabaq, Sabqi and Manzil
- Streak tracking that respects holidays, weekly off days and "preserve streak" days
- Weekly velocity and an Active / Needs Attention / Inactive status for each student
- Daily, weekly and monthly reports
- Teacher management and lesson acknowledgements
- Offline-first local storage with Hive, synced with Supabase
- Local notifications

## Tech stack

| Area | Choice |
| --- | --- |
| UI | Flutter (Dart SDK >= 3.3.0), Material, `google_fonts`, `flutter_animate` |
| State | `provider` (`ChangeNotifier`) |
| Routing | `go_router` |
| Backend | Supabase (Postgres, Auth, row-level security) via `supabase_flutter` |
| Local storage | `hive` / `hive_flutter`, `shared_preferences` |
| Notifications | `flutter_local_notifications`, `timezone` |

## Project structure

```
lib/
  core/        theme, router, Supabase client
  models/      Student, SabaqLog, Profile
  providers/   AppProvider (app-wide state)
  services/    auth, students, dashboard, reports, settings, notifications
  screens/     auth, onboarding, dashboard, students, reports, settings
  widgets/     logging sheets and shared widgets
  utils/       Quran page data and streak / velocity logic
supabase/      SQL for row-level security and teacher management
test/unit/     unit tests for the logic and models
```

The streak, juz mapping and velocity rules live in `lib/utils/student_utils.dart` and are plain Dart functions, so they are covered by unit tests without needing a device or a database.

## Getting started

1. Install [Flutter](https://docs.flutter.dev/get-started/install).
2. Create a Supabase project and run the SQL files in `supabase/`.
3. Add your project URL and anon key in `lib/core/supabase_client.dart`. The anon key is public by design, so keep row-level security enabled on every table.
4. Run the app:

```bash
flutter pub get
flutter run
```

## Tests

```bash
flutter test test/unit
```

Continuous integration runs `flutter analyze` and the unit tests on every push to `main` and on every pull request (`.github/workflows/ci.yml`).

## Status

Version 1.0.4. Built by [Mubarak AR](https://github.com/mubarakar95).
