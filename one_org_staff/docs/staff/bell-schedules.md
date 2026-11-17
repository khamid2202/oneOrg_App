# Bell Schedules API

**Base path:** `/bell-schedules`

Only bell schedules at the branches selected by `X-Branch-Id` are visible; see
[Branches](branches.md#scoped-data).

## Overview
A bell schedule is a set of periods (lesson times) for one academic year.
Different grades can have different bell times, e.g. staggered lunch:

- A group uses the schedule whose `grades` contains its grade.
- Otherwise it uses the year's **default** schedule (`is_default: true`).
- A period with `day_of_week: null` applies every day; a period with a
  `day_of_week` overrides the every-day period with the same `period_number`
  on that day (e.g. a shorter Friday).

The migration created a `Default` schedule for every academic year with one
period per existing time slot (`time_slot_id` set), so current timetables keep
their times.

**How this feeds the timetable (for now):** timetable entries still store
`time_id`. Each entry's `period_id` is resolved automatically to the period in
the group's schedule whose `time_slot_id` equals the entry's `time_id`. That
period's real times are used for [clash checks](timetable.md#clash-checks).
Link each period to the matching time slot so this works. Any change on this
API re-resolves `period_id` for the whole year. A later phase will let the
timetable use `period_id` directly and drop the time-slot link.

Changing times doesn't re-check existing timetable entries for clashes.

All routes use `@RequirePermissions`:
- `GET`: `bell_schedules.read`; `POST /bell-schedules`: `bell_schedules.create`;
  period routes and `PATCH`: `bell_schedules.update`; `DELETE /bell-schedules/:id`: `bell_schedules.delete`.

## Data Shape

Bell schedule object:
```json
{
	"id": 2,
	"academic_year_id": 3,
	"name": "Primary",
	"grades": [1, 2, 3, 4],
	"is_default": false,
	"created_at": "2026-09-29T10:00:00.000Z",
	"created_by": 7,
	"updated_at": null,
	"updated_by": null,
	"periods": [
		{
			"id": 11,
			"bell_schedule_id": 2,
			"period_number": 1,
			"name": "1",
			"start_time": "08:00:00",
			"end_time": "08:40:00",
			"day_of_week": null,
			"time_slot_id": 1
		}
	]
}
```

Periods are sorted every-day first, then by `day_of_week`, then `period_number`.

Validation and business rules:
- `name`: string `1..100`, unique per academic year
- `grades`: unique integers `0..20`; a grade can be in only one schedule per year (`409`)
- `is_default`: at most one default per year; setting it moves the flag from the old default
- Period `period_number`: `1..20`; unique per `(schedule, day_of_week)` (`409`)
- Period `start_time` / `end_time`: `HH:mm` or `HH:mm:ss`, start before end
- Periods with the same `day_of_week` value can't overlap (`409`)
- `time_slot_id`: optional, must exist

## Endpoints

### 1) Get Bell Schedules
`GET /bell-schedules`

Query params (optional):
- `academic_year_id`: integer
- `grade`: integer. Returns only the schedule that applies to this grade (per year).

```http
GET /bell-schedules?academic_year_id=3&grade=2
```

Response `200`: `{ "ok": true, "message": "Bell schedules retrieved successfully", "meta": { "total": 1 }, "result": [ ...schedules ] }`

### 2) Get One Bell Schedule
`GET /bell-schedules/:id`

Possible errors:
- `404 Not Found`: `Bell schedule not found`

### 3) Create Bell Schedule
`POST /bell-schedules`

```json
{
	"academic_year_id": 3,
	"name": "Primary",
	"grades": [1, 2, 3, 4],
	"periods": [
		{ "period_number": 1, "start_time": "08:00", "end_time": "08:40", "time_slot_id": 1 },
		{ "period_number": 2, "start_time": "08:45", "end_time": "09:25", "time_slot_id": 2 },
		{ "period_number": 2, "start_time": "08:45", "end_time": "09:15", "day_of_week": 5, "time_slot_id": 2 }
	]
}
```

Response `201`: `{ "ok": true, "message": "Bell schedule created successfully", "result": { ...schedule } }`

Possible errors:
- `400 Bad Request`: validation, `Period 1 (every day): start_time must be earlier than end_time`
- `404 Not Found`: academic year or time slot not found
- `409 Conflict`: `Grades 3 already use bell schedule "Primary"`, duplicate name,
  `Period 2 is defined twice for Friday`, `Periods 1 and 2 overlap on every day`

### 4) Update Bell Schedule
`PATCH /bell-schedules/:id`

Body: any of `name`, `grades` (replaces the list), `is_default`.

Possible errors: as for create, plus `400 No data provided for update`.

### 5) Delete Bell Schedule
`DELETE /bell-schedules/:id`

Deletes the schedule and its periods. Groups that used it fall back to the
default schedule. Response `204 No Content`.

### 6) Add Period
`POST /bell-schedules/:id/periods`

```json
{ "period_number": 7, "name": "7", "start_time": "13:30", "end_time": "14:10", "time_slot_id": 7 }
```

Response `201`: `{ "ok": true, "message": "Period added successfully", "result": { ...schedule } }`

### 7) Update Period
`PATCH /bell-schedules/periods/:periodId`

Any subset of the period fields. `day_of_week: null` / `time_slot_id: null` clear them.

Response `200`: `{ "ok": true, "message": "Period updated successfully", "result": { ...schedule } }`

Possible errors:
- `404 Not Found`: `Period not found`
- `409 Conflict`: overlap or duplicate number

### 8) Delete Period
`DELETE /bell-schedules/periods/:periodId`

Response `204 No Content`. Timetable entries that used it fall back to the time slot's times.
