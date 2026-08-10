# Mini App Exams API

**Base path:** `/mini-app/exams`

Student-scoped exam listing and per-exam ranking for the Telegram mini app.

## Exams
- **GET** `/mini-app/exams?student_id=25`
- **Purpose:** list exams available to the student from their group memberships and include the current student's own result summary when it exists.
- **Auth:** required via mini app token middleware

### Query params
- `student_id` (required, int)
- `id` (optional, int)
- `exam_period_id` (optional, int)
- `subject_id` (optional, int)
- `start_date` (optional, ISO date string)
- `end_date` (optional, ISO date string)

### Behavior
- The middleware verifies the authenticated Telegram user is linked to `student_id`.
- Exams are visible only when the student belonged to one of `exam.group_ids` on the exam-period date.
- `start_date` and `end_date` filter against the related exam-period date.
- The current student's own result is embedded as `current_result_id`, `current_score`, and `current_percentage` when a result exists.

### Example response
```json
{
  "ok": true,
  "message": "Exams retrieved successfully",
  "meta": {
    "student_id": 25,
    "total": 1,
    "exam_period_id": null,
    "subject_id": null,
    "start_date": null,
    "end_date": null
  },
  "result": [
    {
      "id": 41,
      "exam_period_id": 7,
      "academic_year_id": 3,
      "exam_period_name": "Term 2 Finals",
      "exam_period_description": "Second term final exams",
      "exam_period_date": "2026-05-20",
      "exam_period_is_active": true,
      "exam_period_accept_scores": true,
      "subject_id": 12,
      "subject_name": "Mathematics",
      "group_ids": [18],
      "max_score": 100,
      "current_result_id": 305,
      "current_score": 87,
      "current_percentage": 87,
      "created_at": "2026-05-01T08:10:00.000Z",
      "created_by": 4,
      "updated_at": null,
      "updated_by": null
    }
  ]
}
```

## Exam ranking
- **GET** `/mini-app/exams/ranking?student_id=25&exam_id=41`
- **Purpose:** compare students' recorded results for a specific exam and return the current student's rank in `meta`.

### Behavior
- The exam must be accessible to the requesting student through group membership on the exam-period date.
- `exam_id` is resolved exactly; if that specific exam is not accessible to the requesting student, the endpoint returns `404 Exam not found`.
- Ranking includes students who have an `exam_results` row for that exam and whose membership matches one of the exam groups on the exam date.
- Ties share the same rank, ordered by `score DESC`.

### Example response
```json
{
  "ok": true,
  "message": "Exam ranking resolved successfully",
  "meta": {
    "student_id": 25,
    "exam_id": 41,
    "total_students": 3,
    "current_student_rank": 2,
    "current_student_score": 87,
    "current_student_percentage": 87,
    "exam": {
      "id": 41,
      "exam_period_id": 7,
      "academic_year_id": 3,
      "exam_period_name": "Term 2 Finals",
      "exam_period_description": "Second term final exams",
      "exam_period_date": "2026-05-20",
      "exam_period_is_active": true,
      "exam_period_accept_scores": true,
      "subject_id": 12,
      "subject_name": "Mathematics",
      "group_ids": [18],
      "max_score": 100
    }
  },
  "ranking": [
    {
      "rank": 1,
      "exam_result_id": 304,
      "student_id": 24,
      "la_id": "LA-00024",
      "full_name": "Akmal Ergashev",
      "nickname": null,
      "picture": null,
      "status": "active",
      "score": 92,
      "percentage": 92,
      "is_current_student": false
    },
    {
      "rank": 2,
      "exam_result_id": 305,
      "student_id": 25,
      "la_id": "LA-00025",
      "full_name": "Ali Valiyev",
      "nickname": "Ali",
      "picture": null,
      "status": "active",
      "score": 87,
      "percentage": 87,
      "is_current_student": true
    }
  ]
}
```