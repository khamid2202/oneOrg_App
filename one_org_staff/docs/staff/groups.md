# Groups API

**Base path:** `/groups`

Manage class groups per academic year. A group is a unique combination of
academic year, grade, and class (e.g. `2023-2024` / grade `10` / class `A`),
assigned to a teacher and optionally linked to invoice templates.

## Auth
- Guard: `RolesGuard` + permission checks via `@RequirePermissions`.
- Permissions:
  - Create: `groups.create`
  - Update: `groups.update`
  - Upgrade: `groups.create`
  - Delete: `groups.delete`
  - Add student(s), single or bulk: `students.create`
  - Read (list, get one, export): authenticated

## Endpoints

| Method | Path | Description | Permission |
| --- | --- | --- | --- |
| GET | `/groups` | List groups (filterable) | authenticated |
| GET | `/groups/statistics` | Headline summary counts | authenticated |
| GET | `/groups/statistics/trend` | Group counts per creation date | authenticated |
| GET | `/groups/statistics/by-academic-year` | Counts grouped by academic year | authenticated |
| GET | `/groups/statistics/by-grade` | Counts grouped by grade | authenticated |
| GET | `/groups/statistics/by-class` | Counts grouped by class | authenticated |
| GET | `/groups/statistics/by-teacher` | Counts grouped by teacher | authenticated |
| GET | `/groups/:id` | Get one group | authenticated |
| GET | `/groups/export` | Export groups to Excel | authenticated |
| POST | `/groups` | Create a group | `groups.create` |
| PATCH | `/groups/:id` | Update a group (partial) | `groups.update` |
| POST | `/groups/upgrade` | Promote a group to the next grade/year | `groups.create` |
| POST | `/groups/:id/students` | Enrol a person into the group | `students.create` |
| POST | `/groups/:id/students/bulk` | Enrol many persons into the group | `students.create` |
| DELETE | `/groups/:id` | Delete a group (only when it has no students) | `groups.delete` |

### List groups
- **GET** `/groups`
- **Query (GetGroupDto):** all optional — `id`, `academic_year_id`,
  `grades` (int[] 1-12), `classes` (string[]), `teacher_ids` (int[]),
  `class_pairs` (string[], format `GRADE-CLASS`). Array params are coerced via
  `ToArray`.

### Statistics
All `/groups/statistics*` endpoints share the same optional filters
(**GetGroupStatisticsDto**) and return `{ ok, message, meta, result }`, where
`meta` echoes the applied filters. `total_students` counts student enrollments
in the matching groups.

- **Filters (all optional):**
  - `academic_year_id` (int)
  - `grade` (int 1-12)
  - `class` (single letter, case-insensitive)
  - `teacher_id` (int)
  - Date filters on the group's `created_at`: `date` (exact day), or
    `start_date` / `end_date` (range; either bound may be given alone). Dates are
    ISO strings; only the `YYYY-MM-DD` part is used.

#### Summary
- **GET** `/groups/statistics` → headline counts over the filtered set:
  `total_groups`, `distinct_academic_years`, `distinct_grades`,
  `distinct_classes`, `distinct_teachers`, `total_students`, `empty_groups`
  (groups with no students), and `avg_students_per_group`.

**Example**
```http
GET /groups/statistics?academic_year_id=5
```
```json
{
  "ok": true,
  "message": "Group statistics retrieved successfully",
  "meta": {
    "academic_year_id": 5, "grade": null, "class": null, "teacher_id": null,
    "date": null, "start_date": null, "end_date": null
  },
  "result": {
    "total_groups": 12,
    "distinct_academic_years": 1,
    "distinct_grades": 6,
    "distinct_classes": 3,
    "distinct_teachers": 10,
    "total_students": 284,
    "empty_groups": 1,
    "avg_students_per_group": 23.67
  }
}
```

#### Trend
- **GET** `/groups/statistics/trend` → `{ date, total }[]` — groups created per
  `created_at` date, ascending. `meta.total` is the number of dates returned.

#### By academic year
- **GET** `/groups/statistics/by-academic-year` →
  `{ academic_year_id, academic_year, total_groups, total_students }[]`,
  ordered by academic year name.

#### By grade
- **GET** `/groups/statistics/by-grade` →
  `{ grade, total_groups, total_students }[]`, ascending by grade.

