# Students API

**Base path:** `/students`

All endpoints require a valid JWT. The `RolesGuard` is applied at the controller level. Endpoints without an explicit `@Roles` decorator are accessible to **any authenticated user**; those with `@Roles` restrict access to the listed roles.

---

## Table of Contents

1. [GET /students — List students](#1-get-students--list-students)
2. [GET /students/unassigned — List unassigned students](#2-get-studentsunassigned--list-unassigned-students)
3. [GET /students/:id — Get one student](#3-get-studentsid--get-one-student)
4. [POST /students — Create student](#4-post-students--create-student)
5. [PATCH /students/:id — Update student](#5-patch-studentsid--update-student)
6. [POST /students/upload-v2 — Bulk import (Excel)](#6-post-studentsupload-v2--bulk-import-excel)
7. [POST /students/assign-billings — Assign billings](#7-post-studentsassign-billings--assign-billings)
8. [POST /students/assign-group — Assign student to group](#8-post-studentsassign-group--assign-student-to-group)
9. [POST /students/update-group — Move student to another group](#9-post-studentsupdate-group--move-student-to-another-group)
10. [DELETE /students/remove-from-group — Remove student from group](#10-delete-studentsremove-from-group--remove-student-from-group)

---

## 1. GET /students — List students

**Alias:** `GET /students/all`  
**Roles:** any authenticated user

### Query parameters

| Parameter | Type | Required | Default | Description |
|---|---|---|---|---|
| `academic_year_id` | integer | **yes** | — | Filter students enrolled in this academic year |
| `id` | integer | no | — | Filter to a single student by ID |
| `limit` | integer | no | `30` | Page size (max enforced by `ToLimit`) |
| `page` | integer | no | `1` | Page number (1-based) |
| `q` | string | no | — | Case-insensitive full-name search (`ILIKE %q%`) |
| `include_group` | boolean | no | `false` | Attach group info to each student |
| `include_wallet` | boolean | no | `false` | Attach wallet balance. Requires `can_view_wallet` permission |
| `include_billings` | boolean | no | `false` | Attach assigned billing plans. Requires `can_view_billings` permission |
| `include_invoices` | boolean | no | `false` | Attach invoice history. Requires `can_view_invoices` permission |
| `include_payments` | boolean | no | `false` | Attach payment history. Requires `can_view_payments` permission. Also requires `include_group=true` |
| `include_discounts` | boolean | no | `false` | Attach discounts. Requires `can_view_discounts` permission |
| `include_points` | boolean | no | `false` | Attach point records and total. Requires `can_view_points` permission |
| `filter` | JSON string | no | — | See filter object below |
| `sort` | JSON string | no | — | See sort array below |

Pass boolean flags as the string `"true"` / `"false"` (or `"1"` / `"0"`).

#### `filter` object (JSON-encoded string)

```jsonc
{
  "group_ids": ["5", "6"],          // array of group ID strings
  "teacher_ids": ["2", "3"],        // array of teacher user ID strings
  "teachers": ["John Smith"],       // full names of teachers (exact match)
  "grades": [10, 11],               // integers 1-12
  "classes": ["A", "B"],            // single uppercase letters
  "class_pairs": ["10-A", "11-B"],  // "GRADE-CLASS" format
  "billing_ids": [1, 2],            // integer billing IDs
  "billing_codes": ["TUITION"],     // billing code strings
  "billing_categories": ["monthly"] // billing category strings
}
```

All `filter` fields are optional and can be combined. `include_group` must be `true` when any group-related filter is used (`group_ids`, `teacher_ids`, `teachers`, `grades`, `classes`, `class_pairs`).

#### `sort` array (JSON-encoded string)

```jsonc
[
  { "field": "student_name", "order": "ASC" },
  { "field": "join_date",    "order": "DESC" }
]
```

Available sort fields:

| Field | Maps to |
|---|---|
| `student_id` | `s.id` |
| `student_group_id` | `sg.id` |
| `student_name` | `s.full_name` |
| `join_date` | `sg.join_date` |
| `leave_date` | `sg.leave_date` |
| `status` | `s.status` |
| `created_at` | `s.created_at` |
| `updated_at` | `s.updated_at` |
| `grade` | `g.grade` (requires `include_group`) |
| `class` | `g.class` (requires `include_group`) |
| `group_name` | `g.name` (requires `include_group`) |
| `payment_date` | last payment date |
| `total_points` | sum of points |

`order` defaults to `"ASC"` if omitted.

### Example request

```
GET /students?academic_year_id=3&include_group=true&include_billings=true&q=ali&limit=20&page=1
    &filter={"grades":[10,11],"classes":["A","B"]}
    &sort=[{"field":"student_name","order":"ASC"}]
```

### Response

```jsonc
{
  "ok": true,
  "meta": {
    "total": 42,
    "academic_year": {
      "id": 3,
      "name": "2025-2026",
      "start_date": "2025-09-01",
      "end_date": "2026-06-30"
    },
    "range": { "from": 1, "to": 20 },
    "count": 20,
    "page": 1,
    "limit": 20,
    "filter": { "grades": [10, 11], "classes": ["A", "B"] },
    "q": "ali",
    "sort": [{ "field": "student_name", "order": "ASC" }],
    "include_group": true,
    "include_wallet": false,
    "include_billings": true,
    "include_invoices": false,
    "include_payments": false,
    "include_discounts": false,
    "include_points": false
  },
  "students": [
    {
      "student_id": 12,
      "student_group_id": 7,
      "full_name": "Ali Valiyev",
      "nickname": "Ali",
      "status": "active",
      "created_by": "John Admin",
      "updated_by": null,
      "created_at": "2025-09-05T08:00:00.000Z",
      "updated_at": "2025-09-05T08:00:00.000Z",
      "academic_year_id": 3,
      // include_group=true:
      "group": {
        "id": 5,
        "join_date": "2025-09-01",
        "leave_date": null,
        "status": "active",
        "name": "10A",
        "grade": 10,
        "class": "A",
        "class_pair": "10-A",
        "class_pair_compact": "10A",
        "teacher_name": "Jane Teacher"
      },
      // include_billings=true:
      "billings": [
        {
          "id": 1,
          "code": "TUITION",
          "description": "Monthly tuition fee",
          "amount": 500000,
          "category": "monthly",
          "is_active": true
        }
      ],
      // include_wallet=true:
      "has_wallet": true,
      "wallet": {
        "balance": 150000,
        "debited": 350000,
        "credited": 500000,
        "description": "balance = credited - debited"
      },
      // include_invoices=true:
      "invoices": [
        {
          "id": 88,
          "year": 2025,
          "month": 10,
          "billing_id": 1,
          "subtotal_required_amount": 500000,
          "discount_percent": 10,
          "total_required_amount": 450000,
          "total_paid_amount": 450000,
          "total_paid_percent": 100,
          "total_paid_percent_str": "100%",
          "remaining_amount": 0,
          "status": "paid",
          "created_by": "John Admin",
          "created_at": "2025-10-01T09:00:00.000Z"
        }
      ],
      // include_payments=true:
      "payments": [
        {
          "id": 55,
          "purpose": "invoice",
          "amount": 450000,
          "resolved_amount": 450000,
          "comment": null,
          "is_refund": false,
          "method": "cash",
          "created_by": "John Admin",
          "created_at": "2025-10-10T10:00:00.000Z"
        }
      ],
      // include_discounts=true:
      "discounts": [
        {
          "id": 3,
          "billing_id": 1,
          "name": "Sibling discount",
          "reason": "Has a sibling enrolled",
          "percent": 10,
          "start_date": "2025-09-01",
          "end_date": null,
          "created_by": "John Admin",
          "created_at": "2025-09-01T00:00:00.000Z",
          "updated_by": null,
          "updated_at": "2025-09-01T00:00:00.000Z"
        }
      ],
      // include_points=true:
      "total_points": 45,
      "points": [
        {
          "id": 10,
          "points": 5,
          "reason": "Good behavior",
          "date": "2025-10-15",
          "subject": "Math",
          "teacher": "Jane Teacher",
          "created_by": "Jane Teacher",
          "created_at": "2025-10-15T11:00:00.000Z"
        }
      ]
    }
  ]
}
```

### Error responses

| Status | Condition |
|---|---|
| `400 Bad Request` | `academic_year_id` is missing or does not exist |
| `400 Bad Request` | `filter` used without `include_group=true` |
| `400 Bad Request` | `include_payments=true` used without `include_group=true` |
| `400 Bad Request` | Sort by group-related field without `include_group=true` |
| `403 Forbidden` | Include flag used without the required permission |

---

## 2. GET /students/unassigned — List unassigned students

Returns students who are **not** currently assigned to any group (no `student_groups` record).

**Roles:** any authenticated user

> **Note:** This endpoint is declared after `GET /students/:id` in the controller. Requests to `/students/unassigned` will be matched by the `:id` route first and fail with a pipe error because "unassigned" is not a number. Use the full URL path `/students/unassigned` and ensure the routing order is handled correctly on any API gateway or proxy.

### Query parameters

Accepts the same parameters as the list endpoint (`GetManyStudentsDto`) but `academic_year_id` is optional since students are not filtered by year.

### Response

```jsonc
{
  "ok": true,
  "meta": {},
  "students": [
    {
      "student_id": 99,
      "full_name": "Bobur Karimov",
      "nickname": null,
      "status": "active",
      "created_by": "Jane Admin",
      "updated_by": null,
      "created_at": "2025-08-01T07:00:00.000Z",
      "updated_at": "2025-08-01T07:00:00.000Z",
      "has_joined_group": false
    }
  ]
}
```

---

## 3. GET /students/:id — Get one student

**Roles:** any authenticated user

### Path parameter

| Parameter | Type | Description |
|---|---|---|
| `id` | integer | Student ID |

### Query parameters

Same include flags as the list endpoint, without pagination or filter/sort:

| Parameter | Type | Default | Permission required |
|---|---|---|---|
| `include_wallet` | boolean | `false` | `can_view_wallet` |
| `include_group` | boolean | `false` | — |
| `include_billings` | boolean | `false` | `can_view_billings` |
| `include_invoices` | boolean | `false` | `can_view_invoices` |
| `include_payments` | boolean | `false` | `can_view_payments` |
| `include_discounts` | boolean | `false` | `can_view_discounts` |
| `include_points` | boolean | `false` | `can_view_points` |

### Response (found)

```jsonc
{
  "ok": true,
  "student": {
    // same shape as a single item in the list response
    "student_id": 12,
    "student_group_id": 7,
    "full_name": "Ali Valiyev",
    "nickname": "Ali",
    "status": "active",
    "created_by": "John Admin",
    "updated_by": null,
    "created_at": "2025-09-05T08:00:00.000Z",
    "updated_at": "2025-09-05T08:00:00.000Z",
    "academic_year_id": 3
    // + same optional include fields as the list endpoint
  }
}
```

### Response (not found)

```jsonc
{
  "ok": false,
  "error": "Student not found"
}
```

---

## 4. POST /students — Create student

**Roles:** `admin`, `moderator`

### Request body

```jsonc
{
  "la_id": "LA-2025-001",    // required — unique Lang Apex ID
  "full_name": "Ali Valiyev", // required
  "nickname": "Ali",          // optional
  "picture": "https://...",   // optional — URL to profile picture
  "status": "active",         // optional — e.g. "active", "blocked", "graduated"
  "info": {}                  // optional — arbitrary JSON object for extra metadata
}
```

### Response

```jsonc
{
  "ok": true,
  "student": {
    "id": 12,
    "uuid": "a1b2c3d4-...",
    "la_id": "LA-2025-001",
    "full_name": "Ali Valiyev",
    "nickname": "Ali",
    "picture": null,
    "status": "active",
    "info": {},
    "created_by": 5,
    "created_at": "2025-09-05T08:00:00.000Z",
    "updated_by": null,
    "updated_at": "2025-09-05T08:00:00.000Z"
  }
}
```

### Error responses

| Status | Condition |
|---|---|
| `400 Bad Request` | Validation error (missing `full_name`, wrong types) |
| `403 Forbidden` | Caller role is not `admin` or `moderator` |

---

## 5. PATCH /students/:id — Update student

**Roles:** `admin`, `moderator`

### Path parameter

| Parameter | Type | Description |
|---|---|---|
| `id` | integer | Student ID |

### Request body

All fields from `CreateStudentDto` are optional:

```jsonc
{
  "full_name": "Ali Valiyev Updated",
  "nickname": "Alisher",
  "picture": "https://...",
  "status": "graduated",
  "info": { "note": "moved to university" }
}
```

### Response (success)

```jsonc
{
  "ok": true,
  "student": {
    // full student entity, same as create response
    "id": 12,
    "la_id": "LA-2025-001",
    "full_name": "Ali Valiyev Updated",
    "status": "graduated",
    ...
  }
}
```

### Response (not found)

```jsonc
{
  "ok": false,
  "error": "Student not found"
}
```

---

## 6. POST /students/upload-v2 — Bulk import (Excel)

**Roles:** any authenticated user  
**Content-Type:** `multipart/form-data`

Enhanced import that **auto-creates groups** when they do not exist and inherits billing IDs from grade-level billing configs. Matches students by `la_id` (Lang Apex ID) instead of numeric ID.

### Request

Send as `multipart/form-data` with a field named `file`.

### Expected Excel columns

| Column | Aliases | Required | Description |
|---|---|---|---|
| `la_id` | `LA_ID` | yes | Unique Lang Apex student ID |
| `full_name` | `FullName` | yes | Student full name |
| `class` | `Class` | yes | Format: `10A` or `10-A` (grade + class letter) |
| `teacher` | `Teacher` | yes | Teacher full name (must match existing user) |
| `academic_year` | `AcademicYear` | yes | e.g. `2025-2026` |
| `id` | — | no | Internal DB ID (unused in v2, `la_id` is the key) |

### Response

```jsonc
{
  "ok": true,
  "inserted": 10,
  "updated": 5,
  "assigned": 10,
  "moved": 1,
  "skipped": 2,
  "errors": ["Missing references for la_id LA-999."]
}
```

### Error responses

| Status | Condition |
|---|---|
| `400 Bad Request` | No file uploaded |
| `400 Bad Request` | Empty file or no valid rows |
| `400 Bad Request` | Row-level validation error (missing field, bad format) |
| `400 Bad Request` | Academic year name not found in the database |
| `400 Bad Request` | Teacher name not found as a user in the database |

---

## 7. POST /students/assign-billings — Assign billings

Overwrites the billing plan of a student–group enrollment record.

**Roles:** `owner`, `admin`, `moderator`

### Request body

```jsonc
{
  "student_group_id": 7,         // required — the student_groups record ID
  "billing_ids": [1, 3]          // required — array of billing IDs to assign (replaces existing)
}
```

### Response

```jsonc
{
  "ok": true,
  "billing_ids": [1, 3]
}
```

### Error responses

| Status | Condition |
|---|---|
| `400 Bad Request` | `student_group_id` does not exist |

---

## 8. POST /students/assign-group — Assign student to group

Creates a new `student_groups` enrollment record. Automatically inherits billing IDs from the target group.

**Roles:** `owner`, `admin`, `moderator`

### Request body

```jsonc
{
  "student_id": 12,              // required
  "group_id": 5,                 // required
  "join_date": "2025-09-01"      // required — ISO date string
}
```

### Response

```jsonc
{
  "ok": true,
  "studentGroup": {
    "id": 34,
    "student_id": 12,
    "group_id": 5,
    "academic_year_id": 3,
    "join_date": "2025-09-01",
    "billing_ids": [1, 3],
    "created_by": 5,
    "created_at": "2025-09-05T08:00:00.000Z"
  }
}
```

### Error responses

| Status | Condition |
|---|---|
| `400 Bad Request` | Student not found |
| `400 Bad Request` | Group not found |
| `403 Forbidden` | Student is already assigned to this group |

---

## 9. POST /students/update-group — Move student to another group

Reassigns an existing enrollment record to a different group (updates `group_id` in `student_groups`).

**Roles:** `owner`, `admin`, `moderator`

### Request body

```jsonc
{
  "studentGroupId": 34,   // required — existing student_groups record ID
  "newGroupId": 8          // required — ID of the target group
}
```

### Response (success)

```jsonc
{
  "ok": true,
  "studentGroup": {
    "id": 34,
    "student_id": 12,
    "group_id": 8,
    "academic_year_id": 3,
    ...
  }
}
```

### Response (not found)

```jsonc
// studentGroupId not found:
{ "ok": false, "error": "Student is not assigned to the old group" }

// newGroupId not found:
{ "ok": false, "error": "New group not found" }
```

---

## 10. DELETE /students/remove-from-group — Remove student from group

Deletes the `student_groups` enrollment record, effectively un-enrolling the student from the group.

**Roles:** `owner`, `admin`, `moderator`

### Request body

```jsonc
{
  "student_id": 12,   // required
  "group_id": 5       // required
}
```

### Response (success)

```jsonc
{
  "ok": true
}
```

### Response (not found)

```jsonc
{
  "ok": false,
  "error": "Student is not assigned to the group"
}
```

---

## Permission summary

| Endpoint | Minimum role | Extra permissions |
|---|---|---|
| GET /students | any | `can_view_wallet`, `can_view_billings`, `can_view_invoices`, `can_view_payments`, `can_view_discounts`, `can_view_points` per include flag |
| GET /students/unassigned | any | — |
| GET /students/:id | any | same include-flag permissions as list |
| POST /students | `moderator` | — |
| PATCH /students/:id | `moderator` | — |
| POST /students/upload-v2 | any | — |
| POST /students/assign-billings | `moderator` | — |
| POST /students/assign-group | `moderator` | — |
| POST /students/update-group | `moderator` | — |
| DELETE /students/remove-from-group | `moderator` | — |

---

## Frontend integration notes

- **Always** pass `academic_year_id` when calling `GET /students` — it is required and the server returns `400` without it.
- Pass boolean include flags as the string `"true"` in query strings (e.g. `include_group=true`).
- Pass `filter` and `sort` as **URL-encoded JSON strings** in the query string.
- Use include flags selectively — each flag adds a database join or sub-query. Only request data you will display.
- `include_payments=true` also requires `include_group=true`; the server will return `400` otherwise.
- The `wallet.balance` field equals `wallet.credited - wallet.debited`. A positive balance means the student has a credit.
- Invoice `remaining_amount` = `total_required_amount - total_paid_amount`. Use `status` (`"paid"`, `"partial"`, `"unpaid"`) for quick display logic.
- For Excel uploads, validate the file client-side (non-empty, correct extension) before sending to avoid avoidable 400s.
- All successful mutation responses include `"ok": true`. Failed cases return `"ok": false` with an `"error"` string you can display to the user.
