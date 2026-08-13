# Persons API

**Base path:** `/persons`

Manage person-level resources. A **person** is the underlying identity that a
student enrollment (and other records) points at via `person_id`. A person has a
unique `code`, a `full_name`, an optional `grade` (nullable integer), optional
detail fields (`birth_date`, `address`, `phone`, `gender`, `birth_certificate_number`, `birth_certificate_url`, `passport_number`, `passport_issue_date`, `passport_expiration_date`, `passport_issued_by`, `passport_url`), and an optional
profile picture (stored on the Person record and keyed by `personId`, not an
enrollment id).

## Auth
- Guard: `RolesGuard` + permission checks via `@RequirePermissions`.
- Permissions:
  - List: `persons.read`
  - Export: `persons.export`
  - Create (single) and bulk upload: `persons.create`
  - Update (single), upload/replace picture, remove picture: `persons.update`
  - Get picture: `persons.read`

## Endpoints

| Method | Path | Description | Permission |
| --- | --- | --- | --- |
| GET | `/persons` | List persons (paginated, searchable) | `persons.read` |
| GET | `/persons/export` | Export persons to Excel | `persons.export` |
| POST | `/persons` | Create a person | `persons.create` |
| PATCH | `/persons/:id` | Update a person | `persons.update` |
| POST | `/persons/upload` | Bulk-import persons from a spreadsheet | `persons.create` |
| GET | `/persons/:personId/picture` | Get a person's picture URL | `persons.read` |
| POST | `/persons/:personId/picture` | Upload/replace a person's picture | `persons.update` |
| DELETE | `/persons/:personId/picture` | Remove a person's picture | `persons.update` |

## List persons
- **GET** `/persons`
- **Query (GetPersonDto):** all optional —
  - `search` (string, 1–100) — case-insensitive match against `full_name` or
    `code`.
  - `grade` (int) — exact-match filter on the person's grade.
  - `page` (int ≥ 1, default `1`), `limit` (int 1–100, default `50`).
- Returns `{ ok, message, meta: { total, page, limit, pages }, result: Person[] }`,
  ordered by `id` ascending.

**Example request**
```http
GET /persons?search=ali&grade=9&page=1&limit=50
```

**Example response**
```json
{
  "ok": true,
  "message": "Persons retrieved successfully",
  "meta": { "total": 1, "page": 1, "limit": 50, "pages": 1 },
  "result": [
    {
      "id": 100,
      "code": "P-1001",
      "full_name": "Ali Valiyev",
      "grade": 9,
      "birth_date": "2010-03-15",
      "address": "Tashkent, Yunusobod 4",
      "phone": "+998901234567",
      "gender": "male",
      "birth_certificate_number": null,
      "birth_certificate_url": null,
      "passport_number": "AA1234567",
      "passport_issue_date": "2020-01-15",
      "passport_expiration_date": "2030-01-15",
      "passport_issued_by": "IIB Tashkent",
      "passport_url": null,
      "picture_url": null,
      "created_by": 7,
      "created_at": "2026-07-08T09:00:00.000Z",
      "updated_by": null,
      "updated_at": "2026-07-08T09:00:00.000Z"
    }
  ]
}
```

## Export persons
- **GET** `/persons/export`
- **Query (GetPersonDto):** honours the same optional `search` and `grade`
  filters as the list; pagination is ignored — all matching rows are exported.
- Streams an `.xlsx` file (`persons.xlsx`) with columns: `ID`, `Code`,
  `Full Name`, `Grade`, `Birth Date`, `Address`, `Phone`, `Gender`,
  `Birth Certificate Number`, `Birth Certificate URL`, `Passport Number`,
  `Passport Issue Date`, `Passport Expiration Date`, `Passport Issued By`,
  `Passport URL`, `Picture URL`, `Created By`, `Created At`, `Updated At`.

## Create person
- **POST** `/persons`
- **Body (CreatePersonDto):**
  - `code` (string, 1–100, required) — must be unique.
  - `full_name` (string, 1–100, required).
  - `grade` (int, optional) — the person's grade level.
  - `birth_date` (ISO date string, optional) — e.g. `"2010-03-15"`.
  - `address` (string, optional).
  - `phone` (string, optional).
  - `gender` (string, optional).
  - `birth_certificate_number` (string, optional).
  - `birth_certificate_url` (string, optional).
  - `passport_number` (string, optional).
  - `passport_issue_date` (string, optional).
  - `passport_expiration_date` (string, optional).
  - `passport_issued_by` (string, optional).
  - `passport_url` (string, optional).
- `400` if `code` is already taken.

**Example request**
```http
POST /persons
Content-Type: application/json

{ "code": "P-1001", "full_name": "Ali Valiyev", "grade": 9, "birth_date": "2010-03-15", "gender": "male" }
```

**Example response**
```json
{
  "ok": true,
  "message": "Person created successfully",
  "result": {
    "id": 100,
    "code": "P-1001",
    "full_name": "Ali Valiyev",
    "grade": 9,
    "birth_date": "2010-03-15",
    "address": null,
    "phone": null,
    "gender": "male",
    "picture_url": null,
    "created_by": 7
  }
}
```

