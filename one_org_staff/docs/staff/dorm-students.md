# Dorm Students API

**Base path:** `/dorm-students`

## Overview
Dorm student records represent room assignments for student enrollments
(`student_id`).

Creating a dorm student assignment also:
- validates the room and student enrollment
- checks room capacity and active-assignment conflicts
- creates a monthly invoice using the room's `invoice_template_id` for the
  move-in month when one does not already exist, otherwise reuses the existing
  invoice
- adds the room's template to the active student's `invoice_template_ids` so
  future monthly invoice generation includes dorm charges

All routes are under `RolesGuard` + permission checks via `@RequirePermissions`.
- `GET` routes: authenticated, no explicit permission.
- `POST`: `dorm_students.create`; `PATCH`: `dorm_students.update`; `DELETE`: `dorm_students.delete`.

## Data Shape

Dorm student object (enriched read shape):
```json
{
	"id": 10,
	"dorm_room_id": 1,
	"student_id": 55,
	"bed_number": 2,
	"notes": "Moved in after transfer",
	"move_in_date": "2026-04-20",
	"move_out_date": null,
	"created_at": "2026-04-20T10:15:00.000Z",
	"updated_at": null,
	"dorm_room_name": "Room A-101",
	"dorm_room_capacity": 4,
	"invoice_template_id": 12,
	"person_id": 202,
	"academic_year_id": 3,
	"group_id": 8,
	"student_full_name": "John Doe",
	"student_la_id": "LA-202",
	"group_name": "9-A",
	"group_grade": 9,
	"group_class": "A"
}
```

Validation and business rules:
- `dorm_room_id`: integer, `>= 1`, must reference an existing dorm room
- `student_id`: integer, `>= 1`, must reference an existing student enrollment
- `bed_number`: integer, `>= 1`, must not exceed room capacity
- `notes`: optional string, length `1..255`
- `move_in_date`: ISO date string
- `move_out_date`: optional ISO date string, must not be earlier than `move_in_date`
- A student can have only one active dorm assignment at a time
- A room cannot exceed its capacity for active residents
- `dorm_room_id + bed_number` must be unique across all dorm assignments
- Assignment creation reuses an existing invoice for the same student, dorm
  template, and move-in month instead of failing

## Endpoints

### 1) Get Dorm Students
`GET /dorm-students` (alias: `GET /dorm-students/all`)

Query params (all optional):
- `id`: integer, `>= 1`
- `dorm_room_id`: integer, `>= 1`
- `student_id`: integer, `>= 1`
- `active_only`: boolean (only assignments with `move_out_date = null`)

