# Points API

**Base path:** `/student-points`

Manage student point records (scores/points system).

## Auth
- Guard: assumed auth middleware (no explicit roles on controller).

## Endpoints

### Create point
- **POST** `/student-points`
- **Body (CreatePointDto):**
	- `student_id` (int, required)
	- `group_id` (int, required)
	- `subject_id` (int, optional)
	- `points` (number, required)
	- `date` (ISO date string, required)
	- `reason` (string, optional)
- **Behavior:**
	- validates student, group, student-group membership
	- validates point date against group's academic year range
	- resolves `teacher_id` from timetable when `subject_id` is provided (fallback: group teacher)
	- if a duplicate already exists by `student_id`, `group_id`, `subject_id`, `teacher_id`, normalized `reason`, and `date`, updates that existing row instead of inserting a new one, including the latest `points` value
	- stores audit fields from authenticated user (`created_by`, `updated_by`)

### Create points in bulk
- **POST** `/student-points/bulk`
- **Body:** JSON array of `CreatePointDto`
	- Example: `[{"student_id":11,"group_id":5,"subject_id":3,"points":8,"reason":"Quiz","date":"2025-10-02"}]`
- **Behavior:**
	- applies the same validations as single create per record
	- collapses duplicate records inside the same request before writing
	- treats duplicates by `student_id`, `group_id`, `subject_id`, `teacher_id`, normalized `reason`, and `date`
	- updates an existing matching row instead of inserting a new one when the duplicate key already exists, using the latest `points` value

### List points
- **GET** `/student-points`
- **Query (GetPointsDto):**
	- `student_id` (int, optional)
	- `group_id` (int, optional)
	- `subject_id` (int, optional)
	- `reason` (string, optional; partial match)
	- `start_date` (ISO date string, optional)
	- `end_date` (ISO date string, optional)
	- `page` (int, optional, default `1`)
	- `limit` (int, optional, default `20`)
- **Response notes:**
	- sorted by `date DESC`, then `created_at DESC`
	- returns `meta.total` and `meta.total_points`
	- includes joined display fields (`student_name`, `subject_name`, `teacher_name`, class pair fields)

### Update point
- **PATCH** `/student-points/:id`
- **Body (UpdatePointDto):** partial of create fields.
- **Behavior:**
	- validates target point exists
	- validates updated relations/date with same rules as create
	- recalculates `teacher_id` when relevant fields change
	- updates audit fields (`updated_by`, `updated_at`)

### Delete point
- **DELETE** `/student-points/:id`
- **Behavior:** deletes point by `id` (throws if not found).

## Usage notes
- Provide `UserId` via auth token; used for audit.
- Bulk create expects JSON array payload.

## Example request
- **Method:** POST
- **Path:** `/student-points`
- **Request body:**
```json
{
	"student_id": 11,
	"group_id": 5,
	"subject_id": 3,
	"points": 8,
	"reason": "Quiz",
	"date": "2025-10-02"
}
```

## Example response
```json
{
	"ok": true,
	"message": "Point created successfully",
	"point": {
		"id": 701,
		"student_id": 11,
		"subject_id": 3,
		"points": 8
	}
}
```

## Frontend suggestions
- Use date pickers for `date`/range filters.
- Keep list pagination in state to avoid refetch churn.
