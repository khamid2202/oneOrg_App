# Mini App Exam Periods API

**Base path:** `/mini-app/exam-periods`

Student-scoped exam period listing for the Telegram mini app.

## Exam periods
- **GET** `/mini-app/exam-periods?student_id=25`
- **Purpose:** list exam periods that have at least one exam assigned to a group the student belonged to on the exam-period date.
- **Auth:** required via mini app token middleware

### Query params
- `student_id` (required, int)
- `id` (optional, int)
- `academic_year_id` (optional, int)
- `is_active` (optional, bool)
- `accept_scores` (optional, bool)
- `start_date` (optional, ISO date string)
- `end_date` (optional, ISO date string)

### Behavior
- The middleware verifies the authenticated Telegram user is linked to `student_id`.
- `start_date` and `end_date` filter against `exam_periods.date`.
- The request is rejected when `start_date > end_date`.
- A period is visible only when there is at least one accessible exam for one of the student's groups on that exam date.

### Example response
```json
{
  "ok": true,
  "message": "Exam periods retrieved successfully",
  "meta": {
    "student_id": 25,
    "total": 2,
    "academic_year_id": null,
    "is_active": null,
    "accept_scores": null,
    "start_date": null,
    "end_date": null
  },
  "result": [
    {
      "id": 7,
      "academic_year_id": 3,
      "name": "Term 2 Finals",
      "description": "Second term final exams",
      "is_active": true,
      "accept_scores": true,
      "date": "2026-05-20",
      "created_at": "2026-05-01T08:10:00.000Z",
      "created_by": 4,
      "updated_at": null,
      "updated_by": null
    }
  ]
}
```