## Update person
- **PATCH** `/persons/:id`
- **Body (UpdatePersonDto):** all fields optional —
  - `code` (string, 1–100, optional) — must be unique if changed.
  - `full_name` (string, 1–100, optional).
  - `grade` (int, optional).
  - `birth_date` (ISO date string, optional).
  - `address` (string, optional).
  - `phone` (string, optional).
  - `gender` (string, optional).
  - `birth_certificate_number` (string, optional).
  - `birth_certificate_url` (string, optional).
  - `passport_number` (string, optional).
  - `passport_issue_date` (string, optional).
  - `passport_expiration_date` (string, optional).
  - `passport_issued_by` (string, optional).
  - `passport_url` (string, optional).
- `404` if person is not found.
- `400` if `code` is updated to a value already taken by another person.

**Example request**
```http
PATCH /persons/100
Content-Type: application/json

{
  "full_name": "Ali Valiyev Updated",
  "phone": "+998901234567"
}
```

**Example response**
```json
{
  "ok": true,
  "message": "Person updated successfully",
  "result": {
    "id": 100,
    "code": "P-1001",
    "full_name": "Ali Valiyev Updated",
    "grade": 9,
    "birth_date": "2010-03-15",
    "address": null,
    "phone": "+998901234567",
    "gender": "male",
    "birth_certificate_number": null,
    "birth_certificate_url": null,
    "passport_number": null,
    "passport_issue_date": null,
    "passport_expiration_date": null,
    "passport_issued_by": null,
    "passport_url": null,
    "picture_url": null,
    "created_by": 7,
    "created_at": "2026-07-08T09:00:00.000Z",
    "updated_by": 7,
    "updated_at": "2026-08-05T11:22:00.000Z"
  }
}
```

## Bulk upload
- **POST** `/persons/upload` → `multipart/form-data` with an `.xlsx`/`.xls`
  `file` (max 2 MB).
- Each row must provide a `code` and a `full_name` column (header row required).
  Optional columns: `grade`, `birth_date`, `address`, `phone`, `gender`, `birth_certificate_number`, `birth_certificate_url`, `passport_number`, `passport_issue_date`, `passport_expiration_date`, `passport_issued_by`, `passport_url`.
- Rows are processed independently: a row is **skipped** (not created) and
  reported in `errors` when it is missing a field, exceeds 100 characters,
  duplicates a `code` already used earlier in the same file, or duplicates a
  `code` that already exists in the database. Valid rows are created.
- Returns `{ ok, message, result: { created, skipped, errors } }`, where
  `errors` is a list of `{ row, message }` (row numbers are 1-based including
  the header, so the first data row is `2`).

**Example request**
```http
POST /persons/upload
Content-Type: multipart/form-data; boundary=----X

------X
Content-Disposition: form-data; name="file"; filename="persons.xlsx"
Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet

<binary>
------X--
```

**Example response**
```json
{
  "ok": true,
  "message": "Persons imported",
  "result": {
    "created": 2,
    "skipped": 1,
    "errors": [
      { "row": 4, "message": "Person with code \"P-1001\" already exists" }
    ]
  }
}
```

## Profile picture
Pictures are stored on the **Person** record, so these routes are keyed by
`personId` (the `person_id` of an enrollment, not the enrollment id).

### Get picture
- **GET** `/persons/:personId/picture` → `{ ok, picture_url }`.

**Example request**
```http
GET /persons/100/picture
```

**Example response**
```json
{
  "ok": true,
  "picture_url": "https://cdn.example.com/persons/100/9f86d081884c7d65.jpg"
}
```

### Upload/replace picture
- **POST** `/persons/:personId/picture` → `multipart/form-data` with an image
  `file`; uploads to R2, persists the URL, and best-effort deletes the previous
  object. `400` if the file is missing.

**Example request**
```http
POST /persons/100/picture
Content-Type: multipart/form-data; boundary=----X

------X
Content-Disposition: form-data; name="file"; filename="ali.jpg"
Content-Type: image/jpeg

<binary>
------X--
```

**Example response**
```json
{
  "ok": true,
  "picture_url": "https://cdn.example.com/persons/100/9f86d081884c7d65.jpg"
}
```

### Remove picture
- **DELETE** `/persons/:personId/picture` → removes the stored object and
  clears the URL.

**Example request**
```http
DELETE /persons/100/picture
```

**Example response**
```json
{
  "ok": true,
  "picture_url": null
}
```

## Error responses
| Status | Condition |
| --- | --- |
| `400 Bad Request` | Picture file is missing or not a valid image |
| `404 Not Found` | Person not found |
| `403 Forbidden` | Missing the required permission for the mutation |

## Frontend suggestions
- Picture routes are keyed by `personId` — use the enrollment's `person_id`, not
  its `id`.
- The read response's flattened `picture_url` on a student mirrors what these
  routes manage; refetch the student (or the picture) after an upload/remove.
