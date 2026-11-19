# Task: Teacher Management + Teacher Leave Report (Settings, admin-only)

## Context

Huffaz is a Flutter app (Supabase backend, Provider state via a single `AppProvider`, `go_router` `ShellRoute`, Hive offline cache) for Quran memorisation (Hifz) institutions. Admins manage teachers who each log daily lessons (Sabaq/Sabqi/Muraja) for their assigned students.

The current Settings screen already has a lightweight, unstructured "Teacher Management" area (admin-only) that supports:
- Inviting a teacher by email (sends a Supabase invitation, auto-accepted on their first login)
- Scheduling a teacher's absence (date range picker)

**What's missing, and what this task adds:**
1. An actual **list view of current teachers** — this doesn't exist today, admins have no way to see who's on their team
2. **Disabling a teacher** (soft removal — see section 3, no hard delete)
3. A **teacher leave report** — how many absence days each teacher has taken, viewable per month

This is admin-only. Reuse `provider.isAdmin` for the visibility gate, same as everywhere else in the app.

### Design system reminder (must match exactly)

```
Primary: #2D6A4F   PrimaryLight: #52B788   PrimaryDark: #1B4332
Success: #10B981   Warning: #F59E0B   Danger: #EF4444   Info: #1D3557
Light: Background #F8FAF9, Surface #FFFFFF, Surface2 #ECECEF, Border #D8DFDE,
       TextMain #1D3557, TextMuted #455A64, TextTertiary #78909C
Dark:  Background #101216, Surface #1A1C20, Surface2 #23262A, Border #2C2F34,
       TextMain #ECF1F1, TextMuted #B0BEC5, TextTertiary #78909C
```
Font Manrope, radius `20` everywhere, elevation `0` (borders only), `flutter_animate` for entrance transitions, never hardcode hex — use `AppColors`. Reuse the same colour-tint pill pattern already used for report badges (green/amber/red/grey) for the leave-count indicator described below.

---

## 1. Entry point

On the **Settings screen**, replace the current loose "Teacher Management" bits with a single tappable card/row: **"Manage Teachers"** (admin-only, same visibility rule as the rest of that section), showing a small subtitle like "N teachers". Tapping it pushes a new full-screen `TeacherManagementScreen` (`context.push('/settings/teachers')` or similar, above the shell — same navigation pattern as Student Detail).

## 2. `TeacherManagementScreen` — teacher list

- **App bar**: "Teachers", back button
- **Summary strip** (same flat metric-card row pattern used on Dashboard/Reports): "Total teachers", "Absences this month" (institution-wide sum)
- **Teacher list**, one row/card per teacher, styled consistently with the Students List cards (`Surface` bg, 1px border, `r:20`, no shadow):
  - Name
  - Assigned student count (e.g. "12 students")
  - **Leave badge**: pill showing absence days taken this month, colour-tinted — grey/green for 0, amber for a moderate range, red if it crosses whatever threshold feels reasonable for a teaching role (make this a simple configurable constant, not hardcoded magic logic scattered around)
  - Overflow menu (3-dot icon) per row with: **Schedule absence** (existing flow, just relocated here), **View absence history**, **Disable teacher**
- **FAB** (`+`, same green FAB style as Students tab) → opens the existing "Invite teacher by email" bottom sheet (reuse it as-is, just make sure it refreshes this list on success)
- Tapping a row (not the overflow menu) → expand or push to a simple **Teacher Detail** view: their info + full absence history list for the year, reusing whatever list/calendar UI pattern is cheapest to reuse from the Monthly report's streak calendar work, if that's already built by the time this is implemented — otherwise a plain chronological list of absence date ranges is fine for this pass

## 3. Disable teacher — soft removal only, no hard delete

**No hard delete of the Supabase auth user.** Supabase client apps (anon/user key) can't safely delete another user's `auth.users` record from the client anyway — that needs the service role key, which must never ship in the Flutter app. This feature is **disable-only**:

- Add an `is_active` (or `status`) column to `profiles` if one doesn't already exist. "Disable teacher" sets it to inactive.
- Disabled teachers stop appearing in teacher lists, filters, and assignment pickers going forward, but their historical logs and attribution stay fully intact — never orphan past `sabaq_logs` data or rewrite who logged what.
- A disabled teacher's login access should also stop working (check on session load / route guard, same place `AppProvider.initialize()` already checks profile/institution state) — but their account and data are never deleted.
- Include a way to **re-enable** a disabled teacher later (e.g. a small "Show disabled teachers" toggle at the bottom of the list, with a re-enable action) — since there's no delete, this is the only way to undo the action.

**Before disabling a teacher, check if they have assigned students** (`teacherId == this teacher's id`). If they do, block the action (or prompt) with: "This teacher has N students assigned. Reassign them first." — a simple picker to bulk-reassign those students to another active teacher, or leave them unassigned (`teacherId = null`) if the data model already tolerates that. Don't silently orphan students.

Confirm with a standard destructive-action-style dialog (amber or red confirm button — it's reversible, so red may be overly alarming) before proceeding.

## 4. Teacher leave report — data

- Extend (or add to) `SettingsService` with a method to fetch absence data per teacher for a given month, aggregating from the existing `teacher_absences` table (`institution_id`, `teacher_id`, `absence_date` — expand date ranges to individual days if they're stored as ranges, check the actual schema).
- Add matching state/method to `AppProvider` (e.g. `teacherLeaveData`, `fetchTeacherLeaveReport(year, month)`), following the same caching pattern already used for dashboard/report data — fetch once, cache, refetch on pull-to-refresh or month change, not on every rebuild.
- The month shown defaults to the current month; if useful, reuse the same month-switcher component being built for the Monthly student report (`‹ August 2026 ›`) rather than building a second one — check if that's already implemented by this point and reuse it.

## 5. Explicitly out of scope for this pass

- Editing a teacher's profile details (name, contact) beyond what already exists
- Teacher self-service leave requests/approval workflow — this is admin-recorded absence only, same as today
- Leave types/categories (sick vs. personal vs. other) — just a total day count per month for now, unless the existing `teacher_absences` schema already has a reason/type field worth surfacing
- Notifications to teachers about being removed
- Any change to how teacher invitations themselves work — reuse as-is

## 6. Deliverable

Working Flutter code for:
1. "Manage Teachers" entry point on Settings (admin-only)
2. `TeacherManagementScreen`: teacher list with leave badges, overflow actions, FAB to invite
3. Disable-teacher flow (soft removal via `is_active`) with the student-reassignment safeguard described above, plus a re-enable path for disabled teachers
4. Teacher leave report data layer: `SettingsService` method + `AppProvider` state, aggregating `teacher_absences` by month
5. Relocated (not duplicated) absence-scheduling flow, now triggered from the per-teacher overflow menu instead of wherever it currently lives in Settings

Match existing codebase conventions: `const` constructors, `Consumer<AppProvider>`/`context.watch` in build, `context.read` in callbacks, no code generation, dual snake_case/camelCase handling on any model touched, services called from the provider (never Supabase directly from a screen).