#### By class
- **GET** `/groups/statistics/by-class` →
  `{ class, total_groups, total_students }[]`, ascending by class.

#### By teacher
- **GET** `/groups/statistics/by-teacher` →
  `{ teacher_id, teacher_name, total_groups, total_students }[]`, most groups
  first.

**Example (by-grade)**
```http
GET /groups/statistics/by-grade?academic_year_id=5
```
```json
{
  "ok": true,
  "message": "Group statistics by grade retrieved successfully",
  "meta": {
    "academic_year_id": 5, "grade": null, "class": null, "teacher_id": null,
    "date": null, "start_date": null, "end_date": null, "total": 2
  },
  "result": [
    { "grade": 10, "total_groups": 3, "total_students": 72 },
    { "grade": 11, "total_groups": 2, "total_students": 48 }
  ]
}
```

### Get one
- **GET** `/groups/:id`
- Returns a single group; `400` if not found.

**Example request**
```http
GET /groups/12
```

**Example response**
```json
{
  "id": 12,
  "name": "10A",
  "academic_year": "2023-2024",
  "grade": 10,
  "class": "A",
  "class_pair": "10-A",
  "class_pair_compact": "10A",
  "persons": 24,
  "invoice_templates": [
    {
      "id": 3,
      "code": "TUITION_10A",
      "amount": 120,
      "category": "tuition_fee",
      "description": "Grade 10A monthly tuition",
      "is_active": true
    }
  ],
  "teacher_id": 42,
  "teacher_name": "Jane Doe",
  "created_at": "2026-07-01T10:00:00.000Z",
  "created_by": "Admin User",
  "updated_at": "2026-07-01T10:00:00.000Z",
  "updated_by": null
}
```

### Export groups (Excel)
- **GET** `/groups/export`
- Accepts the same query filters as list; responds with an `.xlsx` attachment.

**Example request**
```http
GET /groups/export?academic_year_id=1&grades=[10]
```

**Example response**
```http
HTTP/1.1 200 OK
Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
Content-Disposition: attachment; filename="groups.xlsx"

<binary xlsx>
```

### Create group
- **POST** `/groups`
- **Body (CreateGroupDto):**
  - `academic_year_id` (int, required)
  - `grade` (int 1-12, required)
  - `class` (string, single letter, required — stored uppercased)
  - `teacher_id` (int, required)
  - `name` (string, optional — defaults to `${grade}${class}`, e.g. `10A`)
  - `invoice_template_ids` (int[], optional)
- **Validation performed by the service:**
  - Academic year must exist.
  - Teacher must exist, be `active`, and have the `teacher` role.
  - Every `invoice_template_ids` entry must exist.
  - The `(academic_year_id, grade, class)` combination must be unique.
- Returns the created group (via the same shape as *Get one*).

### Update group
- **PATCH** `/groups/:id`
- **Permission:** `groups.update`
- **Body (UpdateGroupDto):** All fields optional (partial update via
  `PartialType(CreateGroupDto)`):
  - `name` (string)
  - `academic_year_id` (int)
  - `grade` (int 1-12)
  - `class` (string, single letter — stored uppercased)
  - `teacher_id` (int)
  - `invoice_template_ids` (int[])
- **Validation performed by the service:**
  - The group must exist (`404` otherwise).
  - If `teacher_id` is provided: the teacher must exist, be `active`, and have
    the `teacher` role.
  - If `invoice_template_ids` is provided: every entry must exist.
  - If `academic_year_id` is provided: the academic year must exist.
  - If any of `academic_year_id`, `grade`, or `class` change, the new
    `(academic_year_id, grade, class)` combination must be unique.
- Sets `updated_by` to the current user.
- Returns the updated group (via the same shape as *Get one*).

**Example request**
```http
PATCH /groups/12
Content-Type: application/json

{ "teacher_id": 55, "name": "10A-Premium" }
```

**Example response**
```json
{
  "id": 12,
  "name": "10A-Premium",
  "academic_year": "2023-2024",
  "grade": 10,
  "class": "A",
  "class_pair": "10-A",
  "class_pair_compact": "10A",
  "persons": 24,
  "invoice_templates": [
    {
      "id": 3,
      "code": "TUITION_10A",
      "amount": 120,
      "category": "tuition_fee",
      "description": "Grade 10A monthly tuition",
      "is_active": true
    }
  ],
  "teacher_id": 55,
  "teacher_name": "John Smith",
  "created_at": "2026-07-01T10:00:00.000Z",
  "created_by": "Admin User",
  "updated_at": "2026-08-01T15:00:00.000Z",
  "updated_by": "Admin User"
}
```

