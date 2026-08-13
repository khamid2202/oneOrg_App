# Exams API

**Base path:** `/exams`

Manage exam definitions per `exam_period_id + subject_id`.

## Auth
- Guard: `RolesGuard`
- Roles:
  - Create: authenticated (guarded)
  - Update/Delete: allowed only for creator (`created_by`) or elevated roles `owner`, `admin`, `moderator`
  - Read: authenticated (guarded)

## Endpoints

### List exams
- **GET** `/exams`
- **Query (GetExamDto):** optional:
  - `id` (int, min 1)
  - `exam_period_id` (int, min 1)
  - `subject_id` (int, min 1)
  - `group_ids` (int[]; accepts JSON array in query, e.g. `[1,2]`)
  - `start_date` (ISO date string)
  - `end_date` (ISO date string)
- **Date filter behavior:**
  - `start_date`/`end_date` filter by related **exam period** date (`exam_periods.date`), not exam `created_at`.
  - Supports one-sided ranges (`start_date` only or `end_date` only).
  - Rejects request if `start_date > end_date`.
- **Group filter behavior:**
  - `group_ids` returns exams where `exam.group_ids` has at least one overlapping group id.

**Example request**
```http
GET /exams?exam_period_id=3&group_ids=[5,6]
```

**Example response**
```json
{
  "ok": true,
  "message": "Exams retrieved successfully",
  "meta": { "total": 1 },
  "result": [
    {
      "id": 12,
      "exam_period_id": 3,
      "subject_id": 7,
      "group_ids": [5, 6],
      "max_score": 100,
      "created_at": "2026-03-19T10:11:12.000Z",
      "created_by": 1,
      "updated_at": null,
      "updated_by": null
    }
  ]
}
```

### Get one
- **GET** `/exams/:id`

**Example request**
```http
GET /exams/12
```

**Example response**
```json
{
  "ok": true,
  "message": "Exam retrieved successfully",
  "result": {
    "id": 12,
    "exam_period_id": 3,
    "subject_id": 7,
    "group_ids": [5, 6],
    "max_score": 100,
    "created_at": "2026-03-19T10:11:12.000Z",
    "created_by": 1,
    "updated_at": null,
    "updated_by": null
  }
}
```

### Create exam
- **POST** `/exams`
- **Body (CreateExamDto):**
  - `exam_period_id` (int, required, min 1)
  - `subject_id` (int, required, min 1)
  - `group_ids` (int[], optional, each min 1)
  - `max_score` (int, required, min 1)
- **Validation/behavior:**
  - Duplicate combination `exam_period_id + subject_id` is rejected.
  - If `group_ids` is provided, duplicate IDs are normalized.

**Example request**
```json
{
  "exam_period_id": 3,
  "subject_id": 7,
  "group_ids": [5, 6],
  "max_score": 100
}
```

**Example response**
```json
{
  "ok": true,
  "message": "Exam created successfully",
  "result": {
    "id": 12,
    "exam_period_id": 3,
    "subject_id": 7,
    "group_ids": [5, 6],
    "max_score": 100,
    "created_at": "2026-03-19T10:11:12.000Z",
    "created_by": 1,
    "updated_at": null,
    "updated_by": null
  }
}
```

### Update exam
- **PATCH** `/exams/:id`
- **Body (UpdateExamDto):** partial of create fields.
- **Validation/behavior:**
  - Authorization: only creator or `owner/admin/moderator` can update.
  - Empty body is rejected.
  - Changing `exam_period_id` or `subject_id` checks duplicate pair again.
  - If `group_ids` is provided, duplicate IDs are normalized.

**Example request**
```http
PATCH /exams/12
```
```json
{
  "max_score": 80
}
```

**Example response**
```json
{
  "ok": true,
  "message": "Exam updated successfully",
  "result": {
    "id": 12,
    "exam_period_id": 3,
    "subject_id": 7,
    "group_ids": [5, 6],
    "max_score": 80,
    "created_at": "2026-03-19T10:11:12.000Z",
    "created_by": 1,
    "updated_at": "2026-03-20T09:00:00.000Z",
    "updated_by": 1
  }
}
```

### Delete exam
- **DELETE** `/exams/:id`
- Authorization: only creator or `owner/admin/moderator` can delete.
- Returns **204 No Content** (empty body) on success.

**Example request**
```http
DELETE /exams/12
```

## Frontend integration notes
- Load `exam-periods` and `subjects` first, then map selected IDs into `POST /exams`.
- Before creating, you can pre-check duplicates in UI by querying `GET /exams?exam_period_id=...&subject_id=...`.
- For date filtering in exam lists, use `start_date`/`end_date` as exam-period date boundaries.
- To filter by groups, pass `group_ids` as JSON array in query (example: `GET /exams?group_ids=[5,6]`).
- Use `max_score` from this resource to validate score input forms in exam-results screens.
