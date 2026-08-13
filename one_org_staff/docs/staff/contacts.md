# Contacts API

**Base path:** `/contacts`

Manage emergency/family contact documents for persons (students). Contacts are
keyed by `person_id`; multiple rows can exist per person.

## Auth
- Guard: `RolesGuard` + permission checks via `@RequirePermissions`.
- Permissions: `contacts.read`, `contacts.create`, `contacts.update`,
  `contacts.delete` per endpoint.
- **Teacher scoping:** users without elevated access only see/manage contacts of
  persons currently enrolled in a group they teach (`groups.teacher_id`).

## Data model
- `person_id` (int, required) — the person the contact belongs to
- `full_name` (string, required, max 50, trimmed)
- `relationship` (`self` | `father` | `mother` | `brother` | `sister` | `grandfather` | `grandmother` | `uncle` | `aunt` | `cousin` | `other`)
- `phone_number` (string, required, max 16, trimmed)
- `telegram_id` (nullable; auto-copied from another contact with the same
  normalized phone number when available — not returned by the read endpoints)

## Endpoints

| Method | Path | Description | Permission |
| --- | --- | --- | --- |
| GET | `/contacts` | List contacts (filtered) | `contacts.read` |
| GET | `/contacts/statistics` | Headline summary counts | `contacts.read` |
| GET | `/contacts/statistics/trend` | Counts per created date | `contacts.read` |
| GET | `/contacts/statistics/by-relationship` | Counts grouped by relationship | `contacts.read` |
| GET | `/contacts/statistics/by-student` | Counts grouped by person | `contacts.read` |
| GET | `/contacts/:id` | Get one contact | `contacts.read` |
| POST | `/contacts` | Create a contact | `contacts.create` |
| PATCH | `/contacts/:id` | Update a contact | `contacts.update` |
| DELETE | `/contacts/:id` | Delete a contact | `contacts.delete` |

### List contacts
- **GET** `/contacts`
- **Query (GetContactDto), all optional:** `id`, `person_id`, `created_by`,
  `updated_by` (ints).
- Sorted by `created_at DESC`, then `id DESC`; `created_by` / `updated_by` are
  resolved to user full names.

**Example request**
```http
GET /contacts?person_id=100
```

**Example response**
```json
{
  "ok": true,
  "message": "Contacts retrieved successfully",
  "meta": { "total": 1, "query": { "person_id": 100 } },
  "result": [
    {
      "id": 7,
      "person_id": 100,
      "full_name": "Mubina Xasanova",
      "relationship": "mother",
      "phone_number": "+998901112233",
      "created_by": "Nodir Rasulov",
      "created_at": "2026-04-29T09:40:14.482Z",
      "updated_by": "Nodir Rasulov",
      "updated_at": "2026-04-29T09:40:14.482Z"
    }
  ]
}
```

## Statistics

All `/contacts/statistics*` endpoints share the same optional filters
(`GetContactStatisticsDto`): `person_id`, `relationship`, `created_by`, `date`,
`start_date` / `end_date` (applied to `created_at`, date-only). Responses echo
the filters under `meta` (unused ones as `null`); grouped endpoints add
`meta.total` = number of buckets. `meta` examples below are abbreviated.

### Summary
- **GET** `/contacts/statistics`

**Example request**
```http
GET /contacts/statistics?relationship=mother
```

**Example response**
```json
{
  "ok": true,
  "message": "Contact statistics retrieved successfully",
  "meta": {
    "person_id": null, "relationship": "mother", "created_by": null,
    "date": null, "start_date": null, "end_date": null
  },
  "result": {
    "total": 96,
    "distinct_persons": 95,
    "with_telegram": 60,
    "without_telegram": 36
  }
}
```

### Trend
- **GET** `/contacts/statistics/trend`
- `result`: `[{ date, total }]` per created date, ascending.

**Example request**
```http
GET /contacts/statistics/trend?start_date=2026-04-01&end_date=2026-04-30
```

**Example response**
```json
{
  "ok": true,
  "message": "Contact trend retrieved successfully",
  "meta": { "start_date": "2026-04-01", "end_date": "2026-04-30", "total": 2 },
  "result": [
    { "date": "2026-04-10", "total": 12 },
    { "date": "2026-04-29", "total": 5 }
  ]
}
```

