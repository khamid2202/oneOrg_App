# File Structure (Target)

Status: **proposal** — documentation only. No code has been moved as a result of
this file. When/if we migrate, update this doc and add a `CHANGELOG.md` entry.

This is a Flutter staff app (teacher-first) — 32 Dart files, ~11,400 lines under
`lib/`, talking to the same backend as the React staff web app. The `docs/staff/`
API references in this folder are shared with that app on purpose: one backend,
one set of endpoint docs. This file and `CHANGELOG.md` are **this** app's alone.

The bones are good — features are co-located, repositories are abstract with
`Http…` implementations behind them, and no widget touches `http` directly — but
a few inconsistencies make the project harder to navigate than it needs to be.

---

## Problems in the current structure

| Issue | Where | Why it hurts |
|---|---|---|
| **Mixed folder casing** | `features/MyClass/` `MyLessons/` `TimeTable/` `Profile/` `BottomBar/` (Pascal) vs `auth/` `landing/` | Dart style is `lowercase_with_underscores` for directories; with no rule to follow, import paths are guesswork |
| **One PascalCase file** | `features/TimeTable/TimeTable.dart` | Every other file is `snake_case.dart`; `flutter_lints` won't catch it, readers will trip on it |
| **Layering applied to one feature only** | `auth/` has `application/ data/ domain/ presentation/`; `MyClass` `MyLessons` `TimeTable` `Profile` are flat | Two conventions in one tree; unclear where a new file goes |
| **God repository** | `LessonPointsRepository` — 682-line interface, 830-line `Http` impl — owns points **and** students, groups, academic years, guardians, documents, contacts, person details, person pictures | Named for one domain, serves six. Any change to guardians recompiles and re-tests the points path; `MyClass` depends on it for everything and has no repository of its own |
| **Same operation, two homes** | `AuthRepository.uploadProfilePicture` (the signed-in user) vs `LessonPointsRepository.uploadPersonPicture` (a student) | Identical upload/crop/clear flow, two interfaces, two sets of tests |
| **Very large widget files** | `profilepage.dart` 1023, `student_info_view.dart` 877, `TimeTable.dart` 580, `my_class.dart` 574, `documents_tab.dart` 547, `guardians_tab.dart` 538 | Layout, local state, validation and formatting in one file; hard to review, harder to reuse |
| ~~**No theme layer**~~ | ~~Theme built inline in `app/app.dart`; features hardcode colors~~ | **Fixed 2026-08-13** — `app/theme.dart` owns the accent palette, dark flavors and the `AppColors` theme extension, driven by `app/theme_controller.dart`. Every screen reads colours through `appColorsOf(context)`; the only literals left are semantic (status green/amber/rose, destructive red, the dashboard's per-item category tints, the nav bar's glass gradient and shadows) |
| **`test/` doesn't mirror `lib/`** | 8 flat files (`my_class_test.dart`, `widget_test.dart`, …) | Fine at 8; won't scale, and there's no obvious home for a new feature's tests |

---

## Target structure

Feature-first, lowercase folders, one repository per domain. Keep it simple —
this is the right level of structure for the project; don't over-engineer. In
particular: **don't add a state-management package.** `ChangeNotifier` +
constructor injection from `app.dart` is working fine at this size.

```
lib/
├── main.dart
│
├── app/                        ← app-wide wiring
│   ├── app.dart                ← OneOrgStaffApp: DI graph + AuthGate
│   ├── theme.dart              ← NEW: ColorScheme/ThemeData out of app.dart
│   └── swipe_back_detector.dart
│
├── config/
│   └── api_config.dart         ← String.fromEnvironment (API_BASE_URL, …)
│
├── shared/                     ← cross-feature widgets
│   ├── editable_avatar.dart
│   └── underline_tabs.dart
│
└── features/                   ← one folder per domain, lowercase
    ├── auth/                   ← already the target shape; keep it
    │   ├── application/auth_controller.dart
    │   ├── data/               ← http_auth_repository, token_storage
    │   ├── domain/auth_repository.dart
    │   └── presentation/       ← auth_gate, login_page
    │
    ├── my_class/               ← was MyClass/
    │   ├── data/http_students_repository.dart
    │   ├── domain/students_repository.dart   ← NEW: split out of points
    │   └── presentation/       ← my_class, student_info_view,
    │                             guardians_tab, documents_tab,
    │                             document_viewer, student_row_card
    │
    ├── my_lessons/             ← was MyLessons/ — points only, once split
    ├── timetable/              ← was TimeTable/
    ├── profile/                ← was Profile/
    ├── landing/
    └── navigation/             ← was BottomBar/
```

