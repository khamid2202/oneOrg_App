# Subjects API

**Base path:** `/subjects`

Manage academic subjects with optional Excel import. Reads are cached in Redis;
mutations invalidate the cache.

## Auth
- Guard: `RolesGuard` + permission checks via `@RequirePermissions`.
- Permissions:
  - Create / upload: `subjects.create`
  - Update: `subjects.update`
  - Delete: `subjects.delete`
  - List / get one: authenticated

## Endpoints

| Method | Path | Description | Permission |
| --- | --- | --- | --- |
| GET | `/subjects` (or `/subjects/all`) | List subjects | authenticated |
| GET | `/subjects/:id` | Get one subject | authenticated |
| POST | `/subjects/upload` | Bulk import from Excel | `subjects.create` |
| POST | `/subjects` | Create a subject | `subjects.create` |
| PATCH | `/subjects/:id` | Update a subject | `subjects.update` |
| DELETE | `/subjects/:id` | Delete a subject | `subjects.delete` |

### List subjects
- **GET** `/subjects` (alias **GET** `/subjects/all`)
- Returns a **bare array** (no `ok`/`meta` envelope), ordered by id;
  `created_by` / `updated_by` are resolved to user full names.

**Example request**
```http
GET /subjects
```

**Example response**
```json
[
  {
    "id": 44,
    "name": "Mathematics",
    "description": "Algebra and geometry",
    "is_active": true,
    "created_by": "Kamola Karimova",
    "created_at": "2025-08-20T09:00:00.000Z",
    "updated_by": null,
    "updated_at": null
  },
  {
    "id": 45,
    "name": "Physics",
    "description": null,
    "is_active": true,
    "created_by": "Kamola Karimova",
    "created_at": "2025-08-20T09:01:00.000Z",
    "updated_by": null,
    "updated_at": null
  }
]
```

### Get one
- **GET** `/subjects/:id`
- Returns a **bare subject object**; `400` if not found.

**Example request**
```http
GET /subjects/44
```

**Example response**
```json
{
  "id": 44,
  "name": "Mathematics",
  "description": "Algebra and geometry",
  "is_active": true,
  "created_by": "Kamola Karimova",
  "created_at": "2025-08-20T09:00:00.000Z",
  "updated_by": null,
  "updated_at": null
}
```

### Upload subjects (Excel)
- **POST** `/subjects/upload`
- **Body:** `multipart/form-data` with `file` (Excel workbook). `400` if the
  file is missing, has no sheets, is empty, or contains no valid rows.
- Rows with an `id` update the existing subject; rows without an `id` insert
  (duplicate names are skipped).

**Example request**
```http
POST /subjects/upload
Content-Type: multipart/form-data; boundary=----X

------X
Content-Disposition: form-data; name="file"; filename="subjects.xlsx"
Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet

<binary>
------X--
```

**Example response**
```json
{
  "ok": true,
  "inserted": 10,
  "updated": 2,
  "skipped": 1
}
```

### Create subject
- **POST** `/subjects`
- **Body (CreateSubjectDto):** `name` (string, unique — `400` on duplicate),
  optional `description`.

**Example request**
```json
{
  "name": "Chemistry",
  "description": "Organic and inorganic chemistry"
}
```

**Example response**
```json
{
  "ok": true,
  "message": "Subject created successfully",
  "subject": {
    "id": 46,
    "name": "Chemistry",
    "description": "Organic and inorganic chemistry",
    "is_active": true,
    "created_by": "Kamola Karimova",
    "created_at": "2025-08-21T10:00:00.000Z",
    "updated_by": null,
    "updated_at": null
  }
}
```

### Update subject
- **PATCH** `/subjects/:id`
- **Body (UpdateSubjectDto):** partial of the create fields. `400` if the
  subject is missing, the body is empty, or the new name duplicates another
  subject.

**Example request**
```http
PATCH /subjects/46
```
```json
{
  "description": "General chemistry"
}
```

**Example response**
```json
{
  "ok": true,
  "message": "Subject updated successfully",
  "subject": {
    "id": 46,
    "name": "Chemistry",
    "description": "General chemistry",
    "is_active": true,
    "created_by": "Kamola Karimova",
    "created_at": "2025-08-21T10:00:00.000Z",
    "updated_by": "Kamola Karimova",
    "updated_at": "2025-08-22T09:30:00.000Z"
  }
}
```

### Delete subject
- **DELETE** `/subjects/:id`
- Returns `204 No Content` (empty body). `400` if the subject does not exist or
  is still in use (e.g. referenced by the timetable).

**Example request**
```http
DELETE /subjects/46
```

## Usage notes
- Upload validates presence of `file`; imports run under user context for audit.
- List/get responses are cached via Redis in the service layer.

## Frontend suggestions
- Debounce subject search inputs when listing.
- Show upload progress for bulk imports.
