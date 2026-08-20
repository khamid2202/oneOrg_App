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

## 2026-08-20 — Notifications: fix the prompt being spent before it could be shown

Reported as "no notification when the app is closed". The immediate cause was
that neither Firebase config file was in the build, so push had never been on
at all — but chasing it turned up two things in the code that would have kept
it off even after the config landed.

- `features/notifications/presentation/notification_permission_sheet.dart` —
  the gate marked the once-per-install prompt as *seen* whenever it had nothing
  to ask, and `PushPermission.unavailable` counted as nothing to ask. So every
  run without `google-services.json` quietly burned the flag; dropping the
  config in afterwards would find the prompt already spent, and short of
  reinstalling there was no way to reach the OS dialog. `unavailable` now
  returns without persisting anything. Regression test asserts `promptSeen`
  stays false in that state.
- The decline snackbar pointed at a Profile control that was never built. The
  real way back is the banner at the top of the inbox, so it says that now.
- `features/notifications/application/push_service.dart` — added
  `handleBackgroundMessage`, registered via
  `FirebaseMessaging.onBackgroundMessage`. Previously listed as a known gap on
  the reasoning that `POST /notifications/send` produces alert pushes, which
  the OS draws itself. That holds, and the handler returns immediately for any
  message carrying a `notification` block rather than drawing a second copy —
  but if the backend ever sends **data-only**, the old code showed nothing at
  all with the app closed, which is precisely the reported symptom. Now those
  get drawn from `data['title']`/`data['body']`. Everything in the handler is
  wrapped: an uncaught error on a background isolate is a crash with no app on
  screen to explain it.
- Foreground and background paths now share `PushService._androidDetails`, so a
  push looks the same however it was drawn.
- `PushService.debugSetPermission` (`@visibleForTesting`) — the permission
  branches otherwise need a real Firebase app and a real OS answer behind them.
- `docs/PUSH_SETUP.md` — new "If nothing arrives with the app closed" section,
  ordered by what actually catches people: missing config, then no registered
  device (`devices_targeted: 0` from `/notifications/send` proves it), then
  APNs, then OEM battery management, then force-stop.
- `test/notifications_test.dart` — 25 cases now. Also mocks `SharedPreferences`
  globally: without a mock store the real plugin call never completes and the
  tests that touch the prompt flag hang for ten minutes instead of failing.

## 2026-08-20 — Notifications: an inbox, push, and an ask before the OS prompt

The app had no notifications at all — no dependency, no permission handling,
nothing — while the backend has had a full notifications API the whole time
(`docs/staff/notifications.md`, newly mirrored into this repo) and the React
staff web app has been reading it since August. This closes that gap and adds
the piece the web app skipped: real push.

- `features/notifications/domain/notifications_repository.dart` — new.
  `AppNotification`, `NotificationPage`, and the repository interface covering
  the six inbox endpoints plus the two device-token calls.
- `features/notifications/data/http_notifications_repository.dart` — new. Same
  shape as the other `Http…` repositories: tolerates a `data` wrapper, lifts
  the server's `message` into an `AuthFailure`.
- `features/notifications/application/notifications_controller.dart` — new.
  Badge and list state. There is no realtime transport on this API, so the
  unread count is polled every 60s; the timer only runs in the foreground and
  an `AppLifecycleListener` refreshes on resume, so a backgrounded app costs
  nothing. Mark-as-read is optimistic, with the next poll as the fallback.
- `features/notifications/application/push_service.dart` — new. Firebase init,
  the permission request, FCM token registration against
  `POST /notifications/device-token`, token-refresh re-registration, and a
  local notification for pushes that land while the app is open (Android draws
  nothing for those; iOS does it itself via the foreground presentation
  options). Unregisters the device on sign-out, through a new
  `AuthController.onBeforeSignOut` hook — the DELETE needs the session token,
  which `signOut` was clearing first.
- **Every step degrades rather than throws.** With no `google-services.json` /
  `GoogleService-Info.plist` in the build, `Firebase.initializeApp` fails, the
  service settles on `PushPermission.unavailable`, and the REST inbox carries
  on unaffected. `flutter build apk --debug` passes today, with no Firebase
  project wired up.