### By relationship
- **GET** `/contacts/statistics/by-relationship`
- `result`: `[{ relationship, total }]` ordered by `total` descending.

**Example request**
```http
GET /contacts/statistics/by-relationship
```

**Example response**
```json
{
  "ok": true,
  "message": "Contact statistics by relationship retrieved successfully",
  "meta": { "total": 3 },
  "result": [
    { "relationship": "mother", "total": 96 },
    { "relationship": "father", "total": 88 },
    { "relationship": "other", "total": 4 }
  ]
}
```

### By student (person)
- **GET** `/contacts/statistics/by-student`
- `result`: `[{ person_id, full_name, total }]` ordered by `total` descending,
  then name.

**Example request**
```http
GET /contacts/statistics/by-student
```

**Example response**
```json
{
  "ok": true,
  "message": "Contact statistics by student retrieved successfully",
  "meta": { "total": 2 },
  "result": [
    { "person_id": 100, "full_name": "Ali Valiyev", "total": 3 },
    { "person_id": 101, "full_name": "Laylo Karimova", "total": 2 }
  ]
}
```

### Get one contact
- **GET** `/contacts/:id`
- `404` if not found (or out of the teacher's scope).

**Example request**
```http
GET /contacts/7
```

**Example response**
```json
{
  "ok": true,
  "message": "Contact retrieved successfully",
  "result": {
    "id": 7,
    "person_id": 100,
    "full_name": "Mubina Xasanova",
    "relationship": "mother",
    "phone_number": "+998901112233",
    "created_by": "Nodir Rasulov",
    "created_at": "2026-04-29T09:40:14.482Z",
    "updated_by": "Nodir Rasulov",
    "updated_at": "2026-04-29T09:40:14.482Z"
  }
}
```

### Create contact
- **POST** `/contacts`
- **Body (CreateContactDto):** `person_id` (int, required — `400` if the person
  does not exist), `full_name` (required), `relationship` (enum, required),
  `phone_number` (required).
- If another contact shares the same normalized phone number and has a linked
  `telegram_id`, it is copied onto the new contact.

**Example request**
```json
{
  "person_id": 100,
  "full_name": "Mubina Xasanova",
  "relationship": "mother",
  "phone_number": "+998901112233"
}
```

**Example response**
```json
{
  "ok": true,
  "message": "Contact created successfully",
  "result": {
    "id": 7,
    "person_id": 100,
    "full_name": "Mubina Xasanova",
    "relationship": "mother",
    "phone_number": "+998901112233",
    "created_by": "Nodir Rasulov",
    "created_at": "2026-04-29T09:40:14.482Z",
    "updated_by": "Nodir Rasulov",
    "updated_at": "2026-04-29T09:40:14.482Z"
  }
}
```

### Update contact
- **PATCH** `/contacts/:id`
- **Body (UpdateContactDto):** partial of the create fields. `404` if the
  contact is missing; `400` if the body is empty or a changed `person_id`
  points to a missing person. Teacher scoping applies to both the current and
  any replacement person. The phone→`telegram_id` re-match runs after changes.

**Example request**
```http
PATCH /contacts/7
```
```json
{
  "phone_number": "+998907776655"
}
```

**Example response**
```json
{
  "ok": true,
  "message": "Contact updated successfully",
  "result": {
    "id": 7,
    "person_id": 100,
    "full_name": "Mubina Xasanova",
    "relationship": "mother",
    "phone_number": "+998907776655",
    "created_by": "Nodir Rasulov",
    "created_at": "2026-04-29T09:40:14.482Z",
    "updated_by": "Nodir Rasulov",
    "updated_at": "2026-05-02T10:00:00.000Z"
  }
}
```

### Delete contact
- **DELETE** `/contacts/:id`
- Returns `204 No Content` (empty body); `404` if not found or out of scope.

**Example request**
```http
DELETE /contacts/7
```

## Frontend suggestions
- Create and update one contact row per request.
- Use `phone_number` as the field name in the staff contacts UI and API client.
