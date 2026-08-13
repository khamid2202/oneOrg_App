# Documents API

**Base path:** `/documents`

Manage document records for persons (students). Documents are keyed by
`person_id`; multiple rows can exist per person.

## Auth
- Guard: `RolesGuard` + permission checks via `@RequirePermissions`.
- Permissions: `documents.read`, `documents.create`, `documents.update`,
  `documents.delete` per endpoint.
- **Teacher scoping:** users without elevated access only see/manage documents of
  persons currently enrolled in a group they teach (`groups.teacher_id`).

## Data model
- `person_id` (int, required) — the person the document belongs to
- `document_name` (string, required, max 100, trimmed) — e.g. "Birth Certificate", "Passport Copy"
- `document_type` (string, required, max 20, trimmed) — e.g. "passport", "certificate", "medical"
- `document_url` (string, system generated) — Public R2 storage URL of the uploaded document file
- `file` (multipart file upload, max 5 MB) — Required on create; optional on update

## Endpoints

| Method | Path | Description | Permission |
| --- | --- | --- | --- |
| GET | `/documents` | List documents (filtered) | `documents.read` |
| GET | `/documents/:id` | Get one document | `documents.read` |
| POST | `/documents` | Create a document | `documents.create` |
| PATCH | `/documents/:id` | Update a document | `documents.update` |
| DELETE | `/documents/:id` | Delete a document | `documents.delete` |

### List documents
- **GET** `/documents`
- **Query (GetDocumentDto), all optional:** `id`, `person_id`, `created_by`,
  `updated_by` (ints).
- Sorted by `created_at DESC`, then `id DESC`; `created_by` / `updated_by` are
  resolved to user full names.

**Example request**
```http
GET /documents?person_id=100
```

**Example response**
```json
{
  "ok": true,
  "message": "Documents retrieved successfully",
  "meta": { "total": 2, "query": { "person_id": 100 } },
  "result": [
    {
      "id": 5,
      "person_id": 100,
      "document_name": "Birth Certificate",
      "document_type": "certificate",
      "document_url": "https://storage.example.com/docs/birth_cert.pdf",
      "created_by": "Nodir Rasulov",
      "created_at": "2026-07-31T10:00:00.000Z",
      "updated_by": null,
      "updated_at": null
    }
  ]
}
```

### Get one document
- **GET** `/documents/:id`
- `404` if not found (or out of the teacher's scope).

**Example request**
```http
GET /documents/5
```

**Example response**
```json
{
  "ok": true,
  "message": "Document retrieved successfully",
  "result": {
    "id": 5,
    "person_id": 100,
    "document_name": "Birth Certificate",
    "document_type": "certificate",
    "document_url": "https://storage.example.com/docs/birth_cert.pdf",
    "created_by": "Nodir Rasulov",
    "created_at": "2026-07-31T10:00:00.000Z",
    "updated_by": null,
    "updated_at": null
  }
}
```

### Create document
- **POST** `/documents` → `multipart/form-data`
- **Fields:**
  - `person_id` (int, required — `400` if person missing)
  - `document_name` (string, required, max 100)
  - `document_type` (string, required, max 20)
  - `file` (binary file, required, max 5 MB) — file uploaded to R2 storage

**Example request**
```http
POST /documents
Content-Type: multipart/form-data; boundary=----X

------X
Content-Disposition: form-data; name="person_id"

100
------X
Content-Disposition: form-data; name="document_name"

Birth Certificate
------X
Content-Disposition: form-data; name="document_type"

certificate
------X
Content-Disposition: form-data; name="file"; filename="birth_cert.pdf"
Content-Type: application/pdf

<binary>
------X--
```

**Example response**
```json
{
  "ok": true,
  "message": "Document created successfully",
  "result": {
    "id": 5,
    "person_id": 100,
    "document_name": "Birth Certificate",
    "document_type": "certificate",
    "document_url": "https://storage.example.com/docs/birth_cert.pdf",
    "created_by": "Nodir Rasulov",
    "created_at": "2026-07-31T10:00:00.000Z",
    "updated_by": "Nodir Rasulov",
    "updated_at": "2026-07-31T10:00:00.000Z"
  }
}
```

### Update document
- **PATCH** `/documents/:id` → `multipart/form-data`
- **Fields (optional):** `person_id`, `document_name`, `document_type`, `file` (max 5 MB).
- `404` if document missing; `400` if body and file are empty. If a new file is attached, it uploads to R2 and deletes the previous object.

**Example request**
```http
PATCH /documents/5
Content-Type: multipart/form-data; boundary=----X

------X
Content-Disposition: form-data; name="document_name"

Updated Birth Certificate
------X--
```

**Example response**
```json
{
  "ok": true,
  "message": "Document updated successfully",
  "result": {
    "id": 5,
    "person_id": 100,
    "document_name": "Updated Birth Certificate",
    "document_type": "certificate",
    "document_url": "https://storage.example.com/docs/birth_cert.pdf",
    "created_by": "Nodir Rasulov",
    "created_at": "2026-07-31T10:00:00.000Z",
    "updated_by": "Nodir Rasulov",
    "updated_at": "2026-07-31T10:05:00.000Z"
  }
}
```

### Delete document
- **DELETE** `/documents/:id`
- Returns `204 No Content` (empty body); `404` if not found or out of scope.

**Example request**
```http
DELETE /documents/5
```

## Student include

Documents can also be loaded as a nested relation on student read endpoints by
passing `include=documents` (see [Students API](students.md#relations-attached-to-read-responses)):

```http
GET /students?person_id=100&include=documents
GET /students/12?include=documents
```

## Error responses
| Status | Condition |
| --- | --- |
| `400 Bad Request` | Person not found; empty update body |
| `403 Forbidden` | Teacher does not control the student; missing permission |
| `404 Not Found` | Document not found |

## Frontend suggestions
- Create and update one document row per request.
- Use `person_id` to display documents on a student detail page.
- Use `include=documents` on student list/detail endpoints to embed document data
  without a separate request.
