# Changelog

Newest first. Every notable change to the codebase gets an entry here
(see [README.md](README.md) for the convention).

## 2026-07-04 — Groups: show associated invoice templates on class cards

Each class card on the Classes page now lists its associated invoice templates
(`code` + `amount`) from the group's `invoice_templates` array (see
docs/staff/groups.md), or "None" when there are none.

- `features/groups/Classes.jsx` — added an "Invoice templates" section (pinned to
  the card bottom) with a `formatAmount` helper (`toLocaleString`). Also made the
  student count / stats fall back to the doc's `persons` field
  (`g.students ?? g.persons ?? 0`).

## 2026-07-04 — Groups: create modal on the Classes page (per docs/staff/groups.md)

Added group creation to the previously read-only Classes page
(`/management/classes`). The backend API is create + read only, so no
edit/delete — those are deferred until the API adds `PATCH`/`DELETE /groups/:id`.

- `features/groups/hooks/useGroups.js` — `createGroup` (`POST /groups`,
  toast + boolean) plus the create form's reference data: academic years
  (reuses `useAcademicYears`), active invoice templates (reuses
  `useInvoiceTemplates`), and active `teacher`-role users (from `/users`).
- `features/groups/components/GroupFormModal.jsx` — create-only modal
  (roles-style). Sends `{ academic_year_id, grade, class, teacher_id }` plus
  optional `name` and `invoice_template_ids`. Validates grade 1–12 and class as
  a single A–Z letter (uppercased) before the request.
- `features/groups/Classes.jsx` — "New Group" header button + modal; refetches
  the shared `classes` list via `fetchClasses` on success.
- No endpoint changes — `GROUPS` (`/groups`) already existed and serves both
  list and create.

## 2026-07-04 — Groups: academic-year filter on the Classes page

The Classes page was hardcoded to academic year 1. Added a year dropdown so the
group list can be scoped to any academic year.

- `features/groups/hooks/useClassesData.js` — holds an `academicYearId` state
  (default 1), passed as `?academic_year_id=` to `GET /groups`; refetches when
  it changes. Exposes `academicYearId` / `setAcademicYearId` (replaces the
  hardcoded `GET_CLASSES` endpoint usage with `GROUPS` + params).
- `features/groups/Classes.jsx` — academic-year filter in the filter bar
  (options from `useAcademicYears`); the create modal defaults its year to the
  currently-viewed one.

## 2026-07-04 — Groups: bubble dropdowns + single invoice template

- All group selects now use the shared bubble components: `BubbleDropDown` for
  single choices (academic-year filter, and year/teacher/grade/invoice-template
  in the create modal), `BubbleMultiSelect` for the class filter.
- A group's invoice template is now a **single** selection (was multi); still
  sent to the API as a one-element `invoice_template_ids`.
- `BubbleDropDown` gained an opt-in `usePortal` prop: it renders the menu in a
  `document.body` portal with fixed positioning (glued to the trigger on
  scroll/resize, flips up when short on space below) so the menu floats above
  `overflow` containers instead of being clipped. The group create modal's
  dropdowns enable it. Existing (non-portal) usages are unchanged.

## 2026-07-01 — Rebuilt invoices as a simple CRUD (per docs/admin/invoices.md)

New `features/invoices/` — a card-style CRUD matching the (new, simpler)
invoices doc; unrelated to the old billing-code invoices feature deleted earlier.

- `hooks/useInvoices.js` — list / create / update / delete against
  `/students/invoices` (+ `/:id`); defensive response unwrapping.
- `invoiceConstants.js` — months, the doc's status enum, and status→color styles.
- `components/InvoiceCard.jsx` — card: month/year, status badge, subtotal /
  discount / total, billing id, Edit/Delete.
- `components/InvoiceFormModal.jsx` — create sends `{ academic_year_id, year,
  month }`; edit adds `billing_id`, `subtotal_required_amount`,
  `discount_percent` (0–100), `total_required_amount`, `status`. Validates
  year 2000–2100, month 1–12, discount 0–100. Scrollable body uses
  `scrollbar-thin-custom` on a white bg so the scrollbar is visible.
- `Invoices.jsx` — page: card grid + `SearchArea` (filters by month/year/status/id)
  + create button + modals.
- Endpoints added: `INVOICES` (`/students/invoices`), `INVOICE_BY_ID`.
- Re-added the admin route `/management/invoices` and the "Invoices" Tools tile.
- `npm run build` + `eslint` pass clean.
- ⚠️ Path note: the doc says `/students/invoices`, but the rest of `endpoints.js`
  is mid-rename to `/persons/...`. I followed the doc (`/students`); reconcile
  with the rename if the backend actually serves `/persons/invoices`.

## 2026-07-01 — New invoices CRUD feature (card style)

Rebuilt `features/invoices/` from scratch against `docs/staff/invoices.md`
(base `/students/invoices`), replacing the deleted billing-code page.

- `hooks/useInvoices.js` — list (with year/month/status filters), create
  (`POST /students/invoices` `{ academic_year_id, year, month }`), update
  (`PATCH /students/invoices/:id`), delete (`DELETE /students/invoices/:id`);
  also loads academic years for the create form. Exports `INVOICE_STATUSES`,
  `MONTHS`, `monthLabel`. Uses the `INVOICES` / `INVOICE_BY_ID` endpoints.
- `components/InvoiceCard.jsx` — card style: month/year, colored status badge,
  required/paid/remaining amounts, discount, Edit/Delete.
