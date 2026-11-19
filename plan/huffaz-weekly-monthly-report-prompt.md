# Task: Implement Weekly and Monthly tabs on the existing Reports screen

## Context

This follows a prior pass that added a `Reports` tab to the Huffaz app (Flutter, Supabase, Provider, `go_router` `ShellRoute`, Hive offline cache). That pass built:

- `/reports` route in the `ShellRoute`, `ReportsScreen` with a segmented control (Daily / Weekly / Monthly)
- A working **Daily** report: a table where each row is a student, with fixed columns Student / Sabaq / Sabqi / Muraja, each lesson cell a colour-tinted pill (`value/goal`), role-scoped (admin sees all students + teacher filter chips, teacher sees only their own students)
- `ReportService` (`lib/services/report_service.dart`) and matching `AppProvider` state/methods for the daily fetch
- **Weekly and Monthly were left as disabled "Coming soon" placeholders** — this task replaces those placeholders with working implementations

Reuse everything already built for Daily: the design system ("Serene Path" — see below), the role-scoping rule, the `Student`/`SabaqLog` models, the status colour logic, and the segmented control/summary strip/teacher-filter-chip components. Do not rebuild those from scratch — extend the same `ReportsScreen`/`ReportService`/`AppProvider` code.

### Design system reminder (must match exactly)

```
Primary: #2D6A4F   PrimaryLight: #52B788   PrimaryDark: #1B4332
Success: #10B981   Warning: #F59E0B   Danger: #EF4444   Info: #1D3557
Light: Background #F8FAF9, Surface #FFFFFF, Surface2 #ECECEF, Border #D8DFDE,
       TextMain #1D3557, TextMuted #455A64, TextTertiary #78909C
Dark:  Background #101216, Surface #1A1C20, Surface2 #23262A, Border #2C2F34,
       TextMain #ECF1F1, TextMuted #B0BEC5, TextTertiary #78909C
```
Font Manrope, radius `20` everywhere, elevation `0`, borders only, `flutter_animate` for entrance transitions, never hardcode hex — use `AppColors`.

### Role scoping reminder (same rule as Daily, and as Students tab)

| Role | Sees |
|---|---|
| `admin` / `super_admin` | All institution students + teacher filter chips |
| `teacher` | Only their own assigned students (+ absent-teacher fallback), no filter chips |

---

## 1. Weekly report

### Layout — same table shape as Daily, different cell content

Still one row per student, still 3 fixed columns (Sabaq / Sabqi / Muraja) — **do not expand to 21 columns (7 days × 3 lessons)**, that breaks the "view many students at a glance" goal. Instead, each of the 3 columns becomes a compact **7-day strip**:

- Column header: lesson name ("Sabaq") with a small week-total sub-label underneath (e.g. "6.5/7.0")
- Cell body: 7 small dots/squares in a row, one per day (Mon → Sun, or the last 7 calendar days ending today — pick whichever aligns with how streak calculation already windows "the week" in `student_utils.dart`, reuse that windowing logic rather than inventing a new one)
- Each dot coloured using the same status logic as Daily: green = goal met that day, amber = partial, red = skipped, grey = not logged / holiday / weekly-off-day (use existing holiday/off-day exclusion logic from streak calc so those days don't unfairly read as "missed")
- Dot size should stay legible at 3 columns × 7 dots without needing horizontal scroll on a typical phone width — test against something like a 360dp-wide screen

### Data

- `ReportService.fetchWeeklyReport({required String endDate, ...})` — pull the last 7 days of `SabaqLog` entries per visible student (reuse `provider.allLogs` if it already holds enough history client-side; only hit Supabase directly if 7 days of logs aren't already cached)
- Aggregate per student: array of 7 daily statuses per lesson type, plus a week total (sum of pages logged vs sum of goals × 7, adjusted for holidays/off-days)
- Expose via `AppProvider.fetchWeeklyReport()` / `weeklyReportData`, same pattern as the daily state added previously

### Interaction

- Tapping a single dot in a strip → small popover or bottom sheet showing that day's specific log detail (reuse the existing per-day log detail sheet if one already exists from Student Detail's lesson history; otherwise a lightweight inline tooltip is acceptable — don't build a whole new detail screen for this)
- Tapping the student row itself (not a specific dot) → navigate to `StudentDetailScreen`, same as Daily

### Summary strip

Same 2-metric-card row pattern as Daily, but week-scoped: e.g. "Avg completion this week", "Total absences this week"

---

## 2. Monthly report

### Header — month switcher

Replace the date label used on Daily with a month switcher: `‹  August 2026  ›` — left/right chevron icons stepping one calendar month at a time, centered label. Style consistent with existing date-selector patterns already in the app (e.g. the retroactive-log date picker in `AppShell`) rather than inventing a new date-picker component if one already exists to reuse.

### Layout — same 3-column table shape again

Same Student / Sabaq / Sabqi / Muraja columns. Each lesson cell now shows the **monthly aggregate**: total pages logged that month vs total goal for the month (goal × working days in that month, excluding holidays/off-days), same tint logic (green/amber/red) based on overall completion rate for the month, not a single day.

### Data

- `ReportService.fetchMonthlyReport({required int year, required int month, ...})` — query/aggregate `SabaqLog` entries for the full selected month per visible student
- Per student: total Sabaq/Sabqi/Muraja pages, completion rate %, absent/sick day count, longest streak within that month
- Expose via `AppProvider.fetchMonthlyReport()` / `monthlyReportData`

### Row expansion — reuse the existing streak calendar

Tapping a student row expands (inline accordion, or pushes to a lightweight sheet — whichever is less invasive to implement given the existing widget tree) to show the **same streak-calendar heat map component already used on Student Detail**, scoped to the selected month only. Do not build a second calendar component — extract/reuse the existing one if it isn't already generic enough to accept a month range.

### Summary strip

Month-scoped versions of the same metric cards: "Avg completion this month", "Total absences this month"

---

## 3. Segmented control changes

- Remove the disabled/greyed "Coming soon" state from Weekly and Monthly — both are now fully interactive
- Switching tabs should re-fetch (or read from cache if already fetched for that period) rather than re-fetch on every tap — cache the last-fetched Weekly/Monthly result in `AppProvider` similarly to how `dashboardData` is cached, and only refetch on pull-to-refresh or when the selected week/month actually changes

---

## Explicitly out of scope for this pass

- CSV/PDF export of any report
- Push notifications
- Cross-institution or multi-institution reporting
- Custom date-range reports (only calendar week / calendar month as scoped above)

---

## Deliverable

Working Flutter code that:
1. Replaces the Weekly and Monthly placeholder tabs on `ReportsScreen` with the implementations above
2. Adds `fetchWeeklyReport` / `fetchMonthlyReport` to `ReportService` and matching cached state/methods to `AppProvider`
3. Reuses the existing streak calendar component for the Monthly row expansion rather than duplicating it
4. Reuses existing holiday/weekly-off-day exclusion logic from `student_utils.dart` for both Weekly dot colouring and Monthly goal totals
5. Matches existing codebase conventions exactly: `const` constructors, `Consumer<AppProvider>`/`context.watch` in build, `context.read` in callbacks, no code generation, dual snake_case/camelCase handling if touching models
