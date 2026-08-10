# Attendance API

**Base path:** `/attendance`

Manage attendance records by student group or by all students linked to a group.

## Auth
- Guard: `RolesGuard`
- Write operations require: `teacher` or `moderator`

## Endpoints

### Create attendance record
- **POST** `/attendance`
- **Body (CreateAttendanceDto):**
  - `student_group_id` (int, optional)
  - `group_id` (int, optional)
  - `date` (ISO date string, required)
  - `status` (`present` | `late` | `absent` | `excused`, optional, default `present`)
  - `reason` (string, optional, max 255)
- **Behavior:**
  - requires exactly one of `student_group_id` or `group_id`
  - when `student_group_id` is provided, creates one attendance record for that student group
  - when `group_id` is provided, creates attendance records for all active `student_groups` linked to that group on the requested date
  - validates target student group links exist
  - if an attendance record already exists for the same (`student_group_id`, `date`), updates that record instead of creating a duplicate
  - stores audit fields from authenticated user (`created_by`, `updated_by`)

### List attendance records
- **GET** `/attendance`
- **Query (GetAttendanceDto):**
  - `id` (int, optional)
  - `student_group_id` (int, optional)
  - `group_id` (int, optional)
  - `status` (`present` | `late` | `absent` | `excused`, optional)
  - `date` (ISO date string, optional, exact-day filter)
  - `start_date` (ISO date string, optional)
  - `end_date` (ISO date string, optional)
- **Response notes:**
  - `group_id` filters attendance records by joining the linked `student_groups` row
  - sorted by `date DESC`, then `id DESC`
  - returns `meta.total` and `result` list

### Get one attendance record
- **GET** `/attendance/:id`
- **Behavior:** returns one attendance record by `id`.

### Update attendance record
- **PATCH** `/attendance/:id`
- **Body (UpdateAttendanceDto):** partial of create fields.
- **Behavior:**
  - validates target record exists
  - validates student group if `student_group_id` changes
  - enforces uniqueness by (`student_group_id`, `date`)
  - updates audit fields (`updated_by`, `updated_at`)

### Delete attendance record
- **DELETE** `/attendance/:id`
- **Behavior:** deletes by `id` (returns `204`, throws if not found).

## Example request
- **Method:** POST
- **Path:** `/attendance`
- **Request body:**
```json
{
  "group_id": 4,
  "date": "2026-04-08",
  "status": "late",
  "reason": "Came after first period"
}
```

## Example response
```json
{
  "ok": true,
  "message": "Attendance records created successfully",
  "result": [
    {
      "id": 1,
      "student_group_id": 25,
      "date": "2026-04-08",
      "status": "late",
      "reason": "Came after first period",
      "created_by": 9,
      "created_at": "2026-04-08T09:40:14.482Z",
      "updated_by": 9,
      "updated_at": "2026-04-08T09:40:14.482Z"
    }
  ]
}
```
