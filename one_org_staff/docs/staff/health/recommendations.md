# Recommendations API

**Base path:** `/recommendations`

Manage health follow-up recommendations for students.

## Auth
- Guard: `RolesGuard`
- Read endpoints are available to authenticated users.
- Write operations require permissions: `recommendations.create` / `recommendations.update` / `recommendations.delete` (via `@RequirePermissions`)

## Response shape
- List endpoints return `{ ok, message, meta: { total, query }, result: [] }`
- Single-item create/get/update endpoints return `{ ok, message, result }`
- Delete returns `204 No Content`

## Endpoints

### Create recommendation
- **POST** `/recommendations`
- **Body (CreateRecommendationDto):**
  - `student_id` (int, required)
  - `recommendation` (string, required, 1..255)
  - `note` (string, optional, max 255)
  - `follow_up_date` (ISO date string, optional)

### List recommendations
- **GET** `/recommendations`
- **Query (GetRecommendationDto):**
  - `id` (int, optional)
  - `student_id` (int, optional)
  - `created_by` (int, optional)
  - `updated_by` (int, optional)

### Get one recommendation
- **GET** `/recommendations/:id`

### Update recommendation
- **PATCH** `/recommendations/:id`
- **Body:** partial of create fields.

### Delete recommendation
- **DELETE** `/recommendations/:id`

## Example create request

```http
POST /recommendations
Authorization: Bearer <jwt>
Content-Type: application/json

{
  "student_id": 25,
  "recommendation": "Schedule dental cleaning and review brushing technique.",
  "note": "Parent requested an appointment after school hours.",
  "follow_up_date": "2026-05-20"
}
```

## Example create response

```json
{
  "ok": true,
  "message": "Recommendation created successfully",
  "result": {
    "id": 9,
    "student_id": 25,
    "recommendation": "Schedule dental cleaning and review brushing technique.",
    "note": "Parent requested an appointment after school hours.",
    "follow_up_date": "2026-05-20T00:00:00.000Z",
    "created_at": "2026-05-01T08:46:22.690Z",
    "created_by": 9,
    "updated_at": "2026-05-01T08:46:22.690Z",
    "updated_by": 9
  }
}
```

## Example list request

```http
GET /recommendations?student_id=25
Authorization: Bearer <jwt>
```

## Example list response

```json
{
  "ok": true,
  "message": "Recommendations retrieved successfully",
  "meta": {
    "total": 1,
    "query": {
      "student_id": 25
    }
  },
  "result": [
    {
      "id": 9,
      "student_id": 25,
      "recommendation": "Schedule dental cleaning and review brushing technique.",
      "note": "Parent requested an appointment after school hours.",
      "follow_up_date": "2026-05-20T00:00:00.000Z",
      "created_at": "2026-05-01T08:46:22.690Z",
      "created_by": 9,
      "updated_at": "2026-05-01T08:46:22.690Z",
      "updated_by": 9
    }
  ]
}
```

## Notes

- Empty optional `note` values are stored as `null`.
- `follow_up_date` can be omitted when there is no scheduled follow-up.
- Required strings are trimmed and rejected if they become empty.
## Example get one

```http
GET /recommendations/12
Authorization: Bearer <jwt>
```

Returns `{ "ok": true, "message": "Recommendation retrieved successfully", "result": { ... } }`
with the same `result` shape as the create response. `404` if not found.

## Example update

```http
PATCH /recommendations/12
Authorization: Bearer <jwt>
Content-Type: application/json
```
```json
{
  "note": "Reviewed by school doctor"
}
```

Returns `{ "ok": true, "message": "Recommendation updated successfully", "result": { ... } }`
with the updated fields applied. `400` if the body is empty; `404` if not found.

## Example delete

```http
DELETE /recommendations/12
Authorization: Bearer <jwt>
```

Returns `204 No Content` (empty body). `404` if not found.