- `components/InvoiceFormModal.jsx` — create (academic year, year, month) vs edit
  (adds billing_id, subtotal, discount %, total, status); validates year
  2000–2100, month 1–12, discount 0–100.
- `Invoices.jsx` — header + New Invoice, year/month/status filter bar, responsive
  card grid, modal.
- Scrollable modal body uses `scrollbar-thin-custom` (transparent track).
- Route (`/management/invoices`) + management tile were already wired.
- `npm run build` + `eslint` pass clean.

## 2026-07-03 — Replaced the invoices page with Invoice Templates CRUD

The Tools "Invoice templates" tile pointed at an invoices CRUD, which was wrong —
that page should manage **invoice templates** (docs/staff/invoice-templates.md,
formerly *billings*), not invoices.

- Deleted `features/invoices/` (the invoices CRUD).
- New `features/invoice-templates/` — card-style CRUD: list with search + filters
  (category, active), create/edit/delete, and inline active toggle. Fields per
  doc: `code` (1–20), `description` (1–300), `amount` (0–1,000,000), `category`
  (1–50), `is_active`. Category input offers a datalist of existing categories.
  Delete surfaces the "still referenced by enrollments" case with a hint to
  deactivate instead.
- Endpoints added: `INVOICE_TEMPLATES` (`/invoice-templates`),
  `INVOICE_TEMPLATE_BY_ID` (`/invoice-templates/:id`).
- Route → `/management/invoice-templates`; the Tools tile now points there.
- The Invoices statistics section (Statistics page) is unaffected — it reads
  `/invoices/statistics` independently.
- `npm run build` + `eslint` pass clean.

## 2026-07-03 — Statistics: added Invoices section

- New `statistics/sections/InvoicesStats.jsx` registered in the Statistics hub.
  Summary cards (invoices count, total required, total paid, outstanding) from
  `GET /invoices/statistics`, plus a per-status breakdown (count bars + amounts)
  from `GET /invoices/statistics/by-status`. Added `INVOICE_STATISTICS_BY_STATUS`
  endpoint.
- `npm run build` + `eslint` pass clean.

## 2026-07-03 — Rebuilt the invoices feature against the new /invoices API

Filled in the user-scaffolded `features/invoices/` (empty files + route/tile
already wired to `/management/invoices`) per the new `docs/staff/invoices.md`.

- Endpoints added: `INVOICES` (`/invoices`), `INVOICE_BY_ID` (`/invoices/:id`),
  `INVOICE_STATISTICS` (`/invoices/statistics`).
- `hooks/useInvoices.js` — filtered list (`GET /invoices`, reads
  `{ meta.total, invoices }`) + statistics summary fetched together; UI filters
  (academic year / year / month / status) sent as one-element arrays per
  InvoiceFilterDto; generate / update / delete with toasts + refetch.
- `Invoices.jsx` — card-style page: stats strip (count, total required, total
  paid, outstanding), filter bar, card grid, Generate button.
- `components/InvoiceCard.jsx` — student, period, template, subtotal / discount /
  required / paid, color-coded status chip, Edit/Delete.
- `components/InvoiceFormModal.jsx` — dual mode: **Generate** (`POST /invoices`
  with required academic year/year/month + optional grades and
  invoice_template_ids scoping; shows created/updated/skipped) and **Edit**
  (`PATCH /invoices/:id` — status, subtotal, discount %, total; blank total lets
  the backend auto-recalculate).
- `lib/constants.js` — shared MONTHS/STATUSES.
- Not implemented (doc supports, deferred): bulk PATCH/DELETE by filters, the
  by-status / trend / by-academic-year statistics breakdowns.
- `npm run build` + `eslint` pass clean.

## 2026-07-02 — Timetable Maker: explicit save + rename on edit

- Generating no longer auto-saves to history (which piled up duplicate,
  same-named entries). Added an explicit **Save to history** button.
- Editing a history entry now tracks it; saving an edited timetable **prompts for
  a new name** (defaulting to "<name> (edited)") and stores it as a distinct
  entry — the original is left untouched. The button reads "Save as new" while
  editing.
- Free slots store `-` (finished migrating off "Self-study").

## 2026-07-02 — Timetable Maker: naming, history, per-class lunch, hours-by-class, status

Follow-up upgrades to the Timetable Maker.

- **Name + session history**: step 1 asks for a timetable name; each generation is
  saved to `sessionStorage` (`hooks/useTimetableHistory.js`, kept until the tab
  session ends). New "History" step lists past runs with View / Export / Delete.
- **Hours by class + subject toggles** (`HoursStep`): for each teacher it now lists
  the classes they can enter (one row each); the teacher's subjects are toggle
  chips per class, and each selected subject gets its own hours input. Hours are
  keyed by `teacherId::classId::subject` (a teacher can teach several subjects to
  a class).
- **Per-class (staggered) lunch** (`ConfigStep`): a default "lunch after period"
  plus per-class overrides, so lower grades can break after 5 and others after 6.
  The scheduler now checks teacher clashes on **real start-minutes** (derived from
  lesson/lunch length) instead of period numbers, so staggered lunch stays
  conflict-free; the grid/export render lunch per class on shared display rows.
- **Status panel** (`StatusPanel`): after generating, shows overall placed/total
  and a per-class breakdown of which subjects were placed and which didn't fit —
  replacing the previous toast-only feedback.
