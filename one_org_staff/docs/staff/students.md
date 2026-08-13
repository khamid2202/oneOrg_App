# Students API

**Base path:** `/students`

Manage student enrollments. A **student** is an enrollment record linking a
`person` to a `group`, with a join/leave date, status, and a set of invoice
templates. Read endpoints always hydrate each enrollment with its related
`person` (flattened to top-level `full_name` for convenience; the full person
object including `picture_url`, `birth_date`, `address`, `phone`, `gender` is
also attached)
and `group`; heavier relations (`contacts`, `guardians`, `documents`, `invoice_templates`,
`invoices`, `payments`, `dorm_records`) are attached only when requested via the
`include` query parameter.

## Auth
- Guard: `RolesGuard` + permission checks via `@RequirePermissions`.
- Permissions:
  - Create: `students.create`
  - Update: `students.update`
  - Delete: `students.delete`
  - Read (list, get one): authenticated

> Profile pictures are stored on the **Person** record and have moved to the
> [Persons API](persons.md) (`/persons/:personId/picture`).

## Endpoints

| Method | Path | Description | Permission |
| --- | --- | --- | --- |
| GET | `/students` | List enrollments (filterable) | authenticated |
| GET | `/students/statistics` | Headline summary counts | authenticated |
| GET | `/students/statistics/trend` | Enrollment counts per join date | authenticated |
| GET | `/students/statistics/by-status` | Counts grouped by status | authenticated |
| GET | `/students/statistics/by-group` | Counts grouped by group | authenticated |
| GET | `/students/statistics/by-grade` | Counts grouped by grade | authenticated |
| GET | `/students/statistics/by-academic-year` | Counts grouped by academic year | authenticated |
| GET | `/students/:id` | Get one enrollment | authenticated |
| POST | `/students` | Create an enrollment | `students.create` |
| PATCH | `/students/:id` | Update an enrollment | `students.update` |
| DELETE | `/students/:id` | Delete an enrollment | `students.delete` |

