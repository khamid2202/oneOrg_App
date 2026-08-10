# Academic Years API

**Base path:** `/academic-years`

Manage academic year definitions with caching support.

## Auth
- Guard: `RolesGuard`
- Roles:
  - Create/update: `owner`, `admin`
  - Delete: `owner`

## Endpoints

### List academic years
- **GET** `/academic-years`
- **Query:** filters per `GetAcademicYearDto` (e.g., `id`, date ranges).

### Get one
- **GET** `/academic-years/:id`

### Create
- **POST** `/academic-years`
- **Body (CreateAcademicYearDto):** `name` (3-100 chars), `start_date` (ISO), `end_date` (ISO), `is_active` (boolean).

### Update
- **PATCH** `/academic-years/:id`
- **Body (UpdateAcademicYearDto):** partial of create fields.

### Delete
- **DELETE** `/academic-years/:id`
- **Role:** `owner` only.

## Usage notes
- Results may be cached; updates invalidate relevant keys.

## Example request
- **Method:** GET
- **Path:** `/academic-years`
- **Query:** `?id=1`
- **Request body:**
```json
{}
```

## Example response
```json
{
  "ok": true,
  "result": [
    {
      "id": 1,
      "name": "2025-2026",
      "start_date": "2025-09-01",
      "end_date": "2026-06-30",
      "is_active": true
    }
  ]
}
```

## Frontend suggestions
- Cache list results per query to avoid duplicate requests.
- After create/update/delete, refetch the list to sync cache state.
