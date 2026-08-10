# Dorm Students API

**Base path:** `/dorm-students`

## Overview
Dorm student records represent room assignments for student groups.

Creating a dorm student assignment also:
- validates the room and student group
- checks room capacity and active-assignment conflicts
- creates a monthly invoice using the room's `billing_id` when one does not already exist for the same month, otherwise reuses the existing invoice
- adds the room billing to the active student group's `billing_ids` so future monthly invoice generation includes dorm charges
- ensures the student's wallet exists
- recalculates wallet aggregates through the existing invoice/payment resolve flow

All routes are under `RolesGuard`.
- `GET` routes: guarded, no explicit role restriction in controller.
- `POST`, `PATCH`, `DELETE`: allowed for `OWNER`, `ADMIN`, `MODERATOR`.

## Data Shape

Dorm student object:
```json
{
	"id": 10,
	"dorm_room_id": 1,
	"student_group_id": 55,
	"bed_number": 2,
	"notes": "Moved in after transfer",
	"move_in_date": "2026-04-20",
	"move_out_date": null,
	"created_at": "2026-04-20T10:15:00.000Z",
	"created_by": 7,
	"updated_at": null,
	"updated_by": null
}
```

Validation and business rules:
- `dorm_room_id`: integer, `>= 1`, must reference an existing dorm room
- `student_group_id`: integer, `>= 1`, must reference an existing student group
- `bed_number`: integer, `>= 1`, must not exceed room capacity
- `notes`: optional string, length `1..255`
- `move_in_date`: ISO date string
- `move_out_date`: optional ISO date string, must not be earlier than `move_in_date`
- A student group can have only one active dorm assignment at a time
- A room cannot exceed its capacity for active residents
- `dorm_room_id + bed_number` must be unique across all dorm assignments
- Assignment creation reuses an existing invoice for the same student group, dorm billing, and move-in month instead of failing

## Endpoints

### 1) Get Dorm Students
`GET /dorm-students`

Query params (all optional):
- `id`: integer, `>= 1`
- `dorm_room_id`: integer, `>= 1`
- `student_group_id`: integer, `>= 1`
- `active_only`: boolean

Response `200`:
```json
{
	"ok": true,
	"message": "Dorm students retrieved successfully",
	"meta": {
		"total": 1
	},
	"result": [
		{
			"id": 10,
			"dorm_room_id": 1,
			"student_group_id": 55,
			"bed_number": 2,
			"notes": "Moved in after transfer",
			"move_in_date": "2026-04-20",
			"move_out_date": null,
			"dorm_room_name": "Room A-101",
			"billing_id": 12,
			"student_id": 202,
			"student_full_name": "John Doe",
			"student_la_id": "LA-202",
			"student_status": "active",
			"academic_year_id": 3,
			"group_id": 8,
			"group_name": "9-A",
			"group_grade": 9,
			"group_class": "A"
		}
	]
}
```

### 2) Get One Dorm Student
`GET /dorm-students/:id`

Response `200` returns the same enriched shape as the list endpoint, including student and group fields.

Possible errors:
- `404 Not Found`: `Dorm student not found`

### 3) Create Dorm Student
`POST /dorm-students`

Roles:
- `OWNER`, `ADMIN`, `MODERATOR`

Request body:
```json
{
	"dorm_room_id": 1,
	"student_group_id": 55,
	"bed_number": 2,
	"notes": "Moved in after transfer",
	"move_in_date": "2026-04-20"
}
```

Response `201` includes the created assignment with student/group info and the created or reused invoice.

Possible errors:
- `400 Bad Request`: `Dorm room is already at full capacity`
- `400 Bad Request`: `Dorm room billing code not found`
- `400 Bad Request`: `bed_number cannot be greater than dorm room capacity`
- `400 Bad Request`: `move_out_date cannot be earlier than move_in_date`
- `404 Not Found`: `Dorm room not found`
- `404 Not Found`: `Student group not found`
- `409 Conflict`: `This bed number already exists in the selected dorm room`
- `409 Conflict`: `Student group already has an active dorm assignment`

### 4) Update Dorm Student
`PATCH /dorm-students/:id`

Roles:
- `OWNER`, `ADMIN`, `MODERATOR`

Request body:
- Partial of the create body

Notes:
- Update does not create or reverse invoices automatically.
- If an assignment is active (`move_out_date = null`), updating room, student group, or active status also synchronizes the affected student group's `billing_ids`.
- Successful update returns the enriched dorm-student object with student/group info.

Possible errors:
- `400 Bad Request`: `No data provided for update`
- `400 Bad Request`: capacity/date validation errors
- `404 Not Found`: `Dorm student not found`
- `404 Not Found`: `Dorm room not found`
- `404 Not Found`: `Student group not found`
- `409 Conflict`: `Student group already has an active dorm assignment`

### 5) Delete Dorm Student
`DELETE /dorm-students/:id`

Roles:
- `OWNER`, `ADMIN`, `MODERATOR`

Response `204`:
- Empty body

Notes:
- Deleting an active dorm assignment removes that dorm billing from the student group's `billing_ids` when no other active dorm assignment still requires it.

Possible errors:
- `404 Not Found`: `Dorm student not found`

## Frontend Notes
- Treat assignment create as a financial action because it generates an invoice and updates wallet balances.
- If users can change room assignments after creation, communicate clearly that update/delete do not auto-reverse prior invoices, even though they do keep `billing_ids` aligned for future monthly invoice generation.