`test/` mirrors it: `test/features/my_class/…`, `test/shared/…`.

---

## The two rules that fix most of the pain

1. **Split the god repository.** `LessonPointsRepository` should own points and
   nothing else. Students, groups and academic years move to a
   `StudentsRepository` under `my_class/`; guardians, documents, contacts and
   person details move to a `PersonRepository` beside it. Each gets its own
   `Http…` implementation and its own test file. The `MyClass` widgets then
   depend on the repository named for what they actually do — today they reach
   into `MyLessons` for guardians, which is why the dependency is easy to miss.

2. **One folder = one feature, lowercase, with `data/ domain/ presentation/`
   inside it.** `auth/` already looks like this and is the easiest feature in
   the app to navigate. Make it the only pattern rather than the exception.

---

## Current → target mapping

| Current | Target |
|---|---|
| `features/MyClass/` | `features/my_class/` |
| `features/MyLessons/` | `features/my_lessons/` |
| `features/TimeTable/` | `features/timetable/` |
| `features/TimeTable/TimeTable.dart` | `features/timetable/presentation/timetable_page.dart` |
| `features/Profile/` | `features/profile/` |
| `features/BottomBar/` | `features/navigation/` |
| `LessonPointsRepository` (students, groups, years, guardians, documents, contacts, persons) | split → `StudentsRepository` + `PersonRepository` + a points-only `LessonPointsRepository` |
| `LessonPointsRepository.uploadPersonPicture` / `AuthRepository.uploadProfilePicture` | one shared avatar contract, two callers |
| `_buildTheme` inside `app/app.dart` | `app/theme.dart` |
| hardcoded `Color(0xFF…)` in feature widgets | `Theme.of(context).colorScheme` |
| flat `test/*.dart` | `test/features/<domain>/…` |

---

## Suggested migration order (lowest risk first)

1. **Cosmetic renames**: folder casing, `TimeTable.dart` → `timetable_page.dart`,
   `BottomBar/` → `navigation/`. Pure find-and-replace on imports — do this on
   its own commit so the diff stays readable.
2. ~~**Lift the theme** into `app/theme.dart`.~~ **DONE 2026-08-13** — see
   `app/theme.dart` (palette, `AppColors` extension, `appColorsOf`) and
   `app/theme_controller.dart` (persisted accent / mode / dark flavor, keyed to
   match the web's localStorage). All 18 feature files were migrated off
   hardcoded neutrals and brand blues in the same pass.
3. **Highest impact: split `LessonPointsRepository`.** Interface first, then the
   `Http` implementation, then move the matching tests out of the 503-line
   `http_lesson_points_repository_test.dart`. The public method signatures don't
   change, so the widgets only need their constructor arguments rewired in
   `app.dart`.
4. **Add `data/ domain/ presentation/`** inside each feature as it gets touched —
   no big-bang move.
5. **Break up the 800+ line widgets** opportunistically: `student_info_view.dart`
   and `profilepage.dart` both contain a form, a validator and a layout that
   want to be separate files.

Steps 1–2 are safe. Step 3 is the real work and the real payoff.

## Import convention

Already mostly followed — keep it. Use a `package:one_org_staff/…` import for
anything that crosses a top-level boundary (`package:one_org_staff/shared/…`,
`package:one_org_staff/features/auth/…`), and relative `./` imports only
**within** the same feature folder. `my_class.dart` is the model here: `package:`
for `shared/underline_tabs.dart` and the auth domain, relative for its own
siblings. This keeps moves cheap and paths readable.
