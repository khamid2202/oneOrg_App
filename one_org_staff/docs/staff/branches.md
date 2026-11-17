# Branches API

**Base path:** `/branches`

## Overview
Branches are the campuses of the school. Staff can belong to several branches.
Groups, rooms, dorm rooms, time slots, bell schedules, lessons, timetable
versions and generations, timetable constraints, availability, exam periods and
departments each belong to one branch; most other data inherits its branch from those.

The migration created a **Main** branch (`id: 1`), put all existing data in it
and assigned every user to it.

All branch-owned data is scoped (see [Scoped data](#scoped-data)). Academic
years, subjects and categories, invoice templates, holidays, settings and roles
are shared by every branch.

Routes use `@RequirePermissions`, except `GET /branches/my`, which is open to
any staff member. The `branches.*` keys aren't granted to any role by default,
so only `admin` has them until you grant them.
- `GET`: `branches.read`; `POST /branches`: `branches.create`;
  `PATCH` and staff changes: `branches.update`; `DELETE /branches/:id`: `branches.delete`.

## Selecting a branch
Staff requests can send an `X-Branch-Id` header to choose which branches they
read and where new records go.

| Request | Reads | New records go to |
| --- | --- | --- |
| Header set | That branch only | That branch |
| No header, one branch | That branch | That branch |
| No header, several branches | All of them | Refused until a branch is selected |
| No header, `branches.access_all` | Every branch | The only active branch if there is one, otherwise refused |

- A user without `branches.access_all` can only select active branches they are
  assigned to; anything else returns `403`. If a saved selection starts returning
  `403`, drop the header and call `GET /branches/my` again.
- `branches.access_all` can select any branch, including inactive ones.
- A value that isn't a number returns `400`.

## Scoped data
Lists, statistics and exports only include records in the readable branches,
and a record at another branch returns the same `404` as one that doesn't exist.

| Data | Branch comes from |
| --- | --- |
| Groups, rooms, dorm rooms | Their own `branch_id`, which responses include |
| Time slots, bell schedules, timetable versions, lessons (workload), availability, timetable constraints, timetable generations, exam periods | Their own `branch_id` |
| Students | Their group |
| Timetable entries, lesson instances, homework, attendance, lesson grades, teacher lateness, substitutions, group divisions | Their class |
| Exams and exam results | Their exam period |
| Invoices, payments, discounts | Their enrollment's class |
| Student points | Their class |
| Staff KPI points, lesson plans | The staff member's branch assignments |
| Departments | Their own `branch_id`; see [Departments](departments.md) |
| Guardians, contacts, documents, health records | Their person (shared; see below) |
| Change log | The branch the change was made in; see below |
| Dorm students | Their dorm room; the student must be at the same branch |
| Staff users | Their branch assignments |
| Persons | Shared; see below |

- New groups, rooms and dorm rooms go to the active branch, so a user with
  several branches must select one. An upgraded group stays at the source
  group's branch.
- A group's homeroom teachers must be active staff at its branch.
- Persons are shared across branches. A person is visible while currently
  enrolled at a readable branch or while not enrolled anywhere (applicants,
  alumni). Searching `GET /persons?search=` with a person's exact `code` finds
  them anywhere, so staff can look up a student to enrol or transfer.
- Enrolling a person who is still enrolled at another branch returns `400`;
  transfer them with `POST /students/:id/transfer` instead.
- `PATCH /students/:id` can't move an enrollment to another branch's group.
  Transfers move the enrollment with all its records; `POST /groups/:id/move`
  moves a whole class.
- New time slots, bell schedules, timetable versions, lessons, availability
  grids, constraints, generations and exam periods also go to the active
  branch, and so do timetable Excel templates and imports.
- Generating invoices (`POST /invoices`) only bills classes in the readable
  branches, and bulk invoice updates and deletes only touch them.
- `POST /notifications/send` with `staff`, `students` or `all` only reaches the
  readable branches: staff assigned there and students enrolled there. A
  `user` or `person` target must be visible too. A `topic` broadcast can't be
  limited, so it needs an org-wide user without `X-Branch-Id`; anyone else
  gets `403`.
- Each change-log row records the branch selected by the request that made it
  (`branch_id`; `null` for an org-wide user without `X-Branch-Id`, and for
  background jobs). Earlier rows belong to Main. Branch staff only see rows of
  their branches; rows with no branch are only shown to org-wide users.
- `POST /users/create` defaults `branch_ids` to the active branch and only
  accepts branches the creator can reach. The Excel upload adds new users to the
  active branch and skips existing users at other branches.

## Timetables per branch
Each branch has its own bell schedules, time slots and timetable versions, and
publishes its own version for each academic year: publishing archives only that
branch's previous version.

- A timetable entry goes to a version of its class's branch. Without
  `timetable_version_id` it goes to that branch's published version.
- An entry's teachers must be assigned to its branch; its room and time slot
  must be the branch's own. A class can't move to another branch's class.
- A choice's classes must all be at one branch.
- A lesson's classes, teachers and allowed rooms must all be at its branch.
- Generation, the pre-check and the queue are per branch: one active run per
  branch and year. Other branches' runs are hidden from `GET
  /timetable-generations/queue` but still count in its positions.
- An exam's classes must be at its exam period's branch, and a result's
  student must have an enrollment there.
- A timetable constraint's classes, lessons and teachers must be at its branch.

### Teachers at several branches
A teacher can be assigned to more than one branch.

- **Clash checks:** writes and publishing also check the teacher against the
  other branches' published versions for the same year. Times are compared on
  the clock, since bell schedules differ, and the message names the branch,
  e.g. `Teacher "Ali Valiyev" is already booked for 7-B at North on Monday
  09:00–09:45`. `force` still publishes despite these clashes.
- **Generation:** periods that overlap the teacher's lessons in other branches'
  published versions are marked unavailable for the teacher. Availability is
  stored per period number, so a period number is blocked if it overlaps in
  any of the branch's bell schedules.
- **Teacher's own views:** `GET /timetable/my-lessons` and the teacher's
  lessons for a date cover every branch they work at, whatever `X-Branch-Id`
  selects.
- **Absences:** teacher absences belong to the teacher, not a branch.

## Known limitations
- Homework without a class is only visible to org-wide users.
- Reverting the change-log migration and applying it again puts every row in
  Main, including rows written at other branches.

## Data Shape

Branch object:
```json
{
	"id": 2,
	"code": "NORTH",
	"name": "North Campus",
	"address": "12 School St",
	"phone": "+998901234567",
	"is_active": true,
	"created_at": "2026-11-03T10:00:00.000Z",
	"created_by": 7,
	"updated_at": "2026-11-03T10:00:00.000Z",
	"updated_by": null
}
```

Validation and business rules:
- `code`: string, length `1..20`, unique (case-insensitive)
- `name`: string, length `1..100`, unique (case-insensitive)
- `address`: optional string, length `1..255`
- `phone`: optional string, length `1..30`
- `is_active`: boolean (default `true`). Staff can't be assigned to an inactive branch.
- The Main branch can't be deactivated or deleted.
- A branch with staff or data can't be deleted; deactivate it instead.

## Endpoints

### 1) Get Branches
`GET /branches`

Query params (all optional): `search` (name or code), `is_active`.

### My Branches
`GET /branches/my`

Lists the branches the current user can select, for a branch switcher, with
`meta.all_branches` set for `branches.access_all`.

### 2) Get Branch
`GET /branches/:id`

### 3) Create Branch
`POST /branches`

### 4) Update Branch
`PATCH /branches/:id`

### 5) Delete Branch
`DELETE /branches/:id`

Returns `204`, or `409` if it is Main or still has staff or data.

### 6) Get Branch Staff
`GET /branches/:id/staff`

Returns each user's `id`, `username`, `full_name`, `status` and `roles`.

### 7) Assign Staff
`POST /branches/:id/staff`

```json
{ "user_ids": [5, 6] }
```

Users already in the branch are left as they are. Returns `400` if a user
doesn't exist or the branch is inactive.

### 8) Remove Staff
`DELETE /branches/:id/staff/:userId`

Returns `204`, or `409` if this is the user's only branch.

## New users
`POST /users/create` accepts an optional `branch_ids` array and defaults to the
active branch. Users added through the Excel upload go to the active branch.