- `npm run build` + `eslint` pass clean.

## 2026-07-02 — Added Timetable Maker

New `features/timetable-maker/` — a wizard that generates a weekly class
timetable client-side and exports it to Excel.

- Data: `hooks/useTimetableMakerData.js` fetches teacher users (`GET /users`
  filtered to the `teacher` role), classes (`GET /groups`), and subjects
  (`GET /subjects`).
- Wizard steps: (1) pick teachers, (2) teacher×class eligibility matrix,
  (3) subjects per teacher, (4) weekly hours per teacher-subject, (5) timing
  (days, periods/day, lunch-after-period, lesson & lunch length).
- `lib/generateTimetable.js` — greedy scheduler: expands requirements into
  lesson units and places them so **a teacher is never double-booked** in the
  same day+period, spreading a subject across days; empty slots become
  "Self-study"; unplaceable lessons are reported.
- `components/TimetableGrid.jsx` — renders the day×class grid (subject +
  teacher, Lunch/Self-study), styled like the reference screenshot.
- `lib/exportTimetable.js` — exports to `.xlsx` via `xlsx-js-style` (styled
  headers, Lunch/Self-study fills).
- Wired an admin route `/management/timetable-maker` and a "Timetable Maker"
  tile in the management hub.
- `npm run build` + `eslint` pass clean.

Known limitations (MVP): scheduling is best-effort greedy (not an optimal
solver); lunch is a single global period (not staggered per class like the
screenshot); weekly hours are per teacher-subject applied to each eligible
class; result is client-side only (no backend save). Lesson/lunch minutes are
captured but the grid uses period numbers + a Lunch row.

## 2026-07-02 — Per-route scroll memory (fixes pages opening scrolled down)

The app scrolls inside a persistent `<main>` in `shared/layout/Layout.jsx` that
doesn't remount between routes, so a new page inherited the previous page's
scroll offset (e.g. opening Statistics from the long Tools grid landed
scrolled down).

- `Layout.jsx` now tracks scroll position per `pathname` on `<main>` and restores
  it on navigation (`useLayoutEffect`, before paint — no flash); unseen routes
  start at top. Applies app-wide.

## 2026-07-02 — Added Statistics page (Users first)

New `features/statistics/` — a growing statistics hub on the Tools page.

- `Statistics.jsx` is a **section registry**: each feature contributes one
  `sections/<Feature>Stats.jsx` and registers it in the SECTIONS list — no other
  wiring needed for future statistics.
- First section: `sections/UsersStats.jsx`, backed by the live
  `GET /users/statistics` endpoint (not yet in users.md; returns
  `{ result: { total, active, inactive, with_email, with_telegram, with_group,
  without_group } }`). Added the `USER_STATISTICS` endpoint constant.
  - Headline cards: Total / Active / Inactive.
  - Clickable sub-section chips side by side — **By Role · With Email · With
    Groups · With Telegram** — each showing its breakdown as percentage bars.
    "By Role" is still derived from `GET /users` (the statistics endpoint has
    no per-role breakdown); the other three use the statistics counts vs total.
- `components/StatCard.jsx` — reusable numeric stat card (icon + label + value,
  accent variants) for all future sections.
- Wired an admin-only route `/management/statistics` and a "Statistics" tile
  (ChartLine icon) in the management hub.
- `npm run build` + `eslint` pass clean.

## 2026-07-01 — Added Academic Years CRUD

New `features/academic-years/` built against `docs/staff/academic-years.md`.

- Endpoint added: `ACADEMIC_YEAR_BY_ID` (`/academic-years/:id`); `ACADEMIC_YEARS`
  (`/academic-years`) already existed.
- `hooks/useAcademicYears.js` — list (reads `{ ok, result }`) + create/update/
  delete (toast + refetch).
- Card-style UI: `AcademicYearCard` (name, date range, Active badge, edit/delete)
  and `AcademicYearFormModal` (name 3–100, start/end dates, is_active; validates
  start ≤ end). Modal body uses `scrollbar-thin-custom`.
- Wired an admin-only route `/management/academic-years` and an "Academic Years"
  tile in the management hub (`AdminTools.jsx`).
- `npm run build` + `eslint` pass clean.

## 2026-07-01 — Stripped billings from dependent features; deleted invoices

Follow-up to the billings removal — removed the leftover billing dependencies in
the features that consumed the (now-gone) `billings` catalog.

- **Dormitory** (`Dormitory.jsx`): removed `billings`, `dormBillings`,
  `dorm700BillingId`, the `isDormBilling` import, and the `billing_id` from room
  creation (rooms no longer require a dorm billing code).
- **Discounts** (`Discounts.jsx`): removed the required `billing_id` field
  (dropdown, validation, payload), the `billingOptions/billingById/billingByCode`
  maps, the auto-select-billing logic, and the "Billing" table column. Discounts
  are now created without a billing target.
- **Invoices**: deleted `features/invoices/` entirely — the feature was 100%
  billing-code-driven, so there was nothing left without billings. Removed its
  route (`/management/invoices-2.0`) and the "Invoices" management tile.
  - `endpoints.js` left as-is: `UPDATE_INVOICE` is still used by
    `payments/TableModules/InvoiceModule.jsx`; the other invoice endpoint
    constants are now unused but harmless (and endpoints.js is mid-edit).
