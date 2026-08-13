# APIs Overview

Docs are organized by audience, mirroring `src/service/`:

- **`public/`** — unauthenticated endpoints (no token required).
- **`mini-app/`** — Telegram mini app endpoints for students/parents (token-based).
- **`staff/`** — staff panel endpoints, gated by the granular permission layer
  (see [Authorization](AUTHORIZATION.md)).

## Public

- [Health](public/health.md)
- [Invoices](public/invoices.md)
- [Payments](public/payments.md)
- [Discounts](public/discounts.md)

## Mini App

- [Auth](mini-app/auth.md)
- [Attendance](mini-app/attendance.md)
- [Exams](mini-app/exams.md)
- [Exam Periods](mini-app/exam-periods.md)
- [Exam Results](mini-app/exam-results.md)
- [Points](mini-app/points.md)
- [Ranking](mini-app/ranking.md)
- [Schedule](mini-app/schedule.md)
- [Students](mini-app/students.md)

## Staff

- [Academic Years](staff/academic-years.md)
- [Attendance](staff/attendance.md)
- [Contacts](staff/contacts.md)
- [Discounts](staff/discounts.md)
- [Dorm Rooms](staff/dorm-rooms.md)
- [Dorm Students](staff/dorm-students.md)
- [Exams](staff/exams.md)
- [Exam Periods](staff/exam-periods.md)
- [Exam Results](staff/exam-results.md)
- [Groups](staff/groups.md)
- [Invoice Templates](staff/invoice-templates.md)
- [Invoices](staff/invoices.md)
- [My Lessons](staff/my-lessons.md)
- [Payments](staff/payments.md)
- [Persons](staff/persons.md)
- [Points](staff/points.md)
- [Roles](staff/roles.md)
- [Settings](staff/settings.md)
- [Students](staff/students.md)
- [Subjects](staff/subjects.md)
- [Time Slots](staff/time-slots.md)
- [Timetable](staff/timetable.md)
- [Users](staff/users.md)

### Staff · Health (medical records)

- [Dental Tests](staff/health/dental-tests.md)
- [Diagnoses](staff/health/diagnoses.md)
- [General Examinations](staff/health/general-examinations.md)
- [Lab Tests](staff/health/lab-tests.md)
- [Medical Books](staff/health/medical-books.md)
- [Medical Records](staff/health/medical-records.md)
- [Recommendations](staff/health/recommendations.md)
- [Sensory Tests](staff/health/sensory-tests.md)
- [Vital Signs](staff/health/vital-signs.md)

## Example request headers
```http
Authorization: Bearer <token>
Content-Type: application/json
```

## Example error response
```json
{
	"statusCode": 403,
	"message": "Forbidden",
	"error": "Forbidden"
}
```

## Frontend suggestions
- Centralize auth header injection and 401/403 handling.
- For list endpoints, keep filters and pagination in URL state for shareable views.
- Use `multipart/form-data` for upload endpoints with a `file` field.
