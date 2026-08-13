# Medical Records API

**Base path:** `/medical-records`

Manage student medical notes for authenticated staff users.

## Auth
- Guard: `RolesGuard`
- Read endpoints are available to authenticated users.
- Write operations require permissions: `medical_records.create` / `medical_records.update` / `medical_records.delete` (via `@RequirePermissions`)

## Response shape
- List endpoints return `{ ok, message, meta: { total, query }, result: [] }`
- Single-item create/get/update endpoints return `{ ok, message, result }`
- Delete returns `204 No Content`

## Endpoints

### Create medical record
- **POST** `/medical-records`
- **Body (CreateMedicalRecordDto):**
  - `student_id` (int, required)
  - `note` (string, required, 1..5000 chars before trimming)
- **Behavior:**
  - validates student existence
  - trims and stores `note`
  - stores audit fields from authenticated user (`created_by`, `updated_by`)

### List medical records
- **GET** `/medical-records`
- **Query (GetMedicalRecordDto):**
  - `id` (int, optional)
  - `student_id` (int, optional)
  - `created_by` (int, optional)
  - `updated_by` (int, optional)
- **Response notes:**
  - sorted by `created_at DESC`, then `id DESC`
  - each record includes `created_by_name` and `updated_by_name`
  - returns `meta.total` and `result` list

### Get one medical record
- **GET** `/medical-records/:id`

### Update medical record
- **PATCH** `/medical-records/:id`
- **Body (UpdateMedicalRecordDto):** partial of create fields.

### Delete medical record
- **DELETE** `/medical-records/:id`

## Example create request

```http
POST /medical-records
Authorization: Bearer <jwt>
Content-Type: application/json

{
  "student_id": 25,
  "note": "Peanut allergy. Keep epinephrine available during field trips."
}
```

## Example create response

```json
{
  "ok": true,
  "message": "Medical record created successfully",
  "result": {
    "id": 1,
    "student_id": 25,
    "note": "Peanut allergy. Keep epinephrine available during field trips.",
    "created_by": 9,
    "created_by_name": "Nodir Rasulov",
    "created_at": "2026-04-29T09:40:14.482Z",
    "updated_by": 9,
    "updated_by_name": "Nodir Rasulov",
    "updated_at": "2026-04-29T09:40:14.482Z"
  }
}
```

## Example list request

```http
GET /medical-records?student_id=25
Authorization: Bearer <jwt>
```

## Example list response

```json
{
  "ok": true,
  "message": "Medical records retrieved successfully",
  "meta": {
    "total": 2,
    "query": {
      "student_id": 25
    }
  },
  "result": [
    {
      "id": 3,
      "student_id": 25,
      "note": "Lactose intolerance reported by parent.",
      "created_by": 11,
      "created_by_name": "Saida Karimova",
      "created_at": "2026-04-30T11:16:55.002Z",
      "updated_by": 11,
      "updated_by_name": "Saida Karimova",
      "updated_at": "2026-04-30T11:16:55.002Z"
    },
    {
      "id": 1,
      "student_id": 25,
      "note": "Peanut allergy. Keep epinephrine available during field trips.",
      "created_by": 9,
      "created_by_name": "Nodir Rasulov",
      "created_at": "2026-04-29T09:40:14.482Z",
      "updated_by": 9,
      "updated_by_name": "Nodir Rasulov",
      "updated_at": "2026-04-29T09:40:14.482Z"
    }
  ]
}
```

## Notes

- `note` is required and whitespace-only values are rejected with `note must not be empty`.
- Unlike the other health resources, medical record responses also include `created_by_name` and `updated_by_name`.
- `DELETE /medical-records/:id` returns `204` with no response body.
## Example get one

```http
GET /medical-records/12
Authorization: Bearer <jwt>
```

Returns `{ "ok": true, "message": "Medical record retrieved successfully", "result": { ... } }`
with the same `result` shape as the create response. `404` if not found.

## Example update

```http
PATCH /medical-records/12
Authorization: Bearer <jwt>
Content-Type: application/json
```
```json
{
  "note": "Updated after review"
}
```

Returns `{ "ok": true, "message": "Medical record updated successfully", "result": { ... } }`
with the updated fields applied. `400` if the body is empty; `404` if not found.

## Example delete

```http
DELETE /medical-records/12
Authorization: Bearer <jwt>
```

Returns `204 No Content` (empty body). `404` if not found.