### List students
- **GET** `/students`
- **Query (GetStudentDto):** all optional —
  - Filters: `person_id`, `group_id`, `academic_year_id`, `status`.
  - Hydration: `include` (JSON string array — see
    [Relations](#relations-attached-to-read-responses)).
  - Pagination: `page` (int ≥ 1, default `1`), `limit` (int 1–100, default `50`).
- `academic_year_id` resolves the matching group ids first (the academic year
  is derived from the student's group), then filters enrollments by them.
- Results are paginated by default; `meta` returns `total`, `page`, `limit`, and
  `pages` (total page count).

**Example request**
```http
GET /students?academic_year_id=3&status=present&page=1&limit=50&include=["invoices","payments"]
```

**Example response**
```json
{
  "ok": true,
  "message": "Students retrieved successfully",
  "meta": { "total": 1, "page": 1, "limit": 50, "pages": 1 },
  "result": [
    {
      "id": 12,
      "person_id": 100,
      "group_id": 5,
      "join_date": "2025-09-01",
      "leave_date": null,
      "status": "present",
      "invoice_template_ids": [3],
      "created_by": 5,
      "created_at": "2025-09-05T08:00:00.000Z",
      "updated_by": null,
      "updated_at": "2025-09-05T08:00:00.000Z",
      "full_name": "Ali Valiyev",
      "person": {
        "id": 100,
        "code": "P-100",
        "full_name": "Ali Valiyev",
        "picture_url": null
      },
      "group": {
        "id": 5,
        "name": "10A",
        "academic_year_id": 3,
        "grade": 10,
        "class": "A",
        "teacher_id": 42,
        "invoice_template_ids": [3]
      },
      "invoices": [
        {
          "id": 88,
          "student_id": 12,
          "academic_year_id": 3,
          "year": 2025,
          "month": 10,
          "invoice_template_id": 3,
          "subtotal_required_amount": 120,
          "discount_percent": 0,
          "total_required_amount": 120,
          "total_paid_amount": 120,
          "status": "Paid"
        }
      ],
      "payments": [
        {
          "id": 55,
          "student_id": 12,
          "invoice_id": 88,
          "amount": 120,
          "date": "2025-10-10",
          "method": "cash",
          "comment": null,
          "is_refund": false
        }
      ]
    }
  ]
}
```

Without `include`, the same enrollment comes back with only the base fields plus
`full_name`, `person`, and `group` — no `contacts`, `guardians`,
`invoice_templates`, `invoices`, `payments`, or `dorm_records` keys.

### Get one
- **GET** `/students/:id`
- **Query (StudentIncludeDto):** optional `include` (same values as the list).
- Returns a single hydrated enrollment; `404` if not found.

**Example request**
```http
GET /students/12?include=["contacts"]
```

**Example response**
```json
{
  "ok": true,
  "message": "Student retrieved successfully",
  "result": {
    "id": 12,
    "person_id": 100,
    "group_id": 5,
    "join_date": "2025-09-01",
    "leave_date": null,
    "status": "present",
    "invoice_template_ids": [3],
    "created_by": 5,
    "created_at": "2025-09-05T08:00:00.000Z",
    "updated_by": null,
    "updated_at": "2025-09-05T08:00:00.000Z",
    "full_name": "Ali Valiyev",
    "person": {
      "id": 100,
      "code": "P-100",
      "full_name": "Ali Valiyev",
      "picture_url": null
    },
    "group": {
      "id": 5,
      "name": "10A",
      "academic_year_id": 3,
      "grade": 10,
      "class": "A",
      "teacher_id": 42,
      "invoice_template_ids": [3]
    },
    "contacts": [
      {
        "id": 7,
        "person_id": 100,
        "full_name": "Valijon Valiyev",
        "relationship": "father",
        "phone_number": "+998901112233",
        "telegram_id": "123456789"
      }
    ]
  }
}
```

## Statistics

All `/students/statistics*` endpoints share the same filter set
(`GetStudentStatisticsDto`, all optional) and are aggregated over enrollments
joined to their group:

| Filter | Applies to |
| --- | --- |
| `academic_year_id` | group's academic year |
| `group_id` | enrollment group |
| `grade` (1–12) | group's grade |
| `teacher_id` | group's teacher |
| `status` | enrollment status |
| `date` | exact `join_date` |
| `start_date` / `end_date` | `join_date` range (inclusive) |

Date filters target `join_date`. Every response echoes the applied filters under
`meta`; the grouped endpoints also add `meta.total` = number of buckets. The
`meta` examples below are abbreviated to the non-null filters — the real
response always echoes all eight filter keys (unused ones as `null`).

### Summary
- **GET** `/students/statistics`
- `result`: `{ total, distinct_persons, distinct_groups, distinct_academic_years, active, left }`
  where `active` counts enrollments with no `leave_date` and `left` counts those
  with one.

**Example request**
```http
GET /students/statistics?academic_year_id=3
```

**Example response**
```json
{
  "ok": true,
  "message": "Student statistics retrieved successfully",
  "meta": {
    "academic_year_id": 3, "group_id": null, "grade": null,
    "teacher_id": null, "status": null,
    "date": null, "start_date": null, "end_date": null
  },
  "result": {
    "total": 128,
    "distinct_persons": 120,
    "distinct_groups": 8,
    "distinct_academic_years": 1,
    "active": 122,
    "left": 6
  }
}
```

### Trend
- **GET** `/students/statistics/trend`
- `result`: `[{ date, total }]` ordered by `join_date` ascending.

**Example request**
```http
GET /students/statistics/trend?academic_year_id=3&start_date=2025-09-01&end_date=2025-09-30
```

**Example response**
```json
{
  "ok": true,
  "message": "Student trend retrieved successfully",
  "meta": { "academic_year_id": 3, "start_date": "2025-09-01", "end_date": "2025-09-30", "total": 2 },
  "result": [
    { "date": "2025-09-01", "total": 110 },
    { "date": "2025-09-15", "total": 18 }
  ]
}
```

### By status
- **GET** `/students/statistics/by-status`
- `result`: `[{ status, total }]` ordered by `total` descending.

**Example request**
```http
GET /students/statistics/by-status?academic_year_id=3
```

**Example response**
```json
{
  "ok": true,
  "message": "Student statistics by status retrieved successfully",
  "meta": { "academic_year_id": 3, "total": 2 },
  "result": [
    { "status": "present", "total": 122 },
    { "status": "left", "total": 6 }
  ]
}
```

### By group
- **GET** `/students/statistics/by-group`
- `result`: `[{ group_id, group_name, grade, class, total }]`, most populated first.

**Example request**
```http
GET /students/statistics/by-group?academic_year_id=3
```

**Example response**
```json
{
  "ok": true,
  "message": "Student statistics by group retrieved successfully",
  "meta": { "academic_year_id": 3, "total": 2 },
  "result": [
    { "group_id": 5, "group_name": "10A", "grade": 10, "class": "A", "total": 32 },
    { "group_id": 6, "group_name": "10B", "grade": 10, "class": "B", "total": 30 }
  ]
}
```

### By grade
- **GET** `/students/statistics/by-grade`
- `result`: `[{ grade, total }]` ordered by grade ascending.

**Example request**
```http
GET /students/statistics/by-grade?academic_year_id=3
```

**Example response**
```json
{
  "ok": true,
  "message": "Student statistics by grade retrieved successfully",
  "meta": { "academic_year_id": 3, "total": 2 },
  "result": [
    { "grade": 9, "total": 66 },
    { "grade": 10, "total": 62 }
  ]
}
```

### By academic year
- **GET** `/students/statistics/by-academic-year`
- `result`: `[{ academic_year_id, academic_year, total }]`.

**Example request**
```http
GET /students/statistics/by-academic-year?status=present
```

**Example response**
```json
{
  "ok": true,
  "message": "Student statistics by academic year retrieved successfully",
  "meta": { "status": "present", "total": 2 },
  "result": [
    { "academic_year_id": 2, "academic_year": "2024-2025", "total": 115 },
    { "academic_year_id": 3, "academic_year": "2025-2026", "total": 122 }
  ]
}
```

### Create student
- **POST** `/students`
- **Body (CreateStudentDto):**
  - `person_id` (int, required)
  - `group_id` (int, required)
  - `join_date` (ISO date string, required)
  - `leave_date` (ISO date string, optional)
  - `status` (string, optional — defaults to `present`)
  - `invoice_template_ids` (int[], optional)
- The new enrollment inherits the group's `invoice_template_ids` merged with any
  provided on the body (de-duplicated). Invoice generation is triggered
  automatically for the student.
- Rejects a duplicate `(person_id, group_id)` enrollment with `400`.
- The response `result` is the raw enrollment row (not hydrated).

**Example request**
```json
{
  "person_id": 100,
  "group_id": 5,
  "join_date": "2025-09-01",
  "invoice_template_ids": [4]
}
```

**Example response** (template `3` inherited from the group, `4` from the body)
```json
{
  "ok": true,
  "message": "Student created successfully",
  "result": {
    "id": 12,
    "person_id": 100,
    "group_id": 5,
    "join_date": "2025-09-01",
    "leave_date": null,
    "status": "present",
    "invoice_template_ids": [3, 4],
    "created_by": 5,
    "created_at": "2025-09-05T08:00:00.000Z",
    "updated_by": null,
    "updated_at": "2025-09-05T08:00:00.000Z"
  }
}
```

### Update student
- **PATCH** `/students/:id`
- **Body:** partial of `CreateStudentDto`. `400` if the body is empty; re-checks
  the `(person_id, group_id)` uniqueness when either changes.
- The response `result` is the raw enrollment row (not hydrated).

**Example request**
```http
PATCH /students/12
```
```json
{
  "status": "left",
  "leave_date": "2026-05-30"
}
```

**Example response**
```json
{
  "ok": true,
  "message": "Student updated successfully",
  "result": {
    "id": 12,
    "person_id": 100,
    "group_id": 5,
    "join_date": "2025-09-01",
    "leave_date": "2026-05-30",
    "status": "left",
    "invoice_template_ids": [3, 4],
    "created_by": 5,
    "created_at": "2025-09-05T08:00:00.000Z",
    "updated_by": 5,
    "updated_at": "2026-05-30T10:00:00.000Z"
  }
}
```

### Delete student
- **DELETE** `/students/:id`
- Returns `204 No Content` (empty body); `404` if not found.

**Example request**
```http
DELETE /students/12
```

## Relations attached to read responses
Lookups are batched (works for both single and list reads).

**Always attached:**

| Field | Source | Keyed by |
| --- | --- | --- |
| `full_name` | `persons` (flattened) | `student.person_id` |
| `person` | `persons` | `student.person_id` |
| `group` | `groups` | `student.group_id` |

**Opt-in via `include`** (a JSON string array, e.g.
`?include=["invoices","payments"]`; invalid values are rejected with `400`).
Fields not requested are omitted from the response entirely:

| Include value | Source | Keyed by |
| --- | --- | --- |
| `contacts` | `contacts` | `person_id` |
| `guardians` | `guardians` | `person_id` |
| `documents` | `documents` | `person_id` |
| `invoice_templates` | `invoice_templates` | `student.invoice_template_ids` |
| `invoices` | `invoices` | `student.id` |
| `payments` | `payments` | `student.id` |

## Error responses
| Status | Condition |
| --- | --- |
| `400 Bad Request` | Duplicate enrollment `(person_id, group_id)`; empty update body; unknown `include` value or non-array `include` |
| `404 Not Found` | Student not found |
| `403 Forbidden` | Missing the required permission for the mutation |

## Frontend suggestions
- The list is paginated (50 per page by default). Drive paging from
  `meta.pages` / `meta.total`; pass `page` and `limit` (max `100`) to fetch more.
- Use `academic_year_id` to scope a class roster; combine with `group_id` to
  narrow to a single group.
- Rosters only need the base response (`full_name`, `picture_url`, `group`);
  request the heavier relations with `include` only on screens that show them
  (e.g. `include=["invoices","payments"]` on a student's finance tab) to keep
  list payloads small.
- Profile pictures live on the [Persons API](persons.md), keyed by `personId`
  (the enrollment's `person_id`), not the enrollment `id`.
