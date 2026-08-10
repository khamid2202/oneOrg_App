# Protected APIs Overview

Public docs:

- [Mini App Auth](../mini-app/auth.md)
- [Mini App Students](../mini-app/students.md)

Docs for protected modules live in this folder, with health docs grouped under `health/`:

- [Academic Years](academic-years.md)
- [Attendance](attendance.md)
- [Billings](billings.md)
- [Contacts](contacts.md)
- [Dental Tests](health/dental-tests.md)
- [Diagnoses](health/diagnoses.md)
- [Discounts](discounts.md)
- [Dorm Rooms](dorm-rooms.md)
- [Dorm Students](dorm-students.md)
- [Exams](exams.md)
- [Exam Results](exam-results.md)
- [General Examinations](health/general-examinations.md)
- [Groups](groups.md)
- [Invoices](invoices.md)
- [Lab Tests](health/lab-tests.md)
- [Medical Books](health/medical-books.md)
- [Medical Records](health/medical-records.md)
- [Payments](payments.md)
- [Points](points.md)
- [Recommendations](health/recommendations.md)
- [Sensory Tests](health/sensory-tests.md)
- [Students](students.md)
- [Subjects](subjects.md)
- [Timetable](timetable.md)
- [Users](users.md)
- [Vital Signs](health/vital-signs.md)
- [Time Slots](time-slots.md)
- [My Account](my-account.md)
- [Settings](settings.md)

Auth: Most controllers use `RolesGuard` with role checks on mutations; some (users) perform inline admin checks. Upload routes expect `multipart/form-data` with `file`.

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