- `features/notifications/presentation/notification_permission_sheet.dart` —
  new. The app asks in its own words before the OS dialog appears. The iOS
  prompt is a one-shot — decline it and only a trip to Settings undoes that —
  so firing it cold at launch spends the single chance on someone who has no
  idea what they are agreeing to. The sheet lists what the notifications are
  for, and only then calls `requestPermission()`. Shown once per install
  (persisted in `SharedPreferences`), after sign-in rather than before, and
  deliberately not dismissible by tapping away: a stray tap would otherwise
  count as a decline for good.
- `features/notifications/presentation/notifications_page.dart` — new. The
  inbox: paginated list, pull-to-refresh, mark-all-read, and a banner offering
  to turn push on for anyone who declined. It scrolls itself, like Colleagues
  and Rewards.
- `features/notifications/presentation/notification_bell.dart` — new. Bell with
  the unread badge, in the dashboard header beside the theme toggle. Tapping it
  opens the inbox as tab 9; a tapped push opens it too, including from a cold
  start, which the shell collects through
  `PushService.consumeOpenInboxRequest()` once it mounts.
- Native config: `POST_NOTIFICATIONS` and the default FCM channel id in
  `AndroidManifest.xml`, core-library desugaring for
  `flutter_local_notifications`, and the Google Services Gradle plugin applied
  **only when `google-services.json` exists** — it hard-fails the build
  otherwise — mirroring how the release signing config falls back to debug with
  no keystore. On iOS: `remote-notification` background mode, a
  `Runner.entitlements` ready for the Push Notifications capability, and the
  deployment target raised 13.0 → 15.0, which `firebase_core` 4.x requires.
  **This drops iOS 13 and 14.**
- `docs/PUSH_SETUP.md` — new. The Firebase-side steps that cannot be done from
  the repo. Push stays dark until those are done; the inbox does not.
- Tests: `test/notifications_test.dart`, 21 cases across the repository (URL
  and body shapes for all eight endpoints), the controller (optimistic
  updates, badge arithmetic, error text), the bell, the inbox, and the
  permission sheet.

## 2026-08-20 — Dashboard: the grey wash around every card is gone

In light mode each Quick Access card had a soft grey band hugging its edges,
worst along the left and bottom, which made the cards read as smudged rather
than as clean white cards on a tinted page.

- `features/landing/presentation/landing_page.dart` — `_DashboardListTile`
  painted its background, border and `boxShadow` from an `Ink` *inside* a
  `Material`. A `Material` clips its ink layer to its own bounds
  (`_RenderInkFeatures.paint` does `canvas.clipRect(Offset.zero & size)`), and
  that layer is where `Ink` draws. So the drop shadow could not reach outside
  the card: the outer half of the blur was clipped away and the inner half
  stayed, painted under a fill that is 90% opaque and therefore shows it
  through. A shadow meant to fall *outside* the card was being drawn *inside*
  it.
- The decoration moved onto the enclosing `AnimatedContainer`, which is an
  ordinary `DecoratedBox` and is not clipped; `Material` + `InkWell` stay for
  the ripple, with the padding they used to get from `Ink`. Side benefit: the
  border colour now animates with the press state, which it could not do on a
  plain `Ink`.
- How it was pinned down: the shadow was temporarily recoloured opaque red and
  the dashboard rendered in a browser preview. The whole card went pink —
  proving the shadow was being painted under the fill — and the red stopped
  dead at the card's bounds instead of blurring past them, proving the clip.
- Worth knowing for next time: `flutter test`'s renderer does not draw
  `BoxShadow` blur at all. A 40%-black shadow with `blurRadius: 12` sampled
  clean background one pixel outside the box. Shadow and blur work has to be
  checked on a real engine; widget tests will happily show nothing wrong.
- No other `Ink` in the app carries a `boxShadow`, so this was the only
  instance.

## 2026-08-20 — Landing: the page you leave no longer bleeds through the dashboard

