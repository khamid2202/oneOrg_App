# Dorm Rooms API

**Base path:** `/dorm-rooms`

## Overview
Dorm rooms define the room inventory used by the dorm assignment flow. Each
room is linked to a single `invoice_template_id`, which is billed when a
student is assigned to that room.

All routes are under `RolesGuard` + permission checks via `@RequirePermissions`.
- `GET` routes: authenticated, no explicit permission.
- `POST`: `dorm_rooms.create`; `PATCH`: `dorm_rooms.update`; `DELETE`: `dorm_rooms.delete`.

## Data Shape

Dorm room object:
```json
{
	"id": 1,
	"name": "Room A-101",
	"description": "First floor, 4 beds",
	"invoice_template_id": 12,
	"capacity": 4,
	"occupied_beds": 1,
	"free_beds": 3,
	"created_at": "2026-04-20T10:00:00.000Z",
	"created_by": 7,
	"updated_at": null,
	"updated_by": null
}
```

Validation and business rules:
- `name`: string, length `1..255`
- `description`: optional string, length `1..255`
- `invoice_template_id`: integer, `>= 1`, must reference an existing invoice template
- `capacity`: integer, `>= 1`
- `free_beds`: computed as `capacity - active dorm students`
- A dorm room cannot be deleted while it has dorm student assignments

## Endpoints

### 1) Get Dorm Rooms
`GET /dorm-rooms` (alias: `GET /dorm-rooms/all`)

Query params (all optional):
- `id`: integer, `>= 1`
- `name`: string, exact match
- `invoice_template_id`: integer, `>= 1`

Example:
```http
GET /dorm-rooms?invoice_template_id=12
```

Response `200`:
```json
{
	"ok": true,
	"message": "Dorm rooms retrieved successfully",
	"meta": {
		"total": 1
	},
	"result": [
		{
			"id": 1,
			"name": "Room A-101",
			"description": "First floor, 4 beds",
			"invoice_template_id": 12,
			"capacity": 4,
			"occupied_beds": 1,
			"free_beds": 3,
			"created_at": "2026-04-20T10:00:00.000Z",
			"created_by": 7,
			"updated_at": null,
			"updated_by": null
		}
	]
}
```

### 2) Get One Dorm Room
`GET /dorm-rooms/:id`

Example:
```http
GET /dorm-rooms/1
```

Response `200`:
```json
{
	"ok": true,
	"message": "Dorm room retrieved successfully",
	"result": {
		"id": 1,
		"name": "Room A-101",
		"description": "First floor, 4 beds",
		"invoice_template_id": 12,
		"capacity": 4,
		"occupied_beds": 1,
		"free_beds": 3
	}
}
```

Possible errors:
- `404 Not Found`: `Dorm room not found`

### 3) Create Dorm Room
`POST /dorm-rooms`

Permission: `dorm_rooms.create`

Request body:
```json
{
	"name": "Room A-101",
	"description": "First floor, 4 beds",
	"invoice_template_id": 12,
	"capacity": 4
}
```

Response `201` returns the room with computed `occupied_beds` and `free_beds`:
```json
{
	"ok": true,
	"message": "Dorm room created successfully",
	"result": {
		"id": 1,
		"name": "Room A-101",
		"description": "First floor, 4 beds",
		"invoice_template_id": 12,
		"capacity": 4,
		"occupied_beds": 0,
		"free_beds": 4
	}
}
```

Possible errors:
- `400 Bad Request`: `Invoice template not found`
- `400 Bad Request`: DTO validation errors

### 4) Update Dorm Room
`PATCH /dorm-rooms/:id`

Permission: `dorm_rooms.update`

Request body: partial of the create body.

Example:
```http
PATCH /dorm-rooms/1
```
```json
{
	"capacity": 5
}
```

Response `200`:
```json
{
	"ok": true,
	"message": "Dorm room updated successfully",
	"result": {
		"id": 1,
		"name": "Room A-101",
		"description": "First floor, 4 beds",
		"invoice_template_id": 12,
		"capacity": 5,
		"occupied_beds": 1,
		"free_beds": 4
	}
}
```

Possible errors:
- `400 Bad Request`: `No data provided for update`
- `400 Bad Request`: `Invoice template not found`
- `404 Not Found`: `Dorm room not found`

### 5) Delete Dorm Room
`DELETE /dorm-rooms/:id`

Permission: `dorm_rooms.delete`

Example:
```http
DELETE /dorm-rooms/1
```

Response `204`: empty body.

Possible errors:
- `400 Bad Request`: `Cannot delete dorm room with existing student assignments`
- `404 Not Found`: `Dorm room not found`

## Frontend Notes
- Use the room's `invoice_template_id` as informative metadata when choosing a room for assignment.
- Do not offer delete actions for rooms that still have student assignments.