- Cleaned up `paymentUtils.jsx`: dropped the now-unused `notifyBillingUpdate` /
  `notifyInvoiceCreated` (only the deleted invoices page used them); it now holds
  just `normalizeDiscounts` / `normalizeInvoices` (used by payments).
- `npm run build` passes after each step.

## 2026-07-01 — Removed the billings feature (whole project)

Removed billings end to end (billing definitions catalog + management UI).

- Deleted `features/billing/` (page, components, `useBillings.js`, and the global
  `useBillingsData.jsx` hook).
- Unwired from the DataProvider (`Hooks/UseContext.jsx`): dropped the
  `useBillingsData` import, the hook call, and the `...billings` spread/deps — so
  the `billings` context key no longer exists.
- Removed the route (`/management/billings`) and the "Billings" management tile
  (`AdminTools.jsx`), plus the unused `BadgeDollarSign` icon.
- Removed billing endpoints: `GET_BILLINGS`, `GET_BILLING_BY_ID`,
  `CREATE_BILLING`, `UPDATE_BILLING`, `DELETE_BILLING`, `BILLING_CODES`.
- **Preserved (relocated) the non-billing display helpers** that lived in the
  billing hook — `normalizeDiscounts`, `normalizeInvoices`, `notifyInvoiceCreated`,
  `notifyBillingUpdate` — into `features/payments/paymentUtils.jsx`, and pointed
  `payments/TableRow`, `payments/PaymentsPage`, and `invoices/New_Invoices_Page`
  at them. These format a student's own discounts/invoices and show toasts; they
  are not billing definitions, and removing them would have broken the payments
  table and invoice flow.
- Consumers of the old `billings` catalog key (`invoices/New_Invoices_Page`,
  `discounts/Discounts`, `dormitory/Dormitory`) already destructure with
  `billings = []`, so they now default to empty and don't crash — their
  billing-driven selectors just render empty.
- `npm run build` + `eslint` (touched files) pass.

Remaining / notes:
- `features/tools/Tools.jsx` still has commented-out `BILLING_CODES` references
  (inert dead comments).
- `docs/admin/billings.md` (backend API reference) left in place.

## 2026-06-28 — User form: dropped permissions, roles suggested from /roles

Rewrote `features/users/components/UserFormModal.jsx` (simpler, no change in
endpoints):

- Removed the permissions picker entirely — permissions are now managed on roles
  (Roles page), not per user. The form no longer sends `permissions`.
- The Roles field now suggests from the live role list (`GET /roles`, role
  `name`s) instead of a hardcoded list; free-text add still allowed.
- Kept create (`POST /users/create`) / edit (`PATCH /users/update/:id`),
  `phone` payload key, `max-w-lg` size, and the same validation.
- `ViewUserModal` still displays a user's permissions read-only (unchanged).
- `npm run build` + `eslint` pass clean.
- Note: users.md's CreateUserDto lists `role` (singular) while the form sends a
  `roles` array (matching the user object + UpdateUserDto); adjust if the live
  create endpoint rejects `roles`.

## 2026-06-28 — Added roles management feature

New `features/roles/` built against `docs/admin/roles.md`.

- Endpoints added: `ROLES` (`/roles`), `ROLE_BY_ID` (`/roles/:id`),
  `ROLE_PERMISSIONS` (`/roles/permissions`).
- `hooks/useRoles.js` — loads roles + the permission catalog, groups the catalog
  by `resource`, and exposes create/update/delete (each toasts + refetches).
- `components/RoleFormModal.jsx` — create/edit a role: `name` (create-only,
  validated lowercase/numbers/underscores), `label`, and a permission picker
  (checkboxes grouped by resource with per-resource select-all). Create sends
  `{ name, label, permissionKeys }`; edit sends `{ label, permissionKeys }`.
  Shows a note that `admin` is a wildcard.
- `components/RoleCard.jsx` — role name/label, System badge, permission count,
  Edit/Delete (delete hidden for system roles).
- `Roles.jsx` — page: list + New Role button + modal.
- Wired an admin-only route `path="roles"` in `AdminRoutes.jsx` and a "Roles"
  tile in the management hub (`AdminTools.jsx`).
- `npm run build` + `eslint` pass clean. (Live `/roles` calls depend on the
  backend exposing them — same deploy caveat as other endpoints.)

## 2026-06-28 — Users page: Active/Blocked tabs + click-to-view cards

Reworked the Users page UX (kept the docs-aligned create/edit flow).

- Replaced the two stacked Active/Blocked sections with a single **tab toggle**
  at the top (Active | Blocked, each with a count); the selected tab decides
  which list shows. Search filters within the active tab.
- Simplified `UserCard` to **avatar spot + name + ID**; the whole card is now a
  button that opens the details modal on click (removed the inline View/Edit
  buttons).
- Details modal (`ViewUserModal`) shows the rest of the fields and has an **Edit**
  button → opens `UserFormModal` → saves via `/users/update/:id` (or
  `/users/create` for the + button) per docs/admin/users.md.
- Set both the details modal (`ViewUserModal`) and the form modal
  (`UserFormModal`) to `max-w-lg` so clicking Edit no longer changes the modal
  width (consistent size between view and edit).
- `npm run build` + `eslint` pass clean.

## 2026-06-28 — Added reusable SearchArea component

Promoted the Users page's `ExpandableSearch` into a shared, reusable component.

