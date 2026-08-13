# Dental Tests API

**Base path:** `/dental-tests`

Manage student dental screening records for authenticated staff users.

## Auth
- Guard: `RolesGuard`
- Read endpoints are available to authenticated users.
- Write operations require permissions: `dental_tests.create` / `dental_tests.update` / `dental_tests.delete` (via `@RequirePermissions`)

## Response shape
- List endpoints return `{ ok, message, meta: { total, query }, result: [] }`
- Single-item create/get/update endpoints return `{ ok, message, result }`
- Delete returns `204 No Content`

## Endpoints

### Create dental test
- **POST** `/dental-tests`
- **Body (CreateDentalTestDto):**
  - `student_id` (int, required)
  - `has_cavities` (boolean, required)
  - `gum_condition` (string, required, 1..255)
  - `teeth_alignment` (string, required, 1..255)
  - `oral_hygiene` (string, required, 1..255)
  - `recommendations` (string, required, 1..255)
  - `note` (string, optional, max 255)
- **Behavior:** validates student existence, trims string fields, and stores empty optional notes as `null`.

### List dental tests
- **GET** `/dental-tests`
- **Query (GetDentalTestDto):**
  - `id` (int, optional)
  - `student_id` (int, optional)
  - `has_cavities` (boolean, optional)
  - `created_by` (int, optional)
  - `updated_by` (int, optional)

### Get one dental test
- **GET** `/dental-tests/:id`

### Update dental test
- **PATCH** `/dental-tests/:id`
- **Body:** partial of create fields.

### Delete dental test
- **DELETE** `/dental-tests/:id`

## Example create request

```http
POST /dental-tests
Authorization: Bearer <jwt>
Content-Type: application/json

{
  "student_id": 25,
  "has_cavities": true,
  "gum_condition": "Mild gingival redness around upper molars",
  "teeth_alignment": "Mild crowding in lower incisors",
  "oral_hygiene": "Fair",
  "recommendations": "Schedule cleaning and reinforce twice-daily brushing",
  "note": "Needs follow-up cleaning within 3 months."
}
```

## Example create response

```json
{
  "ok": true,
  "message": "Dental test created successfully",
  "result": {
    "id": 7,
    "student_id": 25,
    "has_cavities": true,
    "gum_condition": "Mild gingival redness around upper molars",
    "teeth_alignment": "Mild crowding in lower incisors",
    "oral_hygiene": "Fair",
    "recommendations": "Schedule cleaning and reinforce twice-daily brushing",
    "note": "Needs follow-up cleaning within 3 months.",
    "created_at": "2026-05-01T08:25:11.218Z",
    "created_by": 9,
    "updated_at": "2026-05-01T08:25:11.218Z",
    "updated_by": 9
  }
}
```

## Example list request

```http
GET /dental-tests?student_id=25&has_cavities=true
Authorization: Bearer <jwt>
```

## Example list response

```json
{
  "ok": true,
  "message": "Dental tests retrieved successfully",
  "meta": {
    "total": 1,
    "query": {
      "student_id": 25,
      "has_cavities": true
    }
  },
  "result": [
    {
      "id": 7,
      "student_id": 25,
      "has_cavities": true,
      "gum_condition": "Mild gingival redness around upper molars",
      "teeth_alignment": "Mild crowding in lower incisors",
      "oral_hygiene": "Fair",
      "recommendations": "Schedule cleaning and reinforce twice-daily brushing",
      "note": "Needs follow-up cleaning within 3 months.",
      "created_at": "2026-05-01T08:25:11.218Z",
      "created_by": 9,
      "updated_at": "2026-05-01T08:25:11.218Z",
      "updated_by": 9
    }
  ]
}
```

## Notes

- `has_cavities` is an exact boolean filter on the list endpoint.
- All required string fields are trimmed and rejected if they become empty.
- `DELETE /dental-tests/:id` returns `204` with no response body.
## Example get one

```http
GET /dental-tests/12
Authorization: Bearer <jwt>
```

Returns `{ "ok": true, "message": "Dental test retrieved successfully", "result": { ... } }`
with the same `result` shape as the create response. `404` if not found.

## Example update

```http
PATCH /dental-tests/12
Authorization: Bearer <jwt>
Content-Type: application/json
```
```json
{
  "note": "Follow-up in 6 months"
}
```

Returns `{ "ok": true, "message": "Dental test updated successfully", "result": { ... } }`
with the updated fields applied. `400` if the body is empty; `404` if not found.

## Example delete

```http
DELETE /dental-tests/12
Authorization: Bearer <jwt>
```

Returns `204 No Content` (empty body). `404` if not found.
