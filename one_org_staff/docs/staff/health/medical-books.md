# Medical Books API

**Base path:** `/medical-books`

Manage the primary medical profile record for each student.

## Auth
- Guard: `RolesGuard`
- Read endpoints are available to authenticated users.
- Write operations require permissions: `medical_books.create` / `medical_books.update` / `medical_books.delete` (via `@RequirePermissions`)

## Response shape
- List endpoints return `{ ok, message, meta: { total, query }, result: [] }`
- Single-item create/get/update endpoints return `{ ok, message, result }`
- Delete returns `204 No Content`

## Endpoints

### Create medical book
- **POST** `/medical-books`
- **Body (CreateMedicalBookDto):**
  - `student_id` (int, required)
  - `date_of_birth` (ISO date string, required)
  - `gender` (string, required, 1..10)
- **Behavior:** validates student existence and enforces one medical book per student.

### List medical books
- **GET** `/medical-books`
- **Query (GetMedicalBookDto):**
  - `id` (int, optional)
  - `student_id` (int, optional)
  - `gender` (string, optional)
  - `created_by` (int, optional)
  - `updated_by` (int, optional)

### Get one medical book
- **GET** `/medical-books/:id`

### Update medical book
- **PATCH** `/medical-books/:id`
- **Body:** partial of create fields.

### Delete medical book
- **DELETE** `/medical-books/:id`

## Example create request

```http
POST /medical-books
Authorization: Bearer <jwt>
Content-Type: application/json

{
  "student_id": 25,
  "date_of_birth": "2010-04-17",
  "gender": "female"
}
```

## Example create response

```json
{
  "ok": true,
  "message": "Medical book created successfully",
  "result": {
    "id": 3,
    "student_id": 25,
    "date_of_birth": "2010-04-17T00:00:00.000Z",
    "gender": "female",
    "created_at": "2026-05-01T08:42:13.507Z",
    "created_by": 9,
    "updated_at": "2026-05-01T08:42:13.507Z",
    "updated_by": 9
  }
}
```

## Example list request

```http
GET /medical-books?gender=female
Authorization: Bearer <jwt>
```

## Example list response

```json
{
  "ok": true,
  "message": "Medical books retrieved successfully",
  "meta": {
    "total": 1,
    "query": {
      "gender": "female"
    }
  },
  "result": [
    {
      "id": 3,
      "student_id": 25,
      "date_of_birth": "2010-04-17T00:00:00.000Z",
      "gender": "female",
      "created_at": "2026-05-01T08:42:13.507Z",
      "created_by": 9,
      "updated_at": "2026-05-01T08:42:13.507Z",
      "updated_by": 9
    }
  ]
}
```

## Notes

- `student_id` is unique across medical books. Creating a second record for the same student returns `Medical book for this student already exists`.
- Send `date_of_birth` as `YYYY-MM-DD`; the stored response value is returned as a timestamp.
- `gender` is an exact-match filter on the list endpoint.
## Example get one

```http
GET /medical-books/12
Authorization: Bearer <jwt>
```

Returns `{ "ok": true, "message": "Medical book retrieved successfully", "result": { ... } }`
with the same `result` shape as the create response. `404` if not found.

## Example update

```http
PATCH /medical-books/12
Authorization: Bearer <jwt>
Content-Type: application/json
```
```json
{
  "gender": "female"
}
```

Returns `{ "ok": true, "message": "Medical book updated successfully", "result": { ... } }`
with the updated fields applied. `400` if the body is empty; `404` if not found.

## Example delete

```http
DELETE /medical-books/12
Authorization: Bearer <jwt>
```

Returns `204 No Content` (empty body). `404` if not found.
