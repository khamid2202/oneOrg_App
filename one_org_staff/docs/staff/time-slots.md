# Time Slots API

**Base path:** `/time-slots`

## Overview
Time slots are used to define named daily intervals (for example, `Morning`, `Evening`) with `start_time` and `end_time`.

All routes are under `RolesGuard`.
- `GET` routes: guarded, no explicit role restriction in controller.
- `POST`, `PATCH`, `DELETE`: allowed for `OWNER`, `ADMIN`, `MODERATOR`.

## Data Shape

Time slot object:
```json
{
	"id": 1,
	"name": "Morning",
	"start_time": "08:00:00",
	"end_time": "10:00:00",
	"is_active": true
}
```

Validation and business rules:
- `name`: string, length `1..50`, unique.
- `start_time`: `HH:mm` or `HH:mm:ss`.
- `end_time`: `HH:mm` or `HH:mm:ss`.
- `start_time` must be earlier than `end_time`.
- `is_active`: optional boolean, defaults to `true` on create.

## Endpoints

### 1) Get Time Slots
`GET /time-slots`

Query params (all optional):
- `id`: integer, `>= 1`
- `name`: string, length `1..50`
- `is_active`: boolean

Response `200`:
```json
{
	"ok": true,
	"message": "Time slots retrieved successfully",
	"meta": {
		"total": 2
	},
	"result": [
		{
			"id": 1,
			"name": "Morning",
			"start_time": "08:00:00",
			"end_time": "10:00:00",
			"is_active": true
		},
		{
			"id": 2,
			"name": "Evening",
			"start_time": "17:00:00",
			"end_time": "19:00:00",
			"is_active": true
		}
	]
}
```

Example:
```http
GET /time-slots?is_active=true
```

### 2) Get One Time Slot
`GET /time-slots/:id`

Path params:
- `id`: integer

Response `200`:
```json
{
	"ok": true,
	"message": "Time slot retrieved successfully",
	"result": {
		"id": 1,
		"name": "Morning",
		"start_time": "08:00:00",
		"end_time": "10:00:00",
		"is_active": true
	}
}
```

Not found `404`:
```json
{
	"statusCode": 404,
	"message": "Time slot not found",
	"error": "Not Found"
}
```

### 3) Create Time Slot
`POST /time-slots`

Roles:
- `OWNER`, `ADMIN`, `MODERATOR`

Request body:
```json
{
	"name": "Morning",
	"start_time": "08:00",
	"end_time": "10:00",
	"is_active": true
}
```

Response `201`:
```json
{
	"ok": true,
	"message": "Time slot created successfully",
	"result": {
		"id": 1,
		"name": "Morning",
		"start_time": "08:00:00",
		"end_time": "10:00:00",
		"is_active": true
	}
}
```

Possible errors:
- `400 Bad Request`: `Time slot with this name already exists`
- `400 Bad Request`: `start_time must be earlier than end_time`
- `400 Bad Request`: DTO validation errors

### 4) Update Time Slot
`PATCH /time-slots/:id`

Roles:
- `OWNER`, `ADMIN`, `MODERATOR`

Path params:
- `id`: integer

Request body:
- Partial of create body; send only fields to change.

Example:
```json
{
	"name": "Morning Updated",
	"end_time": "10:30"
}
```

Response `200`:
```json
{
	"ok": true,
	"message": "Time slot updated successfully",
	"result": {
		"id": 1,
		"name": "Morning Updated",
		"start_time": "08:00:00",
		"end_time": "10:30:00",
		"is_active": true
	}
}
```

Possible errors:
- `400 Bad Request`: `No data provided for update`
- `400 Bad Request`: `Time slot with this name already exists`
- `400 Bad Request`: `start_time must be earlier than end_time`
- `400 Bad Request`: DTO validation errors
- `404 Not Found`: `Time slot not found`

### 5) Delete Time Slot
`DELETE /time-slots/:id`

Roles:
- `OWNER`, `ADMIN`, `MODERATOR`

Path params:
- `id`: integer

Response `204`:
- Empty body

Possible errors:
- `404 Not Found`: `Time slot not found`

## Frontend Notes
- Use `HH:mm` inputs for create/update; backend also accepts `HH:mm:ss`.
- Expect `204` with no response body for successful delete.
- For list screens, consume `meta.total` and `result` from `GET /time-slots`.

