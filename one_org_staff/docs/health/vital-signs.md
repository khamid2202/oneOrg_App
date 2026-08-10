# Vital Signs API

**Base path:** `/vital-signs`

Manage quantitative vital sign measurements for students.

## Auth
- Guard: `RolesGuard`
- Read endpoints are available to authenticated users.
- Write operations require: `owner` | `admin` | `moderator`

## Response shape
- List endpoints return `{ ok, message, meta: { total, query }, result: [] }`
- Single-item create/get/update endpoints return `{ ok, message, result }`
- Delete returns `204 No Content`

## Endpoints

### Create vital sign
- **POST** `/vital-signs`
- **Body (CreateVitalSignDto):**
  - `student_id` (int, required)
  - `height` (number, required)
  - `weight` (number, required)
  - `bmi` (number, required)
  - `blood_pressure_systolic` (number, required)
  - `blood_pressure_diastolic` (number, required)
  - `heart_rate` (number, required)
  - `respiratory_rate` (number, required)
  - `temperature` (number, required)

### List vital signs
- **GET** `/vital-signs`
- **Query (GetVitalSignDto):**
  - `id` (int, optional)
  - `student_id` (int, optional)
  - `created_by` (int, optional)
  - `updated_by` (int, optional)

### Get one vital sign
- **GET** `/vital-signs/:id`

### Update vital sign
- **PATCH** `/vital-signs/:id`
- **Body:** partial of create fields.

### Delete vital sign
- **DELETE** `/vital-signs/:id`

## Example create request

```http
POST /vital-signs
Authorization: Bearer <jwt>
Content-Type: application/json

{
  "student_id": 25,
  "height": 154.2,
  "weight": 47.8,
  "bmi": 20.1,
  "blood_pressure_systolic": 108,
  "blood_pressure_diastolic": 68,
  "heart_rate": 76,
  "respiratory_rate": 17,
  "temperature": 36.7
}
```

## Example create response

```json
{
  "ok": true,
  "message": "Vital sign created successfully",
  "result": {
    "id": 14,
    "student_id": 25,
    "height": 154.2,
    "weight": 47.8,
    "bmi": 20.1,
    "blood_pressure_systolic": 108,
    "blood_pressure_diastolic": 68,
    "heart_rate": 76,
    "respiratory_rate": 17,
    "temperature": 36.7,
    "created_at": "2026-05-01T08:53:11.990Z",
    "created_by": 9,
    "updated_at": "2026-05-01T08:53:11.990Z",
    "updated_by": 9
  }
}
```

## Example list request

```http
GET /vital-signs?student_id=25
Authorization: Bearer <jwt>
```

## Example list response

```json
{
  "ok": true,
  "message": "Vital signs retrieved successfully",
  "meta": {
    "total": 1,
    "query": {
      "student_id": 25
    }
  },
  "result": [
    {
      "id": 14,
      "student_id": 25,
      "height": 154.2,
      "weight": 47.8,
      "bmi": 20.1,
      "blood_pressure_systolic": 108,
      "blood_pressure_diastolic": 68,
      "heart_rate": 76,
      "respiratory_rate": 17,
      "temperature": 36.7,
      "created_at": "2026-05-01T08:53:11.990Z",
      "created_by": 9,
      "updated_at": "2026-05-01T08:53:11.990Z",
      "updated_by": 9
    }
  ]
}
```

## Notes

- Send numeric payload values as JSON numbers, not strings.
- The backend expects `bmi` from the client; it is not derived from `height` and `weight`.
- `DELETE /vital-signs/:id` returns `204` with no response body.