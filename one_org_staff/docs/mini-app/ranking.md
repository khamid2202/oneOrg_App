# Mini App Ranking API

**Base path:** `/mini-app/ranking`

Student group points ranking endpoint for the Telegram mini app.

## Group ranking
- **GET** `/mini-app/ranking?student_id=25&start_date=2026-05-01&end_date=2026-05-31`
- **Purpose:** resolve the student's group for the requested date range, total points for every student in that group, rank them, and return the current student's rank in `meta`.
- **Auth:** required via mini app token middleware

### Behavior
- `student_id`, `start_date`, and `end_date` are required.
- The middleware verifies the authenticated Telegram user is linked to `student_id`.
- The endpoint selects the latest student group membership overlapping `start_date..end_date`.
- All students whose membership in that group overlaps the date range are included, even when they have zero point records.
- Point rows whose `reason` is `change to Dollars` or `change to Points` are excluded from ranking totals and point-record counts.
- Ranking uses shared ranks for ties, ordered by `total_points DESC`.
- Responses are cached briefly in Redis per resolved `group_id` and date range so classmates reuse the same cached ranking. Staff-side point writes invalidate cached rankings.

### Example response
```json
{
  "ok": true,
  "message": "Ranking resolved successfully",
  "meta": {
    "student_id": 25,
    "start_date": "2026-05-01",
    "end_date": "2026-05-31",
    "total_students": 2,
    "current_student_rank": 1,
    "current_student_points": 18,
    "group": {
      "id": 14,
      "name": "Grade 7 - A",
      "grade": 7,
      "class": "A",
      "class_pair": "7-A",
      "class_pair_compact": "7A",
      "teacher_name": "Jane Doe"
    }
  },
  "ranking": [
    {
      "rank": 1,
      "student_id": 25,
      "la_id": "LA-00025",
      "full_name": "Ali Valiyev",
      "nickname": "Ali",
      "picture": "https://cdn.example.com/students/25.jpg",
      "status": "active",
      "student_group_id": 77,
      "total_points": 18,
      "point_records": 4,
      "is_current_student": true
    },
    {
      "rank": 2,
      "student_id": 26,
      "la_id": "LA-00026",
      "full_name": "Vali Aliyev",
      "nickname": null,
      "picture": null,
      "status": "active",
      "student_group_id": 78,
      "total_points": 12,
      "point_records": 3,
      "is_current_student": false
    }
  ]
}
```