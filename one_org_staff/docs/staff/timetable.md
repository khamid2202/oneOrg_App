# Timetable API

**Base path:** `/timetable`

Manage timetable import, entries, and retrieval.

## Auth
- Guard: `RolesGuard` + permission checks via `@RequirePermissions`.
- Permissions:
  - Create / upload: `timetable.create`
  - Update: `timetable.update`
  - Delete: `timetable.delete`
  - Read (list, my-lessons): authenticated

## Endpoints

| Method | Path | Description | Permission |
| --- | --- | --- | --- |
| GET | `/timetable` | Get timetable (filtered) | authenticated |
| POST | `/timetable/upload` | Import from Excel | `timetable.create` |
| POST | `/timetable` | Create an entry | `timetable.create` |
| PATCH | `/timetable/:id` | Update an entry | `timetable.update` |
| DELETE | `/timetable/:id` | Delete an entry | `timetable.delete` |
| GET | `/timetable/my-lessons` | Current user's lessons for a day | authenticated |

### Get timetable
- **GET** `/timetable`
- **Query (GetTimetableDto):** optional `academic_year_id`; arrays
  `teacher_ids`, `group_ids`, `subject_ids`, `time_ids`, `days`; optional `sort`
  array `{ field, order }`.
- Structured lessons include `subject`/`teacher` fields; text lessons return
  `text` and omit teacher/subject. Default order: day, grade, class.

**Example request**
```http
GET /timetable?academic_year_id=1&group_ids=[5]&days=[1]
```

**Example response**
```json
{
  "ok": true,
  "message": "Timetable fetched successfully",
  "meta": { "total": 2 },
  "timetable": [
    {
      "id": 10,
      "day": "Monday",
      "day_index": 1,
      "lesson_type": "structured",
      "text": null,
      "room": "A-12",
      "group_id": 5,
      "time_id": 2,
      "grade": 10,
      "class": "A",
      "class_pair": "10-A",
      "class_pair_compact": "10A",
      "time_slot": "2nd lesson",
      "start_time": "08:30:00",
      "end_time": "09:15:00",
      "created_by": "Admin User",
      "updated_by": null,
      "created_at": "2026-01-10T08:00:00.000Z",
      "updated_at": null,
      "subject_id": 3,
      "teacher_id": 12,
      "subject": "Math",
      "teacher": "John Doe"
    },
    {
      "id": 11,
      "day": "Monday",
      "day_index": 1,
      "lesson_type": "text",
      "text": "Class meeting and planning",
      "room": "Hall",
      "group_id": 5,
      "time_id": 3,
      "grade": 10,
      "class": "A",
      "class_pair": "10-A",
      "class_pair_compact": "10A",
      "time_slot": "3rd lesson",
      "start_time": "09:25:00",
      "end_time": "10:10:00",
      "created_by": "Admin User",
      "updated_by": null,
      "created_at": "2026-01-10T08:00:00.000Z",
      "updated_at": null
    }
  ]
}
```

### Upload timetable (Excel)
- **POST** `/timetable/upload`
- **Body:** `multipart/form-data` with `file` plus `ImportTimetableDto`
  (`academic_year_id` required, int 1-9999). `400` if the file is missing.
- **Lesson mode in file:** each lesson cell supports either:
  - structured lesson: subject in lesson row + teacher in next row
  - text lesson: prefix lesson value with `text:` (example: `text: Exam week`)
    or leave teacher empty and provide plain text value

**Example request**
```http
POST /timetable/upload
Content-Type: multipart/form-data; boundary=----X

------X
Content-Disposition: form-data; name="academic_year_id"

1
------X
Content-Disposition: form-data; name="file"; filename="timetable.xlsx"
Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet

<binary>
------X--
```

**Example response**
```json
{
  "ok": true,
  "inserted": 120,
  "updated": 6,
  "skipped": 4
}
```

### Create timetable entry
- **POST** `/timetable`
- **Body (CreateTimetableDto):**
  - common required: `academic_year_id`, `group_id`, `day` (0-6), `time_id`, `lesson_type` (`structured` or `text`)
  - when `lesson_type=structured`: require `subject_id` and `teacher_id`; `text` must be omitted
  - when `lesson_type=text`: require `text`; `subject_id` and `teacher_id` must be omitted
  - optional: `room`
- Slot uniqueness: one entry per `(academic_year_id, group_id, day, time_id)`.

**Example request (structured)**
```json
{
  "academic_year_id": 1,
  "group_id": 5,
  "day": 1,
  "time_id": 2,
  "lesson_type": "structured",
  "subject_id": 3,
  "teacher_id": 12,
  "room": "A-12"
}
```

**Example request (text)**
```json
{
  "academic_year_id": 1,
  "group_id": 5,
  "day": 1,
  "time_id": 3,
  "lesson_type": "text",
  "text": "Class meeting and planning",
  "room": "Hall"
}
```

**Example response**
```json
{
  "ok": true,
  "message": "Timetable entry created successfully",
  "timetable": {
    "id": 10,
    "day": "Monday",
    "day_index": 1,
    "lesson_type": "structured",
    "text": null,
    "room": "A-12",
    "group_id": 5,
    "time_id": 2,
    "grade": 10,
    "class": "A",
    "class_pair": "10-A",
    "class_pair_compact": "10A",
    "time_slot": "2nd lesson",
    "start_time": "08:30:00",
    "end_time": "09:15:00",
    "subject_id": 3,
    "teacher_id": 12,
    "subject": "Math",
    "teacher": "John Doe"
  }
}
```

### Update timetable entry
- **PATCH** `/timetable/:id`
- **Body (UpdateTimetableDto):** partial fields, but final lesson state must
  still follow mutual exclusivity:
  - structured lesson: `subject_id` + `teacher_id`, no `text`
  - text lesson: `text`, no `subject_id`/`teacher_id`

**Example request**
```http
PATCH /timetable/10
```
```json
{
  "room": "B-07"
}
```

**Example response**
```json
{
  "ok": true,
  "message": "Timetable entry updated successfully",
  "timetable": {
    "id": 10,
    "day": "Monday",
    "day_index": 1,
    "lesson_type": "structured",
    "room": "B-07",
    "group_id": 5,
    "time_id": 2,
    "subject_id": 3,
    "teacher_id": 12,
    "subject": "Math",
    "teacher": "John Doe"
  }
}
```

### Delete timetable entry
- **DELETE** `/timetable/:id`
- Returns **204 No Content** (empty body).

**Example request**
```http
DELETE /timetable/10
```

### Get my lessons
- **GET** `/timetable/my-lessons`
- **Query:** optional `date` (ISO string; defaults to today).
- Scoped to the authenticated user (teacher) and the active academic year
  covering the date; sorted by start time.

**Example request**
```http
GET /timetable/my-lessons?date=2026-05-15
```

**Example response**
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

## Frontend suggestions
- Use consistent day/time mappings to render grids.
- After upload, refresh the timetable view automatically.