Example:
```http
GET /dorm-students?dorm_room_id=1&active_only=true
```

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
			"student_id": 55,
			"bed_number": 2,
			"notes": "Moved in after transfer",
			"move_in_date": "2026-04-20",
			"move_out_date": null,
			"dorm_room_name": "Room A-101",
			"dorm_room_capacity": 4,
			"invoice_template_id": 12,
			"person_id": 202,
			"academic_year_id": 3,
			"group_id": 8,
			"student_full_name": "John Doe",
			"student_la_id": "LA-202",
			"group_name": "9-A",
			"group_grade": 9,
			"group_class": "A"
		}
	]
}
```

### 2) Get One Dorm Student
`GET /dorm-students/:id`

Example:
```http
GET /dorm-students/10
```

Response `200`:
```json
{
	"ok": true,
	"message": "Dorm student retrieved successfully",
	"result": {
		"id": 10,
		"dorm_room_id": 1,
		"student_id": 55,
		"bed_number": 2,
		"move_in_date": "2026-04-20",
		"move_out_date": null,
		"dorm_room_name": "Room A-101",
		"invoice_template_id": 12,
		"student_full_name": "John Doe",
		"group_name": "9-A"
	}
}
```

Possible errors:
- `404 Not Found`: `Dorm student not found`

### 3) Create Dorm Student
`POST /dorm-students`

Permission: `dorm_students.create`

Request body:
```json
{
	"dorm_room_id": 1,
	"student_id": 55,
	"bed_number": 2,
	"notes": "Moved in after transfer",
	"move_in_date": "2026-04-20"
}
```

Response `201` includes the enriched assignment plus the created or reused
invoice:
```json
{
	"ok": true,
	"message": "Dorm student created successfully",
	"result": {
		"id": 10,
		"dorm_room_id": 1,
		"student_id": 55,
		"bed_number": 2,
		"move_in_date": "2026-04-20",
		"move_out_date": null,
		"dorm_room_name": "Room A-101",
		"invoice_template_id": 12,
		"student_full_name": "John Doe"
	},
	"invoice": {
		"id": 901,
		"student_id": 55,
		"academic_year_id": 3,
		"year": 2026,
		"month": 4,
		"invoice_template_id": 12,
		"subtotal_required_amount": 80,
		"discount_percent": 0,
		"total_required_amount": 80,
		"status": "Not Paid"
	}
}
```

Possible errors:
- `400 Bad Request`: `Dorm room is already at full capacity`
- `400 Bad Request`: `Dorm room invoice template not found`
- `400 Bad Request`: `bed_number cannot be greater than dorm room capacity`
- `400 Bad Request`: `move_out_date cannot be earlier than move_in_date`
- `404 Not Found`: `Dorm room not found`
- `404 Not Found`: `Person group not found` (missing student enrollment)
- `404 Not Found`: `Group not found`
- `409 Conflict`: `This bed number already exists in the selected dorm room`
- `409 Conflict`: student already has an active dorm assignment

### 4) Update Dorm Student
`PATCH /dorm-students/:id`

Permission: `dorm_students.update`

Request body: partial of the create body.

Example:
```http
PATCH /dorm-students/10
```
```json
{
	"move_out_date": "2026-06-30"
}
```

Response `200`:
```json
{
	"ok": true,
	"message": "Dorm student updated successfully",
	"result": {
		"id": 10,
		"dorm_room_id": 1,
		"student_id": 55,
		"bed_number": 2,
		"move_in_date": "2026-04-20",
		"move_out_date": "2026-06-30",
		"dorm_room_name": "Room A-101",
		"invoice_template_id": 12,
		"student_full_name": "John Doe"
	}
}
```

Notes:
- Update does not create or reverse invoices automatically.
- If an assignment is active (`move_out_date = null`), updating room, student,
  or active status also synchronizes the affected student's
  `invoice_template_ids`.

Possible errors:
- `400 Bad Request`: `No data provided for update`
- `400 Bad Request`: capacity/date validation errors
- `404 Not Found`: `Dorm student not found`
- `404 Not Found`: `Dorm room not found`
- `404 Not Found`: `Person group not found`
- `409 Conflict`: student already has an active dorm assignment

### 5) Delete Dorm Student
`DELETE /dorm-students/:id`

Permission: `dorm_students.delete`

Example:
```http
DELETE /dorm-students/10
```

This endpoint is payment-aware. It looks at the assignment's related dorm
invoices — invoices for the same `student_id` and the room's
`invoice_template_id` from the move-in month onward — and behaves in one of
three ways:

1. **No payment yet** (all related invoices have `total_paid_amount = 0`, or
   there are none): hard-deletes the dorm student record, then removes the
   room's template from the student's `invoice_template_ids` when no other
   active assignment still requires it. Related invoices are left untouched
   (invoice deletion is managed separately).

   Response `200`:
   ```json
   {
   	"ok": true,
   	"message": "Dorm student deleted successfully"
   }
   ```

2. **Payment made and fully resolved** (every related invoice has
   `total_paid_amount >= total_required_amount`): keeps the record and its
   history, sets `move_out_date` to today, and removes the room's template from
   the student's `invoice_template_ids` when no other active assignment still
   requires it.

   Response `200`:
   ```json
   {
   	"ok": true,
   	"message": "Dorm student moved out successfully",
   	"result": {
   		"id": 10,
   		"dorm_room_id": 1,
   		"student_id": 55,
   		"move_out_date": "2026-07-10",
   		"invoice_template_id": 12,
   		"student_full_name": "John Doe"
   	}
   }
   ```

3. **Payment made but still outstanding** (a related invoice is partially paid):
   rejects the request so the balance can be settled first.

Possible errors:
- `400 Bad Request`: `Please resolve the outstanding invoice payment before removing this dorm student`
- `404 Not Found`: `Dorm student not found`
- `404 Not Found`: `Dorm room not found`

## Frontend Notes
- Treat assignment create as a financial action because it generates an invoice.
- `DELETE` is a financial action too: it only hard-deletes the assignment when
  no payment has been made, otherwise it either records a move-out (when fully
  paid) or blocks with `400` (when a balance is still outstanding). It never
  deletes invoices — invoice deletion is managed separately. Surface the
  returned `message` to the user rather than assuming the record was deleted,
  and expect a `200` JSON body instead of the previous `204`.
- `PATCH` does not create or reverse invoices automatically, even though it keeps
  `invoice_template_ids` aligned for future monthly invoice generation.
