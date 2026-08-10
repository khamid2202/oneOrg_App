# Dorm Rooms API

**Base path:** `/dorm-rooms`

## Overview
Dorm rooms define the room inventory used by the dorm assignment flow. Each room is linked to a single `billing_id`, which is used when a student is assigned to that room.

All routes are under `RolesGuard`.
- `GET` routes: guarded, no explicit role restriction in controller.
- `POST`, `PATCH`, `DELETE`: allowed for `OWNER`, `ADMIN`, `MODERATOR`.

## Data Shape

Dorm room object:
```json
{
	"id": 1,
	"name": "Room A-101",
	"description": "First floor, 4 beds",
	"billing_id": 12,
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
- `billing_id`: integer, `>= 1`, must reference an existing billing
- `capacity`: integer, `>= 1`
- `free_beds`: computed as `capacity - active dorm students`
- A dorm room cannot be deleted while it has dorm student assignments

## Endpoints

### 1) Get Dorm Rooms
`GET /dorm-rooms`

Query params (all optional):
- `id`: integer, `>= 1`
- `name`: string, exact match
- `billing_id`: integer, `>= 1`

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
			"billing_id": 12,
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

Response `200`:
```json
{
	"ok": true,
	"message": "Dorm room retrieved successfully",
	"result": {
		"id": 1,
		"name": "Room A-101",
		"description": "First floor, 4 beds",
		"billing_id": 12,
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

Roles:
- `OWNER`, `ADMIN`, `MODERATOR`

Request body:
```json
{
	"name": "Room A-101",
	"description": "First floor, 4 beds",
	"billing_id": 12,
	"capacity": 4
}
```

Possible errors:
- `400 Bad Request`: `Billing code not found`
- `400 Bad Request`: DTO validation errors

Response `201` returns the room with computed `occupied_beds` and `free_beds`.

### 4) Update Dorm Room
`PATCH /dorm-rooms/:id`

Roles:
- `OWNER`, `ADMIN`, `MODERATOR`

Request body:
- Partial of the create body

Possible errors:
- `400 Bad Request`: `No data provided for update`
- `400 Bad Request`: `Billing code not found`
- `404 Not Found`: `Dorm room not found`

Response `200` returns the room with computed `occupied_beds` and `free_beds`.

### 5) Delete Dorm Room
`DELETE /dorm-rooms/:id`

Roles:
- `OWNER`, `ADMIN`, `MODERATOR`

Response `204`:
- Empty body

Possible errors:
- `400 Bad Request`: `Cannot delete dorm room with existing student assignments`
- `404 Not Found`: `Dorm room not found`

## Frontend Notes
- Use the room's `billing_id` as informative metadata when choosing a room for assignment.
- Do not offer delete actions for rooms that still have student assignments.