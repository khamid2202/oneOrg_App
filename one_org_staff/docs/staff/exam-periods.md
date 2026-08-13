# Exam Periods API

**Base path:** `/exam-periods`

Manage exam windows (period metadata) per academic year.

## Auth
- Guard: `RolesGuard` + permission checks via `@RequirePermissions`.
- Permissions:
  - Create: `exam_periods.create`
  - Update: `exam_periods.update`
  - Delete: `exam_periods.delete`
  - Read (list, get one): authenticated

## Endpoints

### List exam periods
- **GET** `/exam-periods`
- **Query (GetExamPeriodDto):** optional:
  - `id` (int, min 1)
  - `academic_year_id` (int, min 1)
  - `is_active` (bool)
  - `accept_scores` (bool)
  - `start_date` (ISO date string)
  - `end_date` (ISO date string)
- **Date filter behavior:**
  - Filters against `exam_periods.date`.
  - Supports one-sided ranges (`start_date` only or `end_date` only).
  - Rejects request if `start_date > end_date`.

**Example request**
```http
GET /exam-periods?academic_year_id=1&is_active=true
```

**Example response**
```json
{
  "ok": true,
  "message": "Exam periods retrieved successfully",
  "meta": { "total": 1 },
  "result": [
    {
      "id": 3,
      "academic_year_id": 1,
      "name": "Midterm 2026",
      "description": "First semester midterm",
      "is_active": true,
      "accept_scores": true,
      "date": "2026-03-25",
      "created_at": "2026-03-19T10:11:12.000Z",
      "created_by": 1,
      "updated_at": null,
      "updated_by": null
    }
  ]
}
```

### Get one
- **GET** `/exam-periods/:id`

**Example request**
```http
GET /exam-periods/3
```

**Example response**
```json
{
  "ok": true,
  "message": "Exam period retrieved successfully",
  "result": {
    "id": 3,
    "academic_year_id": 1,
    "name": "Midterm 2026",
    "description": "First semester midterm",
    "is_active": true,
    "accept_scores": true,
    "date": "2026-03-25",
    "created_at": "2026-03-19T10:11:12.000Z",
    "created_by": 1,
    "updated_at": null,
    "updated_by": null
  }
}
```

### Create exam period
- **POST** `/exam-periods`
- **Body (CreateExamPeriodDto):**
  - `academic_year_id` (int, required, min 1)
  - `name` (string, required, length 1-255)
  - `description` (string, optional, max 255)
  - `is_active` (boolean, optional, default `true`)
  - `accept_scores` (boolean, optional, default `true`)
  - `date` (ISO date string, required)

**Example request**
```json
{
  "academic_year_id": 1,
  "name": "Midterm 2026",
  "description": "First semester midterm",
  "is_active": true,
  "accept_scores": true,
  "date": "2026-03-25"
}
```

**Example response**
```json
{
  "ok": true,
  "message": "Exam period created successfully",
  "result": {
    "id": 3,
    "academic_year_id": 1,
    "name": "Midterm 2026",
    "description": "First semester midterm",
    "is_active": true,
    "accept_scores": true,
    "date": "2026-03-25",
    "created_at": "2026-03-19T10:11:12.000Z",
    "created_by": 1,
    "updated_at": null,
    "updated_by": null
  }
}
```

### Update exam period
- **PATCH** `/exam-periods/:id`
- **Body (UpdateExamPeriodDto):** partial of create fields.
- **Validation/behavior:** empty body is rejected.

**Example request**
```http
PATCH /exam-periods/3
```
```json
{
  "accept_scores": false
}
```

**Example response**
```json
{
  "ok": true,
  "message": "Exam period updated successfully",
  "result": {
    "id": 3,
    "academic_year_id": 1,
    "name": "Midterm 2026",
    "description": "First semester midterm",
    "is_active": true,
    "accept_scores": false,
    "date": "2026-03-25",
    "created_at": "2026-03-19T10:11:12.000Z",
    "created_by": 1,
    "updated_at": "2026-03-26T08:00:00.000Z",
    "updated_by": 1
  }
}
```

### Delete exam period
- **DELETE** `/exam-periods/:id`
- Returns **204 No Content** (empty body) on success.

**Example request**
```http
DELETE /exam-periods/3
```

## Frontend integration notes
- Build filter chips from `is_active`, `accept_scores`, and `academic_year_id` for admin list pages.
- Use `start_date` and `end_date` for date range filtering in reports/listing screens.
- Use `accept_scores` as a direct UI switch to allow/disable score entry actions.
- Keep `date` in `YYYY-MM-DD` format and send as ISO date string.
- Load exam periods first, then create exams with selected `exam_period_id`.