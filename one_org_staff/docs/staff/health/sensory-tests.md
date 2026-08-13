# Sensory Tests API

**Base path:** `/sensory-tests`

Manage vision and hearing screening records.

## Auth
- Guard: `RolesGuard`
- Read endpoints are available to authenticated users.
- Write operations require permissions: `sensory_tests.create` / `sensory_tests.update` / `sensory_tests.delete` (via `@RequirePermissions`)

## Response shape
- List endpoints return `{ ok, message, meta: { total, query }, result: [] }`
- Single-item create/get/update endpoints return `{ ok, message, result }`
- Delete returns `204 No Content`

## Endpoints

### Create sensory test
- **POST** `/sensory-tests`
- **Body (CreateSensoryTestDto):**
  - `student_id` (int, required)
  - `vision_left` (string, required, 1..10)
  - `vision_right` (string, required, 1..10)
  - `color_blindness` (boolean, required)
  - `hearing_left` (string, required, 1..50)
  - `hearing_right` (string, required, 1..50)
  - `note` (string, optional, max 255)

### List sensory tests
- **GET** `/sensory-tests`
- **Query (GetSensoryTestDto):**
  - `id` (int, optional)
  - `student_id` (int, optional)
  - `color_blindness` (boolean, optional)
  - `created_by` (int, optional)
  - `updated_by` (int, optional)

### Get one sensory test
- **GET** `/sensory-tests/:id`

### Update sensory test
- **PATCH** `/sensory-tests/:id`
- **Body:** partial of create fields.

### Delete sensory test
- **DELETE** `/sensory-tests/:id`

## Example create request

```http
POST /sensory-tests
Authorization: Bearer <jwt>
Content-Type: application/json

{
  "student_id": 25,
  "vision_left": "20/25",
  "vision_right": "20/20",
  "color_blindness": false,
  "hearing_left": "Normal",
  "hearing_right": "Normal",
  "note": "Recommend repeating distance vision screening next term."
}
```

## Example create response

```json
{
  "ok": true,
  "message": "Sensory test created successfully",
  "result": {
    "id": 6,
    "student_id": 25,
    "vision_left": "20/25",
    "vision_right": "20/20",
    "color_blindness": false,
    "hearing_left": "Normal",
    "hearing_right": "Normal",
    "note": "Recommend repeating distance vision screening next term.",
    "created_at": "2026-05-01T08:49:58.331Z",
    "created_by": 9,
    "updated_at": "2026-05-01T08:49:58.331Z",
    "updated_by": 9
  }
}
```

## Example list request

```http
GET /sensory-tests?student_id=25&color_blindness=false
Authorization: Bearer <jwt>
```

## Example list response

```json
{
  "ok": true,
  "message": "Sensory tests retrieved successfully",
  "meta": {
    "total": 1,
    "query": {
      "student_id": 25,
      "color_blindness": false
    }
  },
  "result": [
    {
      "id": 6,
      "student_id": 25,
      "vision_left": "20/25",
      "vision_right": "20/20",
      "color_blindness": false,
      "hearing_left": "Normal",
      "hearing_right": "Normal",
      "note": "Recommend repeating distance vision screening next term.",
      "created_at": "2026-05-01T08:49:58.331Z",
      "created_by": 9,
      "updated_at": "2026-05-01T08:49:58.331Z",
      "updated_by": 9
    }
  ]
}
```

## Notes

- Boolean query parameters should be sent as `true` or `false`.
- Required strings are trimmed and rejected if they become empty after trimming.
- Empty optional `note` values are stored as `null`.
## Example get one

```http
GET /sensory-tests/12
Authorization: Bearer <jwt>
```

Returns `{ "ok": true, "message": "Sensory test retrieved successfully", "result": { ... } }`
with the same `result` shape as the create response. `404` if not found.

## Example update

```http
PATCH /sensory-tests/12
Authorization: Bearer <jwt>
Content-Type: application/json
```
```json
{
  "note": "Repeat test next term"
}
```

Returns `{ "ok": true, "message": "Sensory test updated successfully", "result": { ... } }`
with the updated fields applied. `400` if the body is empty; `404` if not found.

## Example delete

```http
DELETE /sensory-tests/12
Authorization: Bearer <jwt>
```

Returns `204 No Content` (empty body). `404` if not found.
