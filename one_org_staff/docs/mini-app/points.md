# Mini App Points API

**Base path:** `/mini-app/points`

Student points history endpoint for the Telegram mini app.

## Points progress
- **GET** `/mini-app/points/progress?student_id=25`
- **Purpose:** return the student's points aggregated by date so the mini app can render progress over time.
- **Auth:** required via mini app token middleware

### Query params
- `student_id` is required so middleware can verify that the authenticated Telegram user is linked to that student.
- `group_id`, `subject_id`, `start_date`, and `end_date` are optional filters.
- Point rows whose `reason` is `change to Dollars` or `change to Points` are excluded from both history and progress totals.
- Responses are cached briefly in Redis per `student_id` and filter set. Staff-side point writes invalidate the cached point progress too.

### Example response
```json
{
  "ok": true,
  "message": "Points progress retrieved successfully",
  "meta": {
    "student_id": 25,
    "total_dates": 3,
    "total_point_records": 4,
    "total_points": 18,
    "group_id": null,
    "subject_id": null,
    "start_date": null,
    "end_date": null
  },
  "progress": [
    {
      "date": "2026-05-01",
      "total_points": 5,
      "point_records": 1
    },
    {
      "date": "2026-05-08",
      "total_points": 13,
      "point_records": 3
    }
  ]
}
```

## Points history
- **GET** `/mini-app/points?student_id=25&page=1&limit=20`
- **Purpose:** return point history for a token-linked student and expose the student's total points in `meta.total_points`.
- **Auth:** required via mini app token middleware

### Query params
- `student_id` is required so middleware can verify that the authenticated Telegram user is linked to that student.
- `page` and `limit` are optional and default to `1` and `20`.
- `group_id`, `subject_id`, `start_date`, and `end_date` are optional filters.
- Point rows whose `reason` is `change to Dollars` or `change to Points` are excluded from the returned history and `meta.total_points`.
- Responses are cached briefly in Redis per `student_id` and filter set. Staff-side point writes invalidate the cached point history.

### Example response
```json
{
  "ok": true,
  "message": "Points history retrieved successfully",
  "meta": {
    "student_id": 25,
    "total": 4,
    "total_points": 18,
    "page": 1,
    "limit": 20,
    "group_id": null,
    "subject_id": null,
    "start_date": null,
    "end_date": null
  },
  "points": [
    {
      "id": 401,
      "student_id": 25,
      "group_id": 14,
      "subject_id": 9,
      "subject_name": "Physics",
      "points": 5,
      "reason": "Homework",
      "date": "2026-05-08",
      "grade": 7,
      "class": "A",
      "class_pair": "7-A",
      "class_pair_compact": "7A",
      "teacher_name": "Jane Doe",
      "created_at": "2026-05-08T08:12:44.000Z"
    }
  ]
}
```