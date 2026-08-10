# Mini App Attendance API

**Base path:** `/mini-app/attendance`

Student attendance history endpoint for the Telegram mini app.

## Attendance history
- **GET** `/mini-app/attendance?student_id=25&page=1&limit=20`
- **Purpose:** return attendance history for a token-linked student across the student's student-group records.
- **Auth:** required via mini app token middleware

### Query params
- `student_id` is required so middleware can verify that the authenticated Telegram user is linked to that student.
- `page` and `limit` are optional and default to `1` and `20`.
- `student_group_id`, `status`, `date`, `start_date`, and `end_date` are optional filters.
- Responses are cached briefly in Redis per `student_id` and filter set. Staff-side attendance writes invalidate the cached attendance history.

### Example response
```json
{
  "ok": true,
  "message": "Attendance history retrieved successfully",
  "meta": {
    "student_id": 25,
    "total": 4,
    "page": 1,
    "limit": 20,
    "student_group_id": null,
    "status": null,
    "date": null,
    "start_date": null,
    "end_date": null
  },
  "attendance": [
    {
      "id": 401,
      "student_group_id": 77,
      "group_id": 14,
      "status": "late",
      "reason": "Came after first period",
      "date": "2026-05-08",
      "grade": 7,
      "class": "A",
      "class_pair": "7-A",
      "class_pair_compact": "7A",
      "teacher_name": "Jane Doe",
      "created_at": "2026-05-08T08:12:44.000Z",
      "updated_at": "2026-05-08T08:12:44.000Z"
    }
  ]
}
```