# Diagnoses API

**Base path:** `/diagnoses`

Manage student diagnosis records for authenticated staff users.

## Auth
- Guard: `RolesGuard`
- Read endpoints are available to authenticated users.
- Write operations require permissions: `diagnoses.create` / `diagnoses.update` / `diagnoses.delete` (via `@RequirePermissions`)

## Response shape
- List endpoints return `{ ok, message, meta: { total, query }, result: [] }`
- Single-item create/get/update endpoints return `{ ok, message, result }`
- Delete returns `204 No Content`

## Endpoints

### Create diagnose
- **POST** `/diagnoses`
- **Body (CreateDiagnoseDto):**
  - `student_id` (int, required)
  - `condition` (string, required, 1..255)
  - `severity` (string, required, 1..255)
  - `note` (string, optional, max 255)

### List diagnoses
- **GET** `/diagnoses`
- **Query (GetDiagnoseDto):**
  - `id` (int, optional)
  - `student_id` (int, optional)
  - `condition` (string, optional)
  - `severity` (string, optional)
  - `created_by` (int, optional)
  - `updated_by` (int, optional)

### Get one diagnose
- **GET** `/diagnoses/:id`

### Update diagnose
- **PATCH** `/diagnoses/:id`
- **Body:** partial of create fields.

### Delete diagnose
- **DELETE** `/diagnoses/:id`

## Example create request

```http
POST /diagnoses
Authorization: Bearer <jwt>
Content-Type: application/json

{
  "student_id": 25,
  "condition": "Seasonal allergic rhinitis",
  "severity": "moderate",
  "note": "Symptoms usually worsen in early spring."
}
```

## Example create response

```json
{
  "ok": true,
  "message": "Diagnose created successfully",
  "result": {
    "id": 12,
    "student_id": 25,
    "condition": "Seasonal allergic rhinitis",
    "severity": "moderate",
    "note": "Symptoms usually worsen in early spring.",
    "created_at": "2026-05-01T08:29:52.104Z",
    "created_by": 9,
    "updated_at": "2026-05-01T08:29:52.104Z",
    "updated_by": 9
  }
}
```

## Example list request

```http
GET /diagnoses?student_id=25&severity=moderate
Authorization: Bearer <jwt>
```

## Example list response

```json
{
  "ok": true,
  "message": "Diagnoses retrieved successfully",
  "meta": {
    "total": 1,
    "query": {
      "student_id": 25,
      "severity": "moderate"
    }
  },
  "result": [
    {
      "id": 12,
      "student_id": 25,
      "condition": "Seasonal allergic rhinitis",
      "severity": "moderate",
      "note": "Symptoms usually worsen in early spring.",
      "created_at": "2026-05-01T08:29:52.104Z",
      "created_by": 9,
      "updated_at": "2026-05-01T08:29:52.104Z",
      "updated_by": 9
    }
  ]
}
```

## Notes

- `condition` and `severity` are exact-match filters on the list endpoint.
- Required strings are trimmed and rejected if they become empty after trimming.
- Empty optional `note` values are stored as `null`.
## Example get one

```http
GET /diagnoses/12
Authorization: Bearer <jwt>
```

Returns `{ "ok": true, "message": "Diagnose retrieved successfully", "result": { ... } }`
with the same `result` shape as the create response. `404` if not found.

## Example update

```http
PATCH /diagnoses/12
Authorization: Bearer <jwt>
Content-Type: application/json
```
```json
{
  "severity": "mild"
}
```

Returns `{ "ok": true, "message": "Diagnose updated successfully", "result": { ... } }`
with the updated fields applied. `400` if the body is empty; `404` if not found.

## Example delete

```http
DELETE /diagnoses/12
Authorization: Bearer <jwt>
```

Returns `204 No Content` (empty body). `404` if not found.
