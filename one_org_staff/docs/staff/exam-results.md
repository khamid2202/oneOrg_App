# Exam Results API

**Base path:** `/exam-results`

Manage student scores per `student_id + exam_id`.

## Auth
- Guard: `RolesGuard` (authenticated access required)
- Roles:
	- Create: authenticated (guarded)
	- Update/Delete: allowed only for creator (`created_by`) or elevated roles `owner`, `admin`, `moderator`
	- Read: authenticated (guarded)

## Endpoints

### Create exam result
- **POST** `/exam-results`
- **Body (CreateExamResultDto):**
	- `student_id` (int, required, min 1)
	- `exam_id` (int, required, min 1)
	- `score` (number, required, min 0)
- **Validation/behavior:**
	- Duplicate combination `student_id + exam_id` is rejected.

### Bulk create exam results
- **POST** `/exam-results/bulk`
- **Body:** array of `CreateExamResultDto`
- **Validation/behavior:**
	- Empty array is rejected.
	- Duplicate `student_id + exam_id` pair inside payload is rejected.
	- If any provided pair already exists in DB, request is rejected.

### List exam results
- **GET** `/exam-results`
- **Query (GetExamResultDto):** optional:
	- `id` (int, min 1)
	- `student_id` (int, min 1)
	- `exam_id` (int, min 1)
	- `start_date` (ISO date string)
	- `end_date` (ISO date string)
- **Date filter behavior:**
	- `start_date`/`end_date` filter by related **exam period** date (`exam_results -> exams -> exam_periods.date`), not result `created_at`.
	- Supports one-sided ranges (`start_date` only or `end_date` only).
	- Rejects request if `start_date > end_date`.

### Get one
- **GET** `/exam-results/:id`

### Update exam result
- **PATCH** `/exam-results/:id`
- **Body (UpdateExamResultDto):** partial of create fields.
- **Validation/behavior:**
	- Authorization: only creator or `owner/admin/moderator` can update.
	- Empty body is rejected.
	- Changing `student_id` or `exam_id` checks duplicate pair again.

### Bulk update exam results
- **PATCH** `/exam-results/bulk`
- **Body:** array of items:
	- `id` (int, required, min 1)
	- optional update fields from `UpdateExamResultDto`
- **Validation/behavior:**
	- Empty array is rejected.
	- Duplicate ids in payload are rejected.
	- Each item must contain at least one updatable field.
	- Authorization applies per item (creator or `owner/admin/moderator`).
	- Duplicate `student_id + exam_id` pairs introduced by payload or existing records are rejected.

### Delete exam result
- **DELETE** `/exam-results/:id`
- Authorization: only creator or `owner/admin/moderator` can delete.
- Returns **204 No Content** on success.

## Response shape
- **List:**
```json
{
	"ok": true,
	"message": "Exam results retrieved successfully",
	"meta": { "total": 1 },
	"result": [
		{
			"id": 55,
			"student_id": 101,
			"exam_id": 12,
			"score": 86.5,
			"created_at": "2026-03-19T10:11:12.000Z",
			"created_by": 1,
			"updated_at": null,
			"updated_by": null
		}
	]
}
```
- **Single / create / update:**
```json
{
	"ok": true,
	"message": "Exam result updated successfully",
	"result": {
		"id": 55,
		"student_id": 101,
		"exam_id": 12,
		"score": 88,
		"created_at": "2026-03-19T10:11:12.000Z",
		"created_by": 1,
		"updated_at": "2026-03-19T11:01:00.000Z",
		"updated_by": 1
	}
}
```

## Example request
- **Method:** POST
- **Path:** `/exam-results`
- **Request body:**
```json
{
	"student_id": 101,
	"exam_id": 12,
	"score": 86.5
}
```

## Frontend integration notes
- Always fetch related exam (`GET /exams/:id`) to get `max_score` and validate `score` client-side.
- For edit screens, pre-load with `GET /exam-results/:id` and submit only changed fields.
- For list pages, combine filters `student_id` and `exam_id` for compact queries.
- For exam-window analytics, filter by `start_date`/`end_date` (exam-period date range).