Swiping back to the dashboard showed the page being left over the top of it for
a moment before settling, as if it had reloaded behind the transition. Only the
dashboard did it noticeably.

- `features/landing/presentation/landing_page.dart` — the shell's
  `AnimatedSwitcher` cross-faded the outgoing page over 220ms, stacked
  underneath the incoming one. Tabs paint no background of their own — the
  gradient behind them belongs to the shell — so for those 220ms the old page
  was *visible through* the new one. Fixed with a constant
  `reverseDuration: Duration.zero`, which drops the outgoing page at once.
- Why the existing `_returningViaSwipe` guard did not already cover this:
  `AnimatedSwitcher` hands an entry its durations when the entry is created and
  never revisits them (`_addEntryForNewChild`; `didUpdateWidget` only
  propagates a changed `transitionBuilder`). The conditional `duration` was in
  force when the *incoming* page was built, so it only ever shortened the fade
  in — the outgoing page still left on the 220ms it was created with. Hence a
  constant rather than another conditional.
- Why the dashboard specifically: going home, the ghost is a dense page showing
  through a sparse one. Going the other way it is a sparse dashboard showing
  through a dense page, which is much harder to see.
- Regression test: `test/landing_swap_test.dart` walks the real shell through
  the gesture and fails on any frame where the outgoing page is painted back at
  rest while the dashboard is up. The frames it records draw the distinction
  that matters — both pages on screen *while the swipe plays out* is the
  gesture working, and is allowed.

## 2026-08-20 — Landing: header keeps its name across a remount

Found while chasing the bleed-through above, and a real defect on its own,
though not the one that was reported.

- `features/landing/presentation/landing_page.dart` — the header's
  `FutureBuilder` always opens a fresh subscription in the waiting state, even
  on a future that completed long ago, so every remount painted one frame of
  "Staff Member" and a placeholder avatar before the real name arrived. Going
  back home remounts the dashboard twice — once as the page revealed under the
  drag, once as the page the shell swaps in — so it blinked twice.
- The resolved profile is now kept in `_profile` and passed as `initialData`,
  so a remount paints the real name on its first frame.
- Regression test: `test/landing_swipe_back_test.dart`.
- Ruled out along the way: the swipe detector zeroing its controller right
  after `onSwipeBack`. In isolation the reset lands in the same build as the
  caller's `setState` and never paints — a frame-by-frame test showed no
  difference, so `swipe_back_detector.dart` was left alone. What made the
  outgoing page linger was the switcher holding it, above.

## 2026-08-19 — Rewards: award and deduct points in bulk

Ported the web's `features/rewards` ("Points Studio") page. Same job — find
students, select any number, apply one amount to all of them — with a layout
built for a phone rather than the web's two-column directory-beside-a-panel,
which collapses into one very long scroll at mobile width.

- `features/rewards/presentation/rewards_page.dart` — new. The directory owns
  the screen; the award controls live in a bottom sheet raised by a selection
  bar, so picking students and setting an amount are two separate full-width
  steps. Title and filters scroll away with the list instead of being pinned,
  which is what left room for four students at a time in the first draft.
- The sheet keeps the web's quick-amount presets (+1, +5, +10, −5) and adds a
  −/+ stepper, a date picker, a reason field, a live "Adding 5 pts × 2
  students" summary, and a CTA tinted green or red by the sign.
- `MyLessons/lesson_points_repository.dart` — `StudentEntry` now carries
  `groupId` and `classPair`, read from `group_id` / the attached `group`. A
  school-wide search has no single group to fall back on and a point row must
  be filed against one.
- Two new repository methods: `getAllStudents` pages through `/students`
  (`limit` caps at 100, so a local name filter would otherwise miss anyone past
  page one), and `getPointTotalsByStudent` reads
  `/student-points/statistics/by-student` for the balances shown on each row.
  Both take an optional `groupId`: one class, or the whole school.
- Rosters are cached per scope, so extra keystrokes filter in memory. Nothing is
  fetched until a class is chosen or a name is typed, matching the web.
- Wired into the home dashboard as its own tab; like Colleagues it owns its
  scrolling.

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