- New `shared/layout/Custom/SearchArea.jsx` — same behavior (collapsible
  circular search, ⌘K/Ctrl+K to expand+focus, Esc to clear+collapse, collapses
  on empty blur) plus reuse props: `className`, `expandedWidthClass`, and
  `shortcut` (set false when multiple instances share a page so they don't all
  grab ⌘K). Controlled via `value`/`onChange`; has PropTypes.
- `features/users/Users.jsx` now uses `SearchArea`; deleted the local
  `features/users/components/ExpandableSearch.jsx` (superseded).
- `npm run build` + `eslint` pass clean.

## 2026-06-28 — Grouped navigation into shared/navigation/

The navigation map (`NAV_ITEMS`) is the shared concept linking the landing page,
the navbar, and my-class — so co-located the navigation pieces (kept shared, not
moved into a feature, since `Navbar`/nav config are app-wide).

- `shared/utils/navigationConfig.jsx` → `shared/navigation/navigationConfig.jsx`
- `shared/layout/Navbar.jsx` → `shared/navigation/Navbar.jsx`
- `shared/utils/` removed (was empty afterward).
- Updated imports: LandingPage + my-class (`@/shared/navigation/navigationConfig`),
  Navbar (`./navigationConfig`), Layout (`@/shared/navigation/Navbar`).
- `Layout.jsx` stays in `shared/layout/` (it's the page frame, not navigation).
- Dropped a stray unused `import { id } from "date-fns/locale"` in the nav config.
- `npm run build` + `eslint` pass. (LandingPage stays in `features/landing/` — it
  is the only landing-specific file.)

## 2026-06-28 — Replaced MultiSelectDropdown with BubbleMultiSelect

Consolidated on one multi-select component.

- Added `singleSelect` support to `shared/layout/Custom/BubbleMultiSelect.jsx`
  (selecting sets a single value and closes; hides the Select-all/Clear bar) so
  it fully covers MultiSelectDropdown's feature set.
- Migrated both call sites (prop mapping `label`→`placeholder`,
  `selected`→`values`, option `key`→`value`, `align`→`menuAlign`):
  - `features/groups/Classes.jsx` (class filter; also fixed the options sort that
    referenced `.key`).
  - `features/timetable/TimetableFilters.jsx` (classes / teachers / days; the
    teacher filter keeps single-select in teacher mode via the new prop). All
    timetable values are already strings, so BubbleMultiSelect's string coercion
    is a no-op.
- Deleted `shared/layout/MultiSelectDropdown.jsx`.
- `npm run build` and `eslint` pass clean.

## 2026-06-28 — Removed unused shared/layout components

Audited `shared/layout/` usage. Removed two dead components (no importers
anywhere, self-contained):
- `shared/layout/ReusableFilter.jsx` (146 lines)
- `shared/layout/CustomDropdown.jsx` (169 lines)

Kept `shared/layout/Custom/CustomDatePickerRange.jsx` at the user's request
(still unused — no importers, candidate for future cleanup). `npm run build`
passes. All other layout components are in use (BackButton ×22, BubbleDropDown
×8, BubbleMultiSelect ×3, CustomDatePicker ×1, MultiSelectDropdown ×2, Layout,
Navbar).

## 2026-06-28 — Renamed teachers → users feature + reworked the Users page

Renamed the `teachers` feature to `users` and reworked the page per
`docs/admin/users.md`.

Renames (1):
- `features/teachers/` → `features/users/`
- `Teachers.jsx` → `Users.jsx` (component `Users`)
- `TeacherCard.jsx` → `components/UserCard.jsx` (prop `teacher` → `user`)
- `AddModule.jsx` → `components/UserFormModal.jsx` (`AddTeacherModal` →
  `UserFormModal`, prop `editingTeacher` → `editingUser`)
- `hooks/useTeachersData.js` → `hooks/useUsersData.js` (`useTeachersData` →
  `useUsersData`); updated the import + call in `Hooks/UseContext.jsx` and the
  lazy import/const in `AdminRoutes.jsx`.
- Extracted the details modal into `components/ViewUserModal.jsx` (fixed a stray
  literal "f" that rendered in the old header).
- Note: the global context keys stay `teachers`/`fetchTeachers`/etc. because the
  payments & invoices teacher filters consume them; the `/management/teachers`
  URL (nav label "Staff") is unchanged.

Page rework (2):
- a) Users are shown in two separate sections — **Active** and **Blocked**
  (`status === "active"` vs not) — each with a count badge.
- b) New `components/ExpandableSearch.jsx`: a circular search icon that expands
  into an input, with ⌘K/Ctrl+K to expand+focus and Esc to clear+collapse;
  filters locally by name/username (no longer hijacks the shared `searchTerm`).
- c) A circular **+** button to the right of the search opens the create-user
  modal (`UserFormModal`, which posts to `/users/create` and patches
  `/users/update/:id` per users.md).
- `npm run build` and `eslint` (users feature) pass clean.

## 2026-06-28 — Removed ClassManagement; groups is now the class list only

The groups feature is now just the class list + class stats (`Classes.jsx`).
The per-class roster/detail view (`ClassManagement`) was removed.

- Deleted `features/groups/ClassManagement.jsx`.
- Removed its lazy import and `<Route path="class-management">` from
  `AdminRoutes.jsx`.
- `Classes.jsx`: removed the per-card "View Class" navigation (and the
  `useNavigate` import, debug `onClick`), plus pre-existing dead code
  (`formatDate`, `gradeOptions`, `gradeColors`/`color`, unused `React` import);
  wrapped `groups` in `useMemo`. File is now lint-clean.
