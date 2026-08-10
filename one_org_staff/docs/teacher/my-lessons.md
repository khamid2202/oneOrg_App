# Teacher My Lessons API

**Base path:** `/teacher/my-lessons`

Return the authenticated teacher's lessons for a specific calendar day by looking up timetable entries assigned to that teacher.

## Auth
- Middleware: `AuthMiddleware`
- Middleware: `TeacherRoleMiddleware`
- Allowed roles: `teacher`

## Endpoint

### Get lessons for a day
- **GET** `/teacher/my-lessons`
- **Query:**
  - `date` (optional, ISO date string; defaults to today when omitted)
- **Behavior:**
  - resolves the requested day from `date`
  - looks up structured timetable rows where `teacher_id` matches the authenticated user
  - filters to the active academic year covering the requested date
  - sorts lessons by start time

## Example request
- **Method:** GET
- **Path:** `/teacher/my-lessons?date=2026-05-15`

## Example response
```json
{
  "ok": true,
  "lessons": [
    {
      "id": 91,
      "day": "Friday",
      "room": "A-12",
      "group_id": 7,
      "subject_id": 3,
      "grade": 6,
      "class": "B",
      "class_pair": "6-B",
      "class_pair_compact": "6B",
      "subject": "Mathematics",
      "time_slot": "08:30-09:15",
      "start_time": "08:30:00",
      "end_time": "09:15:00"
    }
  ]
}
```