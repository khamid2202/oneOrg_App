# Timetable API

**Base path:** `/timetable`

Manage timetable import and retrieval.

## Auth
- Guard: `RolesGuard`
- Roles:
  - Create/Update/Delete: `owner`, `admin`
  - Upload: `owner`, `admin`, `moderator`
  - Read: authenticated

## Endpoints

### Get timetable
- **GET** `/timetable`
- **Query (GetTimetableDto):** optional `academic_year_id`; arrays `teacher_ids`, `group_ids`, `subject_ids`, `time_ids`, `days`; optional `sort` array `{ field, order }`.

### Upload timetable (Excel)
- **POST** `/timetable/upload`
- **Body:** `multipart/form-data` with `file` plus `ImportTimetableDto` (`academic_year_id` required, int 1-9999).
- **Lesson mode in file:** each lesson cell supports either:
  - structured lesson: subject in lesson row + teacher in next row
  - text lesson: prefix lesson value with `text:` (example: `text: Exam week`) or leave teacher empty and provide plain text value
- **Roles:** `owner`, `admin`, `moderator`.

### Create timetable entry
- **POST** `/timetable`
- **Body (CreateTimetableDto):**
  - common required: `academic_year_id`, `group_id`, `day` (0-6), `time_id`, `lesson_type` (`structured` or `text`)
  - when `lesson_type=structured`: require `subject_id` and `teacher_id`; `text` must be omitted
  - when `lesson_type=text`: require `text`; `subject_id` and `teacher_id` must be omitted
  - optional: `room`
- **Roles:** `owner`, `admin`.

### Update timetable entry
- **PATCH** `/timetable/:id`
- **Body (UpdateTimetableDto):** partial fields, but final lesson state must still follow mutual exclusivity:
  - structured lesson: `subject_id` + `teacher_id`, no `text`
  - text lesson: `text`, no `subject_id`/`teacher_id`
- **Roles:** `owner`, `admin`.

### Delete timetable entry
- **DELETE** `/timetable/:id`
- **Roles:** `owner`, `admin`.

### Get my lessons
- **GET** `/timetable/my-lessons`
- **Query:** optional `date` (ISO string).
- **Auth:** uses `UserId` decorator to scope to current user.

## Usage notes
- Upload rejects missing file; returns `{ ok: true, ...result }` on success.
- `my-lessons` derives schedule for the authenticated user.
- Slot uniqueness is still one entry per `(academic_year_id, group_id, day, time_id)`.
- Text lesson responses return text-focused fields and do not include teacher/subject fields.

## Example requests
- **Method:** POST
- **Path:** `/timetable`
- **Structured body:**
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
- **Text body:**
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

## Example response
```json
{
  "ok": true,
  "timetable": [
    {
      "id": 10,
      "day": "Monday",
      "day_index": 1,
      "lesson_type": "structured",
      "group_id": 5,
      "time_id": 2,
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
      "group_id": 5,
      "time_id": 3,
      "text": "Class meeting and planning"
    }
  ]
}
```

## Frontend suggestions
- Use consistent day/time mappings to render grids.
- After upload, refresh the timetable view automatically.