- `fetchStudentsForClassGroup` stays in `useClassesData` — still used by
  Point Report, Attendance Check, and My Class.
- `npm run build` passes.

## 2026-06-28 — Removed "Add Student" from the groups feature

Per groups.md, the Groups API has no create-group endpoint and no manual
add-student flow — groups (and their students) are created via Excel upload only
(`POST /groups/upload`, `POST /students/upload-v2` which auto-creates groups). So
the ad-hoc add-student UI in the class view didn't reflect the documented flow.

- Removed the "Add Student" button, its modal, the `showAddModal` state, and the
  now-unused `isTeacher`/`useAuth` wiring and empty-state hint from
  `features/groups/ClassManagement.jsx`. Also dropped a dead `Trash2` import.
- Deleted `features/groups/AddStudentModal.jsx`. This also removes the
  undocumented best-effort `DELETE /students/:id` rollback flagged in the
  endpoint audit (no such endpoint exists in students.md).
- `CREATE_STUDENT` and `ASSIGN_STUDENT_GROUP` endpoint constants are now unused
  (left in `endpoints.js` as they remain valid documented endpoints).
- `npm run build` passes. (Pre-existing `React`/`error` no-unused-vars lint in
  ClassManagement.jsx are unrelated and left as-is.)

## 2026-06-28 — Split the billing feature into components + hook

Refactor only — no behavior change. `features/billing/Billing.jsx` went from 790
to 244 lines (orchestration only):

- `components/BillingFilters.jsx` — search + category/status dropdowns
- `components/BillingList.jsx` — loading skeleton, empty state, card grid
- `components/BillingCard.jsx` — single billing card
- `components/BillingFormModal.jsx` — create/edit modal
- `components/CategoryInput.jsx` — free-text category combobox (was inline)
- `hooks/useBillings.js` — list + category/active filters + CRUD actions
  (create/update/delete/toggle), each with its own toast + refetch

Validation rules, API calls, filters, and styling are unchanged. Now matches the
`components/` + `hooks/` layout used across `features/`. Note: this `useBillings`
(page CRUD) is distinct from the existing `useBillingsData` (global billings +
invoice/discount helpers consumed by the `DataProvider`). `npm run build` and
`eslint` pass clean.

## 2026-06-28 — Audited all endpoints against `docs/admin/*`

Checked every `src/api/endpoints.js` path (and the 3 hardcoded `api.*` calls)
against the 13 admin docs + root `attendance`/`points`/`contacts` docs.

- **No path mismatches found.** All paths conform to the documented contracts.
  Apparent mismatches were false alarms: `UPDATE_USER` and `REMOVE_FROM_GROUP`
  are bare bases whose callers append `/:id` (→ `/users/update/:id`,
  `/students/:id`), matching users.md / students.md §5.
- `/billings` 404 and `/students` 400 are **deploy-pending** (live
  `dev-api.oneorg.uz` is behind the docs), not path errors — paths match.
- **Flagged, not changed:** `features/groups/AddStudentModal.jsx:137` does a
  best-effort `DELETE /students/:id` rollback, but the docs expose no student
  hard-delete endpoint (only `DELETE /students/remove-from-group`). Call is
  swallowed/harmless; left as-is pending a documented endpoint.
- Minor (not done): 3 calls hardcode paths instead of using `endpoints.js`
  constants (`PATCH /students/:id`, `DELETE /students/:id`,
  `GET /timetable/my-lessons`) — cosmetic, not a mismatch.

## 2026-06-28 — Realigned student fetching to the documented `/students` contract

Context: `docs/admin/students.md` is the agreed source of truth for the `/students`
query interface — `academic_year_id`, `id`, `limit`, `page`, `q`, the `include_*`
flags, `filter`, and `sort`. The earlier "strip everything" stopgap (2026-06-27,
see entry below) was reverted and the documented params restored.

> ⚠️ **Deploy pending.** As of this change the live API at
> `https://dev-api.oneorg.uz` (`VITE_API_BASE_URL`) is still running an **older**
> `/students` that rejects these params with `400` "property … should not exist".
> The frontend is intentionally aligned to the docs; `/students` calls will keep
> returning `400` until the updated backend is deployed, at which point they work
> with no further frontend change. (Decision: docs = source of truth.)

- `endpoints.js` — restored `include_*` / `filter` / `sort` on the student
  endpoints (`GET_STUDENTS_FOR_PAYMENTS`, `GET_DORM_/COURSE_STUDENTS_FOR_PAYMENTS`,
  `GET_STUDENTS_WITH_POINTS`, `GET_DORM_STUDENTS`, `GET_ALL_STUDENTS_FOR_INVOICES`,
  `GET_STUDENT_WITH_PAYMENTS`, `STUDENTS`, `STUDENTS_WITH_GROUPS`). Booleans use
  `=1` (the doc accepts `1`/`0` and `true`/`false`).
- `GET_STUDENTS_OF_A_CLASS` now carries `include_group=1` (and dropped the old
  trailing empty `&filter=`). The doc requires `include_group` whenever a
  `filter` is sent, so this also hardens the 5 call sites that append a class
  filter (exam-report, assessment, attendance-report, lessons, exam-grading)
  plus `scores/useStudentsForClass`.
