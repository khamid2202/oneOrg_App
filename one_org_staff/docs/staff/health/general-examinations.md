# General Examinations API

**Base path:** `/general-examinations`

Manage broad physical examination records for students.

## Auth
- Guard: `RolesGuard`
- Read endpoints are available to authenticated users.
- Write operations require permissions: `general_examinations.create` / `general_examinations.update` / `general_examinations.delete` (via `@RequirePermissions`)

## Response shape
- List endpoints return `{ ok, message, meta: { total, query }, result: [] }`
- Single-item create/get/update endpoints return `{ ok, message, result }`
- Delete returns `204 No Content`

## Endpoints

### Create general examination
- **POST** `/general-examinations`
- **Body (CreateGeneralExaminationDto):**
  - `student_id` (int, required)
  - `skin` (string, required, 1..5000)
  - `eyes` (string, required, 1..5000)
  - `ears` (string, required, 1..5000)
  - `throat` (string, required, 1..5000)
  - `lungs` (string, required, 1..5000)
  - `heart` (string, required, 1..5000)
  - `posture` (string, required, 1..5000)
  - `note` (string, optional, max 255)

### List general examinations
- **GET** `/general-examinations`
- **Query (GetGeneralExaminationDto):**
  - `id` (int, optional)
  - `student_id` (int, optional)
  - `created_by` (int, optional)
  - `updated_by` (int, optional)

### Get one general examination
- **GET** `/general-examinations/:id`

### Update general examination
- **PATCH** `/general-examinations/:id`
- **Body:** partial of create fields.

### Delete general examination
- **DELETE** `/general-examinations/:id`

## Example create request

```http
POST /general-examinations
Authorization: Bearer <jwt>
Content-Type: application/json

{
  "student_id": 25,
  "skin": "Skin is clear with no active rash or lesions.",
  "eyes": "Pupils equal and reactive to light. No discharge observed.",
  "ears": "Ear canals clear. Tympanic membranes intact.",
  "throat": "No tonsillar enlargement or exudate.",
  "lungs": "Breath sounds clear bilaterally with no wheezing.",
  "heart": "Regular rhythm, no audible murmurs.",
  "posture": "Normal posture and gait.",
  "note": "Cleared for regular PE activities."
}
```

## Example create response

```json
{
  "ok": true,
  "message": "General examination created successfully",
  "result": {
    "id": 5,
    "student_id": 25,
    "skin": "Skin is clear with no active rash or lesions.",
    "eyes": "Pupils equal and reactive to light. No discharge observed.",
    "ears": "Ear canals clear. Tympanic membranes intact.",
    "throat": "No tonsillar enlargement or exudate.",
    "lungs": "Breath sounds clear bilaterally with no wheezing.",
    "heart": "Regular rhythm, no audible murmurs.",
    "posture": "Normal posture and gait.",
    "note": "Cleared for regular PE activities.",
    "created_at": "2026-05-01T08:34:03.681Z",
    "created_by": 9,
    "updated_at": "2026-05-01T08:34:03.681Z",
    "updated_by": 9
  }
}
```

## Example list request

```http
GET /general-examinations?student_id=25
Authorization: Bearer <jwt>
```

## Example list response

```json
{
  "ok": true,
  "message": "General examinations retrieved successfully",
  "meta": {
    "total": 1,
    "query": {
      "student_id": 25
    }
  },
  "result": [
    {
      "id": 5,
      "student_id": 25,
      "skin": "Skin is clear with no active rash or lesions.",
      "eyes": "Pupils equal and reactive to light. No discharge observed.",
      "ears": "Ear canals clear. Tympanic membranes intact.",
      "throat": "No tonsillar enlargement or exudate.",
      "lungs": "Breath sounds clear bilaterally with no wheezing.",
      "heart": "Regular rhythm, no audible murmurs.",
      "posture": "Normal posture and gait.",
      "note": "Cleared for regular PE activities.",
      "created_at": "2026-05-01T08:34:03.681Z",
      "created_by": 9,
      "updated_at": "2026-05-01T08:34:03.681Z",
      "updated_by": 9
    }
  ]
}
```

## Notes

- Required text fields are trimmed and rejected if they become empty after trimming.
- The list endpoint only supports ID and audit-based filters, not text search across examination fields.
- Empty optional `note` values are stored as `null`.
## Example get one

```http
GET /general-examinations/12
Authorization: Bearer <jwt>
```

Returns `{ "ok": true, "message": "General examination retrieved successfully", "result": { ... } }`
with the same `result` shape as the create response. `404` if not found.

## Example update

```http
PATCH /general-examinations/12
Authorization: Bearer <jwt>
Content-Type: application/json
```
```json
{
  "note": "Recheck next quarter"
}
```

Returns `{ "ok": true, "message": "General examination updated successfully", "result": { ... } }`
with the updated fields applied. `400` if the body is empty; `404` if not found.

## Example delete

```http
DELETE /general-examinations/12
Authorization: Bearer <jwt>
```

Returns `204 No Content` (empty body). `404` if not found.