### Add student
- **POST** `/groups/:id/students` — enrol a person into the group as a student.
- **Path param:** `id` — the group id.
- **Body (AddStudentDto):**
  - `person_id` (int, required)
- **Behaviour:**
  - Creates a student enrollment linking the person to the group, with
    `join_date` set to **today**.
  - The enrollment inherits the group's linked `invoice_template_ids`.
  - Invoices for the **current month** are auto-generated **only when today
    falls within the group's academic year** (its `start_date`/`end_date`
    range, with `null` bounds treated as open-ended) — one per inherited invoice
    template, applying any active discounts. Generation is best-effort and does
    not fail the enrollment. Outside that window the student is still created but
    no invoices are generated.
- **Validation:**
  - The group must exist (`400` otherwise).
  - The same person cannot be enrolled in the same group twice (`400`).
- Returns the created student enrollment.

**Example request**
```http
POST /groups/12/students
Content-Type: application/json

{ "person_id": 100 }
```

**Example response**
```json
{
  "ok": true,
  "message": "Student created successfully",
  "result": {
    "id": 345,
    "person_id": 100,
    "group_id": 12,
    "join_date": "2026-07-08",
    "status": "present",
    "invoice_template_ids": [3],
    "created_by": 7
  }
}
```

### Bulk add students
- **POST** `/groups/:id/students/bulk` — enrol many persons into the group in
  one call.
- **Path param:** `id` — the group id.
- **Body (BulkAddStudentsDto):**
  - `person_ids` (int[], required, non-empty, max 1000).
- **Behaviour:**
  - `person_ids` are de-duplicated; anyone **already enrolled** in the group is
    skipped and reported in `skipped_person_ids`.
  - Each new enrollment joins **today** and inherits the group's
    `invoice_template_ids`.
  - Invoices for the **current month** are generated for the created students
    under the same rule as single add — **only when today is within the group's
    academic year** (best-effort).
- **Validation:**
  - The group must exist (`400` otherwise).
- Returns a summary: `created` / `skipped` counts, the `skipped_person_ids`,
  whether the run was `within_academic_year` / `invoices_generated`, and the
  created `students`.

**Example request**
```http
POST /groups/12/students/bulk
Content-Type: application/json

{ "person_ids": [100, 101, 102] }
```

**Example response**
```json
{
  "ok": true,
  "message": "Students added to group successfully",
  "result": {
    "created": 2,
    "skipped": 1,
    "skipped_person_ids": [100],
    "within_academic_year": true,
    "invoices_generated": true,
    "students": [
      {
        "id": 346,
        "person_id": 101,
        "group_id": 12,
        "join_date": "2026-07-08",
        "status": "present",
        "invoice_template_ids": [3],
        "created_by": 7
      },
      {
        "id": 347,
        "person_id": 102,
        "group_id": 12,
        "join_date": "2026-07-08",
        "status": "present",
        "invoice_template_ids": [3],
        "created_by": 7
      }
    ]
  }
}
```

### Upgrade group
- **POST** `/groups/upgrade` — promote a group to the **next grade** in a new
  academic year, carrying its students over.
- **Body (UpgradeGroupDto):**
  - `group_id` (int, required) — the source group to promote.
  - `new_academic_year_id` (int, required) — the academic year of the new group.
  - `new_invoice_template_id` (int, optional) — optional invoice template to attach to the upgraded group.
  - `exclude` (int[], optional) — optional array of person IDs who should not be moved to the new group.
- **Behaviour:**
  - Creates a new group copying the source group's `class`, `teacher_id`, and
    `invoice_template_ids`, with `grade` incremented by one.
  - `name`: if the source name is the auto-generated default (`${grade}${class}`,
    e.g. `10A`) or empty, the new name is regenerated for the new grade
    (`11A`); a custom name is preserved as-is.
  - Re-enrols distinct `person_id`s from the source group into the new group as a
    student (excluding any person IDs specified in `exclude`), with
    `join_date` set to **today** and inheriting the new group's
    `invoice_template_ids`. People already in the new group are skipped.
  - **Invoices:** only when **today falls within the new academic year**
    (`start_date`/`end_date`, with `null` bounds treated as open-ended), each
    new student's invoices are generated for the current month (best-effort,
    per inherited template). Outside that window the students are still created
    but no invoices are generated (e.g. when pre-promoting before the year
    starts).
