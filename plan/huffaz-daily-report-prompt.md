# Task: Add "Reports" tab with Daily Report to Huffaz app

## Context

Huffaz is a Flutter (Dart SDK ≥3.3.0) app for Quran memorisation (Hifz) institutions, using Supabase (Postgres + Auth) as backend, Provider (`ChangeNotifier`) for state, `go_router` with a `ShellRoute` for navigation, and Hive for offline-first caching.

Domain terms used as-is in code:
- **Sabaq** — new lesson (pages memorised today for the first time)
- **Sabqi** — recent revision (recently memorised Juz revised today)
- **Manzil / Muraja** — old revision (older memorised Juz revised today)
- Quran = 604 pages across 30 Juz (~20 pages each)

### Existing structure (do not restructure, extend it)

```
lib/
├── core/ (theme.dart, router.dart, supabase_client.dart)
├── models/ (student.dart, sabaq_log.dart, profile.dart)
├── providers/app_provider.dart   # single monolithic ChangeNotifier, all app state lives here
├── services/ (auth_service.dart, student_service.dart, dashboard_service.dart, settings_service.dart)
├── screens/ (splash, auth, onboarding, shell, dashboard, students/, settings)
├── widgets/ (log_sabaq_sheet.dart, log_sabqi_sheet.dart, log_manzil_sheet.dart, mark_student_sheet.dart, alphabet_scrollbar.dart)
└── utils/ (quran_data.dart, quran_data_mapping.dart, student_utils.dart)
```

### Design system — "Serene Path" (must match exactly, no deviation)

```
Primary:       #2D6A4F
PrimaryLight:  #52B788
PrimaryDark:   #1B4332
Success:  #10B981   Warning: #F59E0B   Danger: #EF4444   Info: #1D3557

Light surfaces: Background #F8FAF9, Surface #FFFFFF, Surface2 #ECECEF,
                Border #D8DFDE, TextMain #1D3557, TextMuted #455A64, TextTertiary #78909C
Dark surfaces:  Background #101216, Surface #1A1C20, Surface2 #23262A,
                Border #2C2F34, TextMain #ECF1F1, TextMuted #B0BEC5, TextTertiary #78909C
```

- Font: Manrope via `google_fonts`, existing `theme.textTheme` styles
- Border radius: `20` everywhere (cards, inputs, buttons, chips, table cell pills)
- Elevation: `0` everywhere — borders only, no shadows
- Use `flutter_animate` for entrance animation (`.fadeIn()`, `.slideY()`, staggered `delay`)
- Follow existing `AppColors` class — never hardcode hex values, reference the theme

### Existing role model (reuse exactly, do not invent a new one)

| Role | Visibility today (Students tab / Dashboard) |
|---|---|
| `admin` / `super_admin` | All institution students |
| `teacher` | Only their assigned students, plus students of teachers marked absent today |

`provider.isAdmin` and `provider.profile?.role == 'teacher'` are the existing checks — reuse them.

### Existing data model (reuse, do not duplicate)

`Student`: id, fullName, teacherId, teacherName, isPersonal, sabaqGoal, sabqiGoal, manzilGoal, progressPercent, uniqueCount, currentJuz, streak, todayStatus, todaySabaqPages, todaySabqiPages, todayManzilPages

`SabaqLog`: id, studentId, teacherId, teacherName, studentName, date (YYYY-MM-DD), status (`complete`|`absent`|`sick`|`other`|`baseline`|`baseline_sabqi`), sabaq (encoded string), manzil (JSONB with `sabqi[]` and `manzilPages[]`), createdAt

The colour/status logic (green = goal met, amber = partial, red = skipped/absent) already exists somewhere in the students list / dashboard rendering — **find and reuse that exact logic**, don't re-derive new thresholds.

---

## What to build (this pass: Daily report only)

### 1. Navigation — new 4th tab

Add a `Reports` tab to the existing `ShellRoute` bottom nav, alongside Dashboard, Students, Settings:

```
ShellRoute (AppShell)
  /dashboard
  /students
  /reports        ← NEW
  /settings
```

Same flat `NavigationBar` style already used (elevation 0, `primary.withOpacity(0.15)` selected indicator). Pick an appropriate Material icon (e.g. `Icons.bar_chart_rounded` or `Icons.assessment_outlined`) consistent with the existing icon style on other tabs.

### 2. Role-based data scoping (client-visible to both roles, data differs)

