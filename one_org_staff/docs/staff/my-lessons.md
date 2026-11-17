# Teacher My Lessons API

**Base path:** `/my-lessons`

Return the authenticated teacher's lessons for a specific calendar day by looking up timetable entries assigned to that teacher.

## Auth
- Middleware: `AuthMiddleware`
- Middleware: `TeacherRoleMiddleware`
- Allowed roles: `teacher`

## Endpoint

### Get lessons for a day
- **GET** `/my-lessons`
- **Query:**
  - `date` (optional, ISO date string; defaults to today when omitted)
  - `timetable_version_id` (optional; defaults to the academic year's published timetable version)
- **Behavior:**
  - resolves the requested day from `date`
  - looks up structured timetable rows where the authenticated user is either the
    **primary teacher** (`teacher_id`) or an **additional teacher** (via the `timetable_teachers` join table)
  - filters to the active academic year covering the requested date
  - `start_time`/`end_time` come from the class's bell-schedule period
    (`period_id`, `period_number`), falling back to the time slot's times;
    `room_id` is included next to `room`
  - sorts lessons by start time
  - also returns `meetings`: the teacher's active
    [teacher meetings](timetable-meetings.md) on that date (its weekday, inside
    the academic year, not on a holiday), at any branch. Meetings are not
    lessons and have no instance, attendance or grading.

A choice option's rows in several classes come back as one lesson: `id` is the row
of the lowest group id, `group_ids` lists the classes, and `class_pair` /
`class_pair_compact` join them (`10-A + 10-B`, `10A+10B`). `/my-lessons` and
`/timetable/my-lessons` return the same `id`.

## Example request
- **Method:** GET
- **Path:** `/my-lessons?date=2026-05-15`

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