- **Validation / rejections (`400`):**
  - Source group must exist.
  - Source grade must be below `11` — grade `11` is the highest and cannot be
    upgraded further.
  - The new academic year must exist.
  - The target `(new_academic_year_id, grade + 1, class)` group must not already
    exist.
- **Note:** the source group and its enrollments are left untouched; the copied
  `teacher_id` is not re-validated (it may reference a teacher who has since
  become inactive).
- Returns the new group plus a summary of what was carried over.

**Example request**
```http
POST /groups/upgrade
Content-Type: application/json

{ "group_id": 12, "new_academic_year_id": 5, "exclude": [101, 102] }
```

**Example response**
```json
{
  "ok": true,
  "message": "Group upgraded successfully",
  "result": {
    "group": {
      "id": 88,
      "name": "11A",
      "academic_year": "2026-2027",
      "grade": 11,
      "class": "A",
      "persons": 24
    },
    "students_created": 24,
    "students_skipped": 0,
    "within_academic_year": true,
    "invoices_generated": true
  }
}
```

### Delete group
- **DELETE** `/groups/:id`
- **Permission:** `groups.delete`
- **Behaviour:** deletes the group permanently. Responds `204 No Content` with an
  empty body.
- **Validation / rejections:**
  - `404` — the group does not exist.
  - `400` — the group still has student enrollments attached
    (`Cannot delete group as it has N student(s) attached to it`). Remove or move
    the enrollments to another group first, then retry.

**Example request**
```http
DELETE /groups/12
```

**Example response**
```http
HTTP/1.1 204 No Content
```

**Example rejection**
```json
{
  "statusCode": 400,
  "message": "Cannot delete group as it has 24 student(s) attached to it",
  "error": "Bad Request"
}
```

## Usage notes
- Group uniqueness is enforced by a DB unique index on
  `(academic_year_id, grade, class)`; create and update both reject duplicates.
- `class` is always normalized to uppercase.
- Create and update run under the caller's user id for audit
  (`created_by` / `updated_by`).

## Create example

- **Method:** POST
- **Path:** `/groups`
- **Request body:**
```json
{
  "academic_year_id": 1,
  "grade": 10,
  "class": "A",
  "teacher_id": 42,
  "invoice_template_ids": [3]
}
```

- **Response:**
```json
{
  "id": 12,
  "name": "10A",
  "academic_year": "2023-2024",
  "grade": 10,
  "class": "A",
  "class_pair": "10-A",
  "class_pair_compact": "10A",
  "persons": 0,
  "invoice_templates": [
    {
      "id": 3,
      "code": "TUITION_10A",
      "amount": 120,
      "category": "tuition_fee",
      "description": "Grade 10A monthly tuition",
      "is_active": true
    }
  ],
  "teacher_id": 42,
  "teacher_name": "Jane Doe",
  "created_at": "2026-07-01T10:00:00.000Z",
  "created_by": "Admin User",
  "updated_at": "2026-07-01T10:00:00.000Z",
  "updated_by": null
}
```

## List example

- **Method:** GET
- **Path:** `/groups`
- **Query:** `?academic_year_id=1&grades=10&classes=A`
- **Response:**
```json
{
  "ok": true,
  "meta": {
    "total": 1,
    "query": { "academic_year_id": 1, "grades": [10], "classes": ["A"] }
  },
  "groups": [
    {
      "id": 12,
      "name": "10A",
      "academic_year": "2023-2024",
      "grade": 10,
      "class": "A",
      "class_pair": "10-A",
      "class_pair_compact": "10A",
      "persons": 24,
      "invoice_templates": [
        {
          "id": 3,
          "code": "TUITION_10A",
          "amount": 120,
          "category": "tuition_fee",
          "description": "Grade 10A monthly tuition",
          "is_active": true
        }
      ],
      "teacher_id": 42,
      "teacher_name": "Jane Doe"
    }
  ]
}
```

## Frontend suggestions
- Normalize `class_pairs` inputs as `GRADE-CLASS` strings.
- On create, pre-validate that grade is 1-12 and class is a single letter to
  surface errors before the request.
