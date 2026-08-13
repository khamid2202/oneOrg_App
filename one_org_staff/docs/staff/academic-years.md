# Academic Years API

**Base path:** `/academic-years`

Manage academic year definitions with caching support (Redis, 7-day TTL;
mutations invalidate the cache).

## Auth
- Guard: `RolesGuard` + permission checks via `@RequirePermissions`.
- Permissions:
  - Create: `academic_years.create`
  - Update: `academic_years.update`
  - Delete: `academic_years.delete`
  - List / get one: authenticated

## Endpoints

| Method | Path | Description | Permission |
| --- | --- | --- | --- |
| GET | `/academic-years` | List academic years | authenticated |
| GET | `/academic-years/:id` | Get one academic year | authenticated |
| POST | `/academic-years` | Create an academic year | `academic_years.create` |
| PATCH | `/academic-years/:id` | Update an academic year | `academic_years.update` |
| DELETE | `/academic-years/:id` | Delete an academic year | `academic_years.delete` |

### List academic years
- **GET** `/academic-years`
- **Query (GetAcademicYearDto):** optional `id` (int).
- Rows are ordered by `start_date` descending; `created_by` / `updated_by` are
  resolved to user full names, and derived `start_year` / `end_year` are added.

**Example request**
```http
GET /academic-years
```

**Example response**
```json
{
  "ok": true,
  "message": "Academic years retrieved successfully",
  "meta": { "total": 1 },
  "result": [
    {
      "id": 3,
      "name": "2025-2026",
      "start_date": "2025-09-01",
      "end_date": "2026-06-30",
      "is_active": true,
      "created_by": "Kamola Karimova",
      "created_at": "2025-06-01T09:00:00.000Z",
      "updated_by": null,
      "updated_at": "2025-06-01T09:00:00.000Z",
      "start_year": 2025,
      "end_year": 2026
    }
  ]
}
```

### Get one
- **GET** `/academic-years/:id`
- `404` if not found.

**Example request**
```http
GET /academic-years/3
```

**Example response**
```json
{
  "ok": true,
  "message": "Academic year retrieved successfully",
  "result": {
    "id": 3,
    "name": "2025-2026",
    "start_date": "2025-09-01",
    "end_date": "2026-06-30",
    "is_active": true,
    "created_by": "Kamola Karimova",
    "created_at": "2025-06-01T09:00:00.000Z",
    "updated_by": null,
    "updated_at": "2025-06-01T09:00:00.000Z",
    "start_year": 2025,
    "end_year": 2026
  }
}
```

### Create
- **POST** `/academic-years`
- **Body (CreateAcademicYearDto):** `name` (3-100 chars, unique — `400` on
  duplicate), `start_date` (ISO date), `end_date` (ISO date), `is_active`
  (boolean).
- **Note:** the created row is returned nested — `result` holds the full
  get-one envelope (`{ ok, message, result }`).

**Example request**
```json
{
  "name": "2026-2027",
  "start_date": "2026-09-01",
  "end_date": "2027-06-30",
  "is_active": false
}
```

**Example response**
```json
{
  "ok": true,
  "message": "Academic year created successfully",
  "result": {
    "ok": true,
    "message": "Academic year retrieved successfully",
    "result": {
      "id": 4,
      "name": "2026-2027",
      "start_date": "2026-09-01",
      "end_date": "2027-06-30",
      "is_active": false,
      "created_by": "Kamola Karimova",
      "created_at": "2026-06-01T09:00:00.000Z",
      "updated_by": null,
      "updated_at": "2026-06-01T09:00:00.000Z",
      "start_year": 2026,
      "end_year": 2027
    }
  }
}
```

### Update
- **PATCH** `/academic-years/:id`
- **Body (UpdateAcademicYearDto):** partial of the create fields.
- `400` if the body is empty, if no field actually changes, or if the new `name`
  collides with another year; `404` if the year does not exist.
- The response nests the get-one envelope under `result`, like create.

**Example request**
```http
PATCH /academic-years/4
```
```json
{
  "is_active": true
}
```

**Example response**
```json
{
  "ok": true,
  "message": "Academic year updated successfully",
  "result": {
    "ok": true,
    "message": "Academic year retrieved successfully",
    "result": {
      "id": 4,
      "name": "2026-2027",
      "start_date": "2026-09-01",
      "end_date": "2027-06-30",
      "is_active": true,
      "created_by": "Kamola Karimova",
      "created_at": "2026-06-01T09:00:00.000Z",
      "updated_by": "Kamola Karimova",
      "updated_at": "2026-08-15T10:00:00.000Z",
      "start_year": 2026,
      "end_year": 2027
    }
  }
}
```

### Delete
- **DELETE** `/academic-years/:id`
- Returns `204 No Content` (empty body).
- `400` if the year is still linked to groups or invoices; `404` if not found.

**Example request**
```http
DELETE /academic-years/4
```

## Usage notes
- Results are cached; create/update/delete invalidate the relevant keys.

## Frontend suggestions
- Cache list results per query to avoid duplicate requests.
- After create/update/delete, refetch the list to sync cache state.
