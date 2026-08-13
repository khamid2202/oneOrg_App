# Attendance API

**Base path:** `/attendance`

Manage attendance records per student enrollment, or in bulk for a whole group.

## Auth
- Guard: `RolesGuard` + permission checks via `@RequirePermissions`.
- Permissions:
  - Create: `attendance.create`
  - Update: `attendance.update`
  - Delete: `attendance.delete`
  - Read (list, statistics, get one): authenticated

## Endpoints

| Method | Path | Description | Permission |
| --- | --- | --- | --- |
| GET | `/attendance` | List attendance records | authenticated |
| GET | `/attendance/statistics` | Status breakdown summary | authenticated |
| GET | `/attendance/statistics/trend` | Breakdown per date | authenticated |
| GET | `/attendance/statistics/by-student` | Breakdown per student | authenticated |
| GET | `/attendance/statistics/by-group` | Breakdown per group | authenticated |
| GET | `/attendance/:id` | Get one record | authenticated |
| POST | `/attendance` | Create (or upsert) records | `attendance.create` |
| PATCH | `/attendance/:id` | Update a record | `attendance.update` |
| DELETE | `/attendance/:id` | Delete a record | `attendance.delete` |

### List attendance records
- **GET** `/attendance`
- **Query (GetAttendanceDto), all optional:** `id`, `student_id`, `group_id`
  (joins through the student's group), `status`
  (`present|late|absent|excused`), `date` (exact day), `start_date` /
  `end_date` (inclusive range).
- Sorted by `date DESC`, then `id DESC`; `created_by` / `updated_by` are
  resolved to user full names.

**Example request**
```http
GET /attendance?group_id=4&date=2026-04-08
```

**Example response**
```json
{
  "ok": true,
  "message": "Attendance records retrieved successfully",
  "meta": { "total": 1 },
  "result": [
    {
      "id": 501,
      "student_id": 25,
      "date": "2026-04-08",
      "status": "late",
      "reason": "Came after first period",
      "created_at": "2026-04-08T09:40:14.482Z",
      "created_by": "Nodir Rasulov",
      "updated_at": "2026-04-08T09:40:14.482Z",
      "updated_by": "Nodir Rasulov"
    }
  ]
}
```

## Statistics

All `/attendance/statistics*` endpoints share the same optional filters
(`GetAttendanceStatisticsDto`): `student_id`, `group_id`, `date`,
`start_date` / `end_date`. Every bucket carries the status breakdown
`{ total, present, late, absent, excused, attendance_rate, absence_rate }` —
rates are percentages (2 decimals); present+late count as attended. Responses
echo the filters under `meta` (unused ones as `null`); grouped endpoints add
`meta.total` = number of buckets. `meta` examples below are abbreviated.

### Summary
- **GET** `/attendance/statistics`

**Example request**
```http
GET /attendance/statistics?group_id=4&start_date=2026-04-01&end_date=2026-04-30
```

**Example response**
```json
{
  "ok": true,
  "message": "Attendance statistics retrieved successfully",
  "meta": {
    "group_id": 4, "student_id": null,
    "date": null, "start_date": "2026-04-01", "end_date": "2026-04-30"
  },
  "result": {
    "total": 480,
    "present": 430,
    "late": 20,
    "absent": 18,
    "excused": 12,
    "attendance_rate": 93.75,
    "absence_rate": 6.25
  }
}
```

### Trend
- **GET** `/attendance/statistics/trend`
- `result`: one breakdown per `date`, ascending.

**Example request**
```http
GET /attendance/statistics/trend?group_id=4
```

**Example response**
```json
{
  "ok": true,
  "message": "Attendance trend retrieved successfully",
  "meta": { "group_id": 4, "total": 2 },
  "result": [
    { "date": "2026-04-07", "total": 24, "present": 22, "late": 1, "absent": 1, "excused": 0, "attendance_rate": 95.83, "absence_rate": 4.17 },
    { "date": "2026-04-08", "total": 24, "present": 21, "late": 2, "absent": 0, "excused": 1, "attendance_rate": 95.83, "absence_rate": 4.17 }
  ]
}
```

### By student
- **GET** `/attendance/statistics/by-student`
- `result`: one breakdown per student (`student_id`, `person_id`, `full_name`),
  ordered by name.

**Example request**
```http
GET /attendance/statistics/by-student?group_id=4
```

**Example response**
```json
{
  "ok": true,
  "message": "Attendance statistics by student retrieved successfully",
  "meta": { "group_id": 4, "total": 1 },
  "result": [
    {
      "student_id": 25,
      "person_id": 100,
      "full_name": "Ali Valiyev",
      "total": 20,
      "present": 18,
      "late": 1,
      "absent": 1,
      "excused": 0,
      "attendance_rate": 95,
      "absence_rate": 5
    }
  ]
}
```

### By group
- **GET** `/attendance/statistics/by-group`
- `result`: one breakdown per group (`group_id`, `group_name`, `grade`,
  `class`, `class_pair`), ordered by grade then class.

**Example request**
```http
GET /attendance/statistics/by-group?date=2026-04-08
```

**Example response**
```json
{
  "ok": true,
  "message": "Attendance statistics by group retrieved successfully",
  "meta": { "date": "2026-04-08", "total": 1 },
  "result": [
    {
      "group_id": 4,
      "group_name": "6B",
      "grade": 6,
      "class": "B",
      "class_pair": "6-B",
      "total": 24,
      "present": 21,
      "late": 2,
      "absent": 0,
      "excused": 1,
      "attendance_rate": 95.83,
      "absence_rate": 4.17
    }
  ]
}
```

### Get one attendance record
- **GET** `/attendance/:id`
- `404` if not found.

**Example request**
```http
GET /attendance/501
```

**Example response**
```json
{
  "ok": true,
  "message": "Attendance record retrieved successfully",
  "result": {
    "id": 501,
    "student_id": 25,
    "date": "2026-04-08",
    "status": "late",
    "reason": "Came after first period",
    "created_at": "2026-04-08T09:40:14.482Z",
    "created_by": "Nodir Rasulov",
    "updated_at": "2026-04-08T09:40:14.482Z",
    "updated_by": "Nodir Rasulov"
  }
}
```

### Create attendance record(s)
- **POST** `/attendance`
- **Body (CreateAttendanceDto):**
  - `student_id` (int, optional) **or** `group_id` (int, optional) — exactly one
    is required.
  - `date` (ISO date string, required)
  - `status` (`present|late|absent|excused`, optional, default `present`)
  - `reason` (string, optional, max 255, trimmed)
- **Behavior:** with `group_id`, records are created for every active enrollment
  in the group. If a record already exists for the same `(student_id, date)` it
  is updated instead (the message reflects created/updated). `result` is a
  single object for single-student requests and an array for group requests.

**Example request (whole group)**
```json
{
  "group_id": 4,
  "date": "2026-04-08",
  "status": "present"
}
```

**Example response**
```json
{
  "ok": true,
  "message": "Attendance records created successfully",
  "result": [
    {
      "id": 501,
      "student_id": 25,
      "date": "2026-04-08",
      "status": "present",
      "reason": null,
      "created_by": 9,
      "created_at": "2026-04-08T09:40:14.482Z"
    },
    {
      "id": 502,
      "student_id": 26,
      "date": "2026-04-08",
      "status": "present",
      "reason": null,
      "created_by": 9,
      "created_at": "2026-04-08T09:40:14.482Z"
    }
  ]
}
```

### Update attendance record
- **PATCH** `/attendance/:id`
- **Body (UpdateAttendanceDto):** partial of the create fields. `404` if the
  record is missing; `400` if the body is empty; enforces uniqueness by
  `(student_id, date)`.

**Example request**
```http
PATCH /attendance/501
```
```json
{
  "status": "excused",
  "reason": "Doctor's appointment"
}
```

**Example response**
```json
{
  "ok": true,
  "message": "Attendance record updated successfully",
  "result": {
    "id": 501,
    "student_id": 25,
    "date": "2026-04-08",
    "status": "excused",
    "reason": "Doctor's appointment",
    "created_by": 9,
    "created_at": "2026-04-08T09:40:14.482Z",
    "updated_by": 9,
    "updated_at": "2026-04-08T11:00:00.000Z"
  }
}
```

### Delete attendance record
- **DELETE** `/attendance/:id`
- Returns `204 No Content` (empty body); `404` if not found.

**Example request**
```http
DELETE /attendance/501
```
