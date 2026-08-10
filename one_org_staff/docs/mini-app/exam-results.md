# Mini App Exam Results API

**Base path:** `/mini-app/exam-results`

Student-scoped exam result history for the Telegram mini app.

## Exam results
- **GET** `/mini-app/exam-results?student_id=25`
- **Purpose:** list the current student's exam results with exam, subject, and exam-period metadata.
- **Auth:** required via mini app token middleware

### Query params
- `student_id` (required, int)
- `id` (optional, int)
- `exam_id` (optional, int)
- `start_date` (optional, ISO date string)
- `end_date` (optional, ISO date string)

### Behavior
- The middleware verifies the authenticated Telegram user is linked to `student_id`.
- Results are limited to the current student's own `exam_results` rows.
- `start_date` and `end_date` filter against the related exam-period date.
- Each result includes `percentage`, derived from `score / max_score`.

### Example response
```json
{
  "ok": true,
  "message": "Exam results retrieved successfully",
  "meta": {
    "student_id": 25,
    "total": 1,
    "exam_id": null,
    "start_date": null,
    "end_date": null
  },
  "result": [
    {
      "id": 305,
      "student_id": 25,
      "exam_id": 41,
      "score": 87,
      "percentage": 87,
      "created_at": "2026-05-20T12:30:00.000Z",
      "created_by": 4,
      "updated_at": null,
      "updated_by": null,
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
  ]
}
```