- Hooks — restored the call-time params: `usePaymentsData` `{ page, q }` (×3),
  `useDormitoryData` `{ page }`, `useLeaderboardData` `{ q }`, and the
  `class_pairs` `filter` in `useClassesData` (Point Report's class lookup).
- Per doc rules verified: every endpoint sending `filter` or `include_payments`
  also sends `include_group`.
- `npm run build` passes.

### Stopgap that this reverts

## 2026-06-27 — (stopgap) Stripped rejected query params from `/students`

The pre-update backend had started returning `400 Bad Request`
("property include_group should not exist", then `page`, `sort`, `filter`) due to
strict whitelist validation, so all student pages showed "no student found".
As a temporary unblock, the `include_*`, `page`, `q`, `filter`, and `sort` params
were stripped from the student endpoints/hooks. **Superseded by the 2026-06-28
entry above** once the backend + docs were updated.

## 2026-06-26 — Flattened pages into `features/` + `@` alias (Stage 4)

The big one: removed the `Pages/admin` + `Pages/teacher` role layers and the
`ManagementPage` nesting; every domain now sits at `features/<name>/`
(domain-first, fully flat — chosen over role-first).

Enabling change — path alias:
- Added `@` → `src/` alias in `vite.config.js` (build) and `jsconfig.json`
  (editor). All cross-boundary imports now use `@/...` instead of fragile
  `../../../` chains, so future moves don't require depth recomputation. 170
  imports converted.

Moves (~150 files, 32 feature folders), e.g.:
- `Pages/admin/PaymentNew` → `features/payments`
- `Pages/admin/ManagementPage/Dormitory` → `features/dormitory`
- `Pages/admin/ManagementPage/{invoices,Billings,Teachers,Groups,…}` →
  `features/{invoices,billing,teachers,groups,…}`
- `Pages/admin/AttendanceCheck` → `features/attendance`;
  `…/ManagementPage/AttendanceReport` → `features/attendance-report`
- `Pages/teacher/{MyClass,LeaderBoard,Profile,Exams,Lessons,…}` →
  `features/{my-class,leaderboard,profile,exams,lessons,…}`
- `Pages/NotFound.jsx` → `app/NotFound.jsx`
- `ManagementPage/AdminTools.jsx` → `features/management/AdminTools.jsx`

Data hooks moved to their feature (second half of the stage):
- `Hooks/data/use{Payments,Classes,Billings,Timetable,Teachers,UserInfo,
  Leaderboard}Data` → `features/{payments,groups,billing,timetable,teachers,
  profile,leaderboard}/hooks/`. `Hooks/UseContext.jsx` (the composing
  DataProvider) now imports them via `@/features/.../hooks/...`.

Cleanups & fixes:
- Deleted two orphaned (unimported) files: `admin/Groups/Classes.jsx` and
  `teacher/Profile/Help.jsx`.
- Fixed two imports that only resolved on case-insensitive macOS (would break on
  Linux/CI): `groups/ClassManagement.jsx` `../Groups/AddStudentModal` →
  `./AddStudentModal`; `profile/{ProfilePage,MobileView}` `../Help/Help.jsx` →
  `@/features/help/Help.jsx`.
- Verified: `npm run build` passes (resolves all static + dynamic route
  imports); no `Pages/` references remain; eslint reports no alias-resolution
  errors (remaining lint findings are pre-existing content issues).
- Safety snapshot taken at `/tmp/schoolproject_src_backup_stage4` before the
  move (can be deleted now).

Remaining: `src/Hooks/UseContext.jsx` is the last PascalCase remnant — the global
DataProvider that composes the feature hooks. Splitting it into per-feature
providers (or relocating it to `app/`) is the final optional step.

## 2026-06-26 — Consolidated reusables into `shared/` (Stage 3)

Grouped cross-feature reusable code under a single `shared/` folder.

- `UI/` → `shared/components/` (buttons, inputs — currently unused; the
  pre-existing broken `./utils` import in `buttons.jsx` was left untouched).
- `Layouts/` → `shared/layout/` (Layout, Navbar, dropdowns, `Custom/`).
- `Hooks/useGlobalSearchShortcut.js` → `shared/hooks/`.
- `utils/` → `shared/utils/` (navigationConfig).

Import fixes:
- Consumers: segment swaps `Layouts/` → `shared/layout/`,
  `utils/navigationConfig` → `shared/utils/navigationConfig`, and the App.jsx
  hook path → `./shared/hooks/...`.
- Moved files that went one level deeper got `../` → `../../` for their
  src-level imports: `Layout.jsx` and `Navbar.jsx` (`auth/`, `Hooks/`).
- `Navbar.jsx` also imports `navigationConfig`; since Navbar itself moved into
  `shared/`, its path was corrected to the sibling `../utils/navigationConfig.jsx`
  (caught as a build error and fixed).
- Verified: `npm run build` passes; no stale `Layouts/`,
  `Hooks/useGlobalSearchShortcut`, or top-level `utils/navigationConfig`
  references remain.

## 2026-06-26 — App wiring + auth into `app/` and `auth/` (Stage 2)

Relocated the app-wiring and auth concerns into dedicated top-level folders.

- `providers/AppProviders.jsx` → `app/providers.jsx`; removed empty `providers/`.
- `routes/` → `app/routes/` (incl. `modules/admin|teacher|shared`).
- `Pages/auth/` → `auth/` (ProtectedRoute, Login). The dead `Auth.jsx` was
  already gone.
- `Hooks/AuthContext.jsx` → `auth/AuthContext.jsx`.

Import fixes (folder moves changed relative depths):
- `app/routes/AppRoutes.jsx`: `../` → `../../` for src-level imports.
- `app/routes/modules/*`: `../../../` → `../../../../`, and `Pages/auth/` →
  `auth/`.
- `auth/ProtectedRoute.jsx`: AuthContext now a sibling → `./AuthContext`.
- `auth/Login/Login.jsx`: → `../../api/auth` and `../AuthContext`.
- All other AuthContext consumers: `Hooks/AuthContext` → `auth/AuthContext`
  (same depth, both direct children of `src/`).
- `Hooks/UseContext.jsx`: relative sibling import `./AuthContext` →
  `../auth/AuthContext`.
- Verified: `npm run build` passes; no stale `Hooks/AuthContext`, `Pages/auth`,
  or `providers/AppProviders` references remain. (Pre-existing lint warnings in
  the moved files were not introduced by this change.)

## 2026-06-26 — Lowercased `Styles/` → `styles/` (Stage 1)

- `src/Styles/` → `src/styles/`. Done as a two-step move (`Styles` →
  `Styles_tmp` → `styles`) because macOS's case-insensitive filesystem treats
  `Styles` and `styles` as the same name.
- Updated the only reference: `import "./styles/index.css"` in `main.jsx`.
- Verified: directory is lowercase on disk; `npm run build` passes.

## 2026-06-26 — Fixed folder/file naming smells (Stage 1)

- `Pages/admin/ManagementPage/Invoices2.0/` → `…/invoices/` (no dot in folder
  name). Updated the lazy import in `AdminRoutes.jsx` and two commented imports
  in `Constants/SensitiveTools.jsx`.
- `Pages/admin/ManagementPage/Billings/Billlings.jsx` → `…/Billings/Billing.jsx`
  (typo fix; only the file was misspelled, the folder was already correct).
  Updated the lazy import in `AdminRoutes.jsx`.
- Verified: `npm run build` passes; no remaining `Invoices2.0` / `Billlings`
  references.
- Note: the browser route path `invoices-2.0/*` (AdminRoutes.jsx) was left
  unchanged — it's a URL, not a file path.

## 2026-06-26 — Renamed `Library/` → `api/` (Stage 1)

First step of the file-structure migration in [STRUCTURE.md](STRUCTURE.md).

- `src/Library/` → `src/api/`, with clearer file names:
  - `RequestMaker.jsx` → `client.js`
  - `Endpoints.jsx` → `endpoints.js`
  - `Authenticate.jsx` → `auth.js`
- Rewrote imports in all 48 referencing files (both `Library/Foo` and
  `Library/Foo.jsx` specifier variants) plus the internal cross-imports in
  `auth.js`. No `.jsx` extension needed — none of the three contain JSX.
- Verified: `npm run build` passes; no remaining `Library/` references.

## 2026-06-26 — Decomposed the global data context

Split the 711-line god provider `src/Hooks/UseContext.jsx` into focused
per-domain hooks under `src/Hooks/data/`, without changing its public API.

- New hooks (one responsibility each):
  - `usePaymentsData.js` — students / dorm / course lists + pagination + purpose
  - `useClassesData.js` — class list + per-class student cache
  - `useBillingsData.jsx` — billings + invoice/discount helpers + toasts
  - `useTimetableData.js` — timetable data + derived maps + refresh
  - `useTeachersData.js` — teachers list + client-side search filtering
  - `useUserInfoData.js` — profile user info
  - `useLeaderboardData.js` — students-with-points lookups
- `DataProvider` now just owns the shared `searchTerm` and composes the hooks.
  The `useGlobalContext` value shape is **unchanged**, so all 22 consumers were
  untouched.
- Verified: `npm run build` passes; `eslint` reports 0 errors (1 pre-existing
  react-refresh warning, same as the original file).
- This completes step 3 ("split the god context") of the migration in
  [STRUCTURE.md](STRUCTURE.md). State is now per-domain; promoting each to its
  own provider later is now a small, isolated change.

## 2026-06-25 — Auth & login hardening

Fixed five issues found while reviewing the auth/login flow.

- **Removed teacher PII from `localStorage`** (`src/Hooks/UseContext.jsx`) — the
  `localStorage.setItem("teachers", …)` write exposed teacher data to any XSS
  and was never read back. Deleted; no functionality lost.
- **Added global 401 interceptor** (`src/Library/RequestMaker.jsx`) — expired
  sessions now redirect to `/login` instead of silently failing. Guarded against
  redirect loops when already on `/login`.
- **Removed `console.log` of login response and error** (`src/Library/Authenticate.jsx`)
  — stopped leaking the server login payload to the console.
- **Awaited `login()` + outer try/catch** (`src/Pages/auth/Login/Login.jsx`) — an
  unexpected throw no longer leaves the button stuck on "Signing in…"; the user
  gets an error and the form resets.
- **Fixed blank flash on admin routes** (`src/Pages/auth/ProtectedRoute.jsx`) —
  `AdminRoute` and `AdminOrModeratorRoute` now render a spinner during
  `authLoading` instead of returning `null`.

## 2026-06-25 — Documentation baseline

- Added `docs/README.md` (index + documentation convention).
- Added `docs/STRUCTURE.md` (target file structure proposal — no code moved).
- Added `docs/CHANGELOG.md` (this file).