The **same screen and UI** is shown to both roles — only the query/filter differs:

- `admin` / `super_admin` → sees all institution students, **with a teacher filter chip row** (reuse the same chip component/style already used on Students List for the admin teacher filter)
- `teacher` → sees only their own assigned students (+ absent-teacher fallback students, same rule as Students tab) — **no teacher filter chip row shown** (it would be meaningless with a pre-filtered set)

### 3. Screen layout — `ReportsScreen`

Structure, top to bottom:

1. **App bar**: title "Reports" (or "My students — today" for teacher role, optional), date label on the right (defaults to today)
2. **Segmented control** (Daily / Weekly / Monthly) — pill style, `r:20`, matching the segmented control pattern already used elsewhere in the app (e.g. filter toggles). **For this pass, only "Daily" is functional — Weekly and Monthly tabs render a "Coming soon" placeholder state and are disabled/greyed, no crash.**
3. **Summary strip**: 2 metric cards side by side (or a row) — "Logged X / Y", "Absent Z" — same flat card style as Dashboard's stats row (`Surface` bg, 1px border, `r:20`, no shadow)
4. **Teacher filter chip row** — admin only, same chip style/behavior as Students tab
5. **Report table** — see below

### 4. Report table — the core UI requirement

**This must be a table, not stacked cards.** Each row = one student. Fixed columns:

| Student | Sabaq | Sabqi | Muraja |
|---|---|---|---|

- **Student column**: name (medium weight, `TextMain` colour) + teacher name below in smaller `TextTertiary` (admin view only — omit teacher sub-label in teacher's own view since it's redundant)
- **Sabaq / Sabqi / Muraja columns**: each cell is a small pill/badge (`r:8` minimum, or match existing badge radius) showing `value/goal` (e.g. "1.0/1.0", "10/10", "12/20"), background-tinted by status:
  - Green tint (`Success` family) — goal fully met
  - Amber tint (`Warning` family) — partially met
  - Red tint (`Danger` family) — skipped
  - Neutral grey (`Surface2`/`TextTertiary`) — not logged yet ("–")
- **Absent/sick row state**: when `todayStatus` is `absent` or `sick`, merge the 3 lesson columns into a single centered cell spanning all three, showing the status label in the red tint (no need to show empty page values three times)
- Use `Table`, `DataTable`, or a `Column` of `Row`s with fixed-width flex columns — whichever renders cleanly and stays performant for 50+ rows. Column widths roughly: Student ~38%, each lesson column ~20.6%.
- Row tap → navigate to existing `StudentDetailScreen` (`context.push('/students/:id')`), same as Students List row tap
- List should support the same sort behaviour as Students List where sensible (e.g. "pending first" toggle) — reuse the sort logic already implemented for Students tab if straightforward, otherwise skip for this pass

### 5. Data/service layer

- Add `ReportService` in `lib/services/report_service.dart` with `Future<List<Student>> fetchDailyReport({required String date, String? role, String? profileId})` — for this pass, it can most efficiently just filter the already-cached `provider.students` + `provider.allLogs` for the given date client-side (matching `todayStatus`/`todaySabaqPages` etc. already on the `Student` model) rather than a new Supabase round-trip, since this data is already fetched for Dashboard/Students. Only add a dedicated Supabase query if today's cached student data doesn't cover arbitrary past dates well — check `selectedDateStr` handling already used for retroactive logging, it likely already solves this.
- Add corresponding state to `AppProvider` (`reportStudents`, `isLoadingReport`, `fetchDailyReport()` method) following the exact pattern of how `dashboardData` is currently fetched and exposed — do not create a second provider.

### 6. Explicitly out of scope for this pass

- Weekly report (7-day matrix per student) — placeholder tab only
- Monthly report (month switcher + aggregates) — placeholder tab only
- CSV/PDF export
- Push notifications about report status

---

## Deliverable

Working Flutter code for:
1. New `/reports` route wired into the existing `ShellRoute`
2. `ReportsScreen` with segmented control (Daily functional, Weekly/Monthly disabled placeholders)
3. Daily report table exactly as specified above, role-scoped
4. `ReportService` + `AppProvider` additions
5. No changes to existing screens/services beyond what's needed to add the new tab and expose the report data

Match the existing codebase's conventions exactly: `const` constructors, `Consumer<AppProvider>`/`context.watch` in build methods, `context.read` in callbacks, dual snake_case/camelCase handling if touching any model, no code generation.
