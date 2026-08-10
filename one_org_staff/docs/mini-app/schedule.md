# Mini App Schedule API

**Base path:** `/mini-app/schedule`

Student scheduling endpoints for the Telegram mini app.

## Schedule by date
- **GET** `/mini-app/schedule?student_id=25&date=2026-05-12`
- **Purpose:** return schedule lessons for a token-linked student on a requested date.
- **Auth:** required via mini app token middleware

### Behavior
- Requires `student_id` so middleware can verify that the authenticated Telegram user is linked to that student.
- Requires a `date` query in `YYYY-MM-DD` format.
- Resolves lessons only for the requested day and only from active student groups whose academic year is active for that date.
- Responses are cached briefly in Redis per `student_id` and date to reduce repeated database reads.

### Example response
```json
{
  "ok": true,
  "message": "Schedule resolved successfully",
  "result": {
    "date": "2026-05-12",
    "day": "Tuesday",
    "day_index": 2,
    "student_id": 25,
    "lessons": [
      {
        "id": 94,
        "day": "Tuesday",
        "day_index": 2,
        "lesson_type": "structured",
        "text": null,
        "room": "205",
        "group_id": 14,
        "student_group_id": 77,
        "academic_year_id": 3,
        "group_name": "Grade 7 - A",
        "grade": 7,
        "class": "A",
        "class_pair": "7-A",
        "class_pair_compact": "7A",
        "time_id": 3,
        "time_slot": "Third Slot",
        "start_time": "10:00:00",
        "end_time": "10:45:00",
        "subject_id": 9,
        "teacher_id": 21,
        "subject": "Physics",
        "teacher": "Jane Doe"
      }
    ]
  }
}
```

## Today's lessons
- **GET** `/mini-app/schedule/today-lessons?student_id=25`
- **Purpose:** return today's timetable lessons for a token-linked student.
- **Auth:** required via mini app token middleware

### Behavior
- Requires `student_id` in the request so middleware can verify that the authenticated Telegram user is linked to that student.
- Resolves only lessons for today based on the server date.
- Includes timetable entries from the student's active groups whose academic year is currently active for today's date.
- Responses are cached briefly in Redis per `student_id` and current date.

### Example response
```json
{
  "ok": true,
  "message": "Today's lessons resolved successfully",
  "result": {
    "date": "2026-05-10",
    "day": "Sunday",
    "day_index": 0,
    "student_id": 25,
    "lessons": [
      {
        "id": 91,
        "day": "Sunday",
        "day_index": 0,
        "lesson_type": "structured",
        "text": null,
        "room": "201",
        "group_id": 14,
        "student_group_id": 77,
        "academic_year_id": 3,
        "group_name": "Grade 7 - A",
        "grade": 7,
        "class": "A",
        "class_pair": "7-A",
        "class_pair_compact": "7A",
        "time_id": 2,
        "time_slot": "Second Slot",
        "start_time": "09:00:00",
        "end_time": "09:45:00",
        "subject_id": 6,
        "teacher_id": 18,
        "subject": "Mathematics",
        "teacher": "John Smith"
      }
    ]
  }
}
```