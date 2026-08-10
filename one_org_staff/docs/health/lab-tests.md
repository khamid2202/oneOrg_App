# Lab Tests API

**Base path:** `/lab-tests`

Manage laboratory test results for students.

## Auth
- Guard: `RolesGuard`
- Read endpoints are available to authenticated users.
- Write operations require: `owner` | `admin` | `moderator`

## Response shape
- List endpoints return `{ ok, message, meta: { total, query }, result: [] }`
- Single-item create/get/update endpoints return `{ ok, message, result }`
- Delete returns `204 No Content`

## Endpoints

### Create lab test
- **POST** `/lab-tests`
- **Body (CreateLabTestDto):**
  - `student_id` (int, required)
  - `test_name` (string, required, 1..100)
  - `result` (string, required, 1..100)
  - `unit` (string, required, 1..100)
  - `normal_range` (string, required, 1..100)

### List lab tests
- **GET** `/lab-tests`
- **Query (GetLabTestDto):**
  - `id` (int, optional)
  - `student_id` (int, optional)
  - `test_name` (string, optional)
  - `created_by` (int, optional)
  - `updated_by` (int, optional)

### Get one lab test
- **GET** `/lab-tests/:id`

### Update lab test
- **PATCH** `/lab-tests/:id`
- **Body:** partial of create fields.

### Delete lab test
- **DELETE** `/lab-tests/:id`

## Example create request

```http
POST /lab-tests
Authorization: Bearer <jwt>
Content-Type: application/json

{
  "student_id": 25,
  "test_name": "Fasting Blood Glucose",
  "result": "92",
  "unit": "mg/dL",
  "normal_range": "70-99"
}
```

## Example create response

```json
{
  "ok": true,
  "message": "Lab test created successfully",
  "result": {
    "id": 18,
    "student_id": 25,
    "test_name": "Fasting Blood Glucose",
    "result": "92",
    "unit": "mg/dL",
    "normal_range": "70-99",
    "created_at": "2026-05-01T08:37:46.019Z",
    "created_by": 9,
    "updated_at": "2026-05-01T08:37:46.019Z",
    "updated_by": 9
  }
}
```

## Example list request

```http
GET /lab-tests?student_id=25&test_name=Fasting%20Blood%20Glucose
Authorization: Bearer <jwt>
```

## Example list response

```json
{
  "ok": true,
  "message": "Lab tests retrieved successfully",
  "meta": {
    "total": 1,
    "query": {
      "student_id": 25,
      "test_name": "Fasting Blood Glucose"
    }
  },
  "result": [
    {
      "id": 18,
      "student_id": 25,
      "test_name": "Fasting Blood Glucose",
      "result": "92",
      "unit": "mg/dL",
      "normal_range": "70-99",
      "created_at": "2026-05-01T08:37:46.019Z",
      "created_by": 9,
      "updated_at": "2026-05-01T08:37:46.019Z",
      "updated_by": 9
    }
  ]
}
```

## Notes

- `test_name` is an exact-match query filter, not a contains search.
- All string fields are trimmed before save and rejected if they end up empty.
- `DELETE /lab-tests/:id` returns `204` with no response body.