# Changelog

Newest first. Every notable change to **this Flutter app** gets an entry here
(see [README.md](README.md) for the convention).

> This file previously held the React staff web app's history — it was copied in
> wholesale along with the shared `docs/staff/` API references and never
> rewritten, so it described `.jsx` files that do not exist in this repo. It was
> replaced on 2026-08-14 with the Dart history below. The `docs/staff/` API docs
> are still shared with the web app on purpose: one backend, one set of endpoint
> docs. `CHANGELOG.md` and `STRUCTURE.md` are this app's alone.

---

## 2026-08-14 — Profile: tabs reuse the shared `UnderlineTabs`

The Profile page had its own tab control — a horizontally scrolling row of pill
chips — so it looked like a different component from the My Class student modal,
which already used the shared bar.

- `features/Profile/profilepage.dart` — the Profile / Password / Help / System
  tabs now build `UnderlineTabs<ProfileTab>`; deleted the page-local
  `_TabSelector` and `_TabChip` (~95 lines).
- Two side effects of the swap: the tabs divide the width evenly instead of
  scrolling, and the active tint comes from `colorScheme.primary`, so the bar
  follows the accent chosen in Settings. The old chips had hardcoded blues.

## 2026-08-14 — Point report: column chooser, saved filters, timetable subjects

Brought the report the rest of the way to the web's behaviour.

- `features/point_report/presentation/column_picker.dart` (new) — the
  three-dots chooser, next to the date-mode selector. Search box, `selected/total`
  count, checkbox per column, Select all / Clear all. Toggles apply live.
- `features/point_report/domain/point_report_repository.dart` — `PointReportColumn`
  and `PointReportColumns`: the option list (`no`, `id`, `name`, `pr-week`,
  `attendance` covering Late **and** Absent, `subject:<name>`, `total`), plus
  `reconcile`, which folds newly-available subjects into an existing choice.
- **`Ism/Familya` is hidden by default**, matching the web — these tables get
  shared with parents.
- `features/point_report/data/point_report_preferences.dart` (new) — class, date
  mode and column choice persist across visits via `shared_preferences`. The
  **hidden** columns are stored rather than the shown ones, so a subject added to
  next week's timetable appears by default instead of being silently missing.
- Columns now come from the class timetable, so a subject taught this week gets
  an (empty) column even before anyone scores a point in it. Subjects that have
  points but no timetable slot are unioned in, so data is never hidden; lessons
  for other classes are filtered out by `groupId`.
- The share button moved up beside the page title.
- **Fix:** the timetable fetch was guarded with `.catchError(...)`, whose callback
  is bound to the future's *static* type — against a `Future<Never>` it threw a
  `TypeError` instead of recovering, failing the whole report. Replaced with
  try/catch.

## 2026-08-14 — Point report: rendered as a table, exportable as an image

Replaced the expanding-row list with the web's actual grid, and made it
shareable so teachers can send it to parents.

- `features/point_report/presentation/point_report_table.dart` (new) —
  `No. | ID | Ism/Familya | Pr-week | Late | Absent | …one per subject… | Total`,
  fixed column widths, sortable by name or total (ties fall back to the other
  column). `Good` instead of a bare `0` for a clean attendance record; a blank —
  not `0` — where a student has no points in a subject.
- `features/point_report/presentation/point_report_page.dart` — captures the
  table to PNG at 3× and hands it to the OS share sheet (`share_plus`, added).
  Filename mirrors the web's, e.g. `point-report-10-a-aug-10-2026-aug-16-2026.png`.
- The `RepaintBoundary` sits **inside** the horizontal scroll view, wrapping the
  full-width table, so the capture contains every column rather than only what is
  on screen — an ancestor's clip does not apply to a boundary's own layer.
- The exported copy uses a pinned light palette and drops the sort arrows: a
  teacher on True Black would otherwise send parents a black-on-black table, and
  an arrow in a static image implies it can be re-sorted.
- **Fix:** header and body rows used `CrossAxisAlignment.stretch` inside an
  unbounded column, throwing `BoxConstraints forces an infinite height`. Wrapped
  each row in `IntrinsicHeight`.
- **Fix:** every cell rendered without gridlines. The border lived on a parent
  `DecoratedBox` and the fill on a child `Container`, so the child painted over
  the line. Both now live in one `BoxDecoration`, and cells carry only `right` +
  `bottom` borders (the table container supplies top/left) so neighbours share a
  single line instead of drawing 2px doubles — `border-collapse` by hand.

## 2026-08-14 — Point report (new feature)

Port of the web's `features/point-report`, opened from a dashboard row.

- `features/point_report/domain/point_report_repository.dart` (new) —
  `StudentPoint`, `DateRange` and `PointReport.aggregate`, as plain Dart so the
  arithmetic is testable without pumping a widget. Matches the web on: Mon–Sun
  weeks, homework/performance read as substrings of the free-text `reason`,
  uncategorised points counting toward a subject total but no bucket, attendance
  penalties (`lateness`/`absence`/`excused`) sitting outside any subject, and the
  previous-week comparison.
- `features/point_report/data/http_point_report_repository.dart` (new) —
  `GET /student-points`, paginated. Unlike the web, which pulls every point a
  group has ever had and filters in the browser, this sends `start_date`/`end_date`
  covering the previous week through the period end — one span serving both
  windows.
- `features/auth/application/auth_controller.dart` — `loadPointsForReport`.
- **Fix:** `FutureBuilder` subscribes a frame after the future is created, so a
  fast failure had no listener when it rejected and Flutter reported it as an
  *unhandled async error*. The future now claims its own error immediately.

## 2026-08-14 — Colleagues (new feature)

Port of the web's Colleagues page, with a bottom-navbar button.

- `features/colleagues/{domain,data,presentation}/` (new) — built in the shape
  `STRUCTURE.md` targets, with its **own** repository rather than being added to
  the already-overloaded `LessonPointsRepository`.
- Active staff only, sorted by name, grouped under A–Z headings; search across
  name, username, phone and email. Rows show the name only and expand in place to
  reveal the number and a Call button — no detail screen. The `tel:` target
  strips formatting, which dialers choke on.
- `features/landing/presentation/landing_page.dart` — Colleagues added to the
  navbar and the dashboard.

## 2026-08-14 — Navigation: dashboard rows, and a shorter navbar

- Dashboard items are full-width list rows (tinted icon square, title, chevron)
  instead of a 1-up/2-up tile grid.
- The Profile and Sign Out cards are gone; the header avatar opens the profile,
  and signing out lives on the profile page behind its confirmation.
- Tapping the header avatar opens the photo full size in a zoomable lightbox.
- Timetable came off the navbar; it, My Class and the point report open from
  dashboard rows. Navbar is now Home, Lessons, Colleagues, Profile.
- Tab indices are named constants (`_colleaguesTab`, `_profileTab`, …) rather
  than bare integers. They have been renumbered twice now, and a wrong number
  silently points a button at the wrong page.

## 2026-08-14 — Theme: selectable accent colour and dark flavours

The app had no theme layer — `ThemeData` was built inline in `app.dart` and
features hardcoded their colours, so nothing could be recoloured centrally.

- `app/theme.dart` (new) — the palette ported hex-for-hex from the web's
  `shared/theme/ThemeContext.jsx`: the same 8 accents and 3 dark flavours
  (Slate / Dark gray / True black). `buildAppTheme()` seeds the `ColorScheme`
  from the accent and pins `primary` to the exact colour; an `AppColors` theme
  extension carries what `ColorScheme` has no slot for (`softBg`, `softText`,
  `border`, `ring`, `gradient`, `card`, `line`, `mutedText`).
- `app/theme_controller.dart` (new) — persists to `shared_preferences` under the
  **same keys** as the web (`system_accent`, `system_theme_mode`,
  `system_dark_variant`). Preferences survive sign-out; they are a device
  setting, and the login screen snapping back to purple reads as a bug.
- `features/Profile/profilepage.dart` — the System tab gained the accent swatch
  row with a live preview strip, and dark-flavour cards drawn as miniatures of
  the app in that shade. Picking a flavour does **not** turn dark mode on, as on
  the web.
- **All 18 feature files migrated** off hardcoded neutrals and brand blues onto
  `appColorsOf(context)` — 122 call sites. Remaining literals are semantic
  (status green/amber/rose, destructive red, the dashboard's category tints, the
  nav bar's glass gradient and shadows).
- **Fix:** the first pass read the extension with `Theme.of(context).extension<AppColors>()!`,
  which throws under a bare `MaterialApp` or a `Theme` override in a dialog.
  `appColorsOf` falls back to the default accent at the ambient brightness.

## 2026-08-14 — Fixes: swipe-back, avatar persistence, sign-out confirmation

- `app/swipe_back_detector.dart`, `features/MyClass/my_class.dart` — a left-edge
  swipe went to the dashboard from anywhere instead of back one page. My Class's
  detector sat inside `Padding(fromLTRB(20, …))`, so a drag starting at the real
  screen edge never reached it and the landing shell's detector took every one.
  The recognizer now lives in an edge strip pinned to `left: 0`, and the page
  padding moved inside the detector, so nested detectors resolve innermost-first.
  Also dropped a `globalPosition` check that would have broken the swipe entirely
  on tablets, where the centred page starts well past `edgeWidth`.
- `features/auth/domain/auth_repository.dart` — an uploaded profile photo showed
  once and then vanished. `AppUserProfile.fromJson` looked for `avatar`/`photo`/
  `image` but never **`picture_url`**, which is what the API returns
  (`docs/staff/users.md`), so the next `/users/me` load blanked it. The upload
  itself was always working.
- `features/landing/presentation/landing_page.dart` — the Profile page's Sign out
  button was wired straight to `controller.signOut`; it now goes through the same
  confirmation dialog the dashboard card had.

## 2026-08-14 — Docs: `STRUCTURE.md` rewritten for Flutter

`STRUCTURE.md` was the React app's, opening "This is a React + Vite role-based
app" and proposing renames for `Hooks/` and `UseContext.jsx`. Replaced with the
Dart structure, its real problems (mixed folder casing, `TimeTable.dart` as the
lone PascalCase file, layering applied only to `auth/`, and
`LessonPointsRepository` as a 682-line god repository owning students, groups,
academic years, guardians, documents, contacts and person pictures alongside
points) and a migration order.

---

## 2026-08-13 — My Class: student profile modal, avatars, shared tabs

Committed as `2ace396`. 92 files.

- `features/MyClass/` — `student_info_view.dart`, `guardians_tab.dart`,
  `documents_tab.dart` and `document_viewer.dart` (new): the student modal with
  Profile / Guardians / Documents tabs. `student_people_sync.dart` (new) keeps
  guardians and contacts in step. Replaced `contact_form.dart` and
  `student_detail_view.dart`.
- `features/Profile/avatar_cropper.dart`, `shared/editable_avatar.dart` (new) —
  profile picture upload with cropping.
- `shared/underline_tabs.dart` (new) — the tab bar the student modal uses.
- `test/` — `my_class_test.dart`, `avatar_cropper_test.dart`,
  `profile_picture_test.dart`, `student_people_sync_test.dart`,
  `underline_tabs_test.dart`.

## 2026-08-10 — Repository import

Committed as `a02887a`. 214 files, ~17k lines: the app as it then stood (auth,
landing, My Class, My Lessons, Timetable, Profile, bottom bar) plus the Windows
runner. The code predates this commit; it was not under version control before.
