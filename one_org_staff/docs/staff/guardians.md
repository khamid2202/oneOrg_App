# Guardians API

**Base path:** `/guardians`

Manage guardian records for persons (students). Guardians are keyed by
`person_id`; multiple rows can exist per person.

## Auth
- Guard: `RolesGuard` + permission checks via `@RequirePermissions`.
- Permissions: `guardians.read`, `guardians.create`, `guardians.update`,
  `guardians.delete` per endpoint.
- **Teacher scoping:** users without elevated access only see/manage guardians of
  persons currently enrolled in a group they teach (`groups.teacher_id`).

## Data model
- `person_id` (int, required) — the person the guardian belongs to
- `full_name` (string, required, max 255, trimmed)
- `relation` (string, required, max 255, trimmed — e.g. "father", "mother",
  "uncle")
- `phone` (string, required, max 255, trimmed)
- `work_address` (string, nullable, max 255, trimmed)
- `position` (string, nullable, max 255, trimmed — e.g. job title)

## Endpoints

| Method | Path | Description | Permission |
| --- | --- | --- | --- |
| GET | `/guardians` | List guardians (filtered) | `guardians.read` |
| GET | `/guardians/:id` | Get one guardian | `guardians.read` |
| POST | `/guardians` | Create a guardian | `guardians.create` |
| PATCH | `/guardians/:id` | Update a guardian | `guardians.update` |
| DELETE | `/guardians/:id` | Delete a guardian | `guardians.delete` |

### List guardians
- **GET** `/guardians`
- **Query (GetGuardianDto), all optional:** `id`, `person_id`, `created_by`,
  `updated_by` (ints).
- Sorted by `created_at DESC`, then `id DESC`; `created_by` / `updated_by` are
  resolved to user full names.

**Example request**
```http
GET /guardians?person_id=100
```

**Example response**
```json
{
  "ok": true,
  "message": "Guardians retrieved successfully",
  "meta": { "total": 2, "query": { "person_id": 100 } },
  "result": [
    {
      "id": 3,
      "person_id": 100,
      "full_name": "Valijon Valiyev",
      "relation": "father",
      "phone": "+998901112233",
      "work_address": "Tashkent, Chilanzar 5",
      "position": "Engineer",
      "created_by": "Nodir Rasulov",
      "created_at": "2026-07-31T09:00:00.000Z",
      "updated_by": null,
      "updated_at": null
    },
    {
      "id": 2,
      "person_id": 100,
      "full_name": "Mubina Xasanova",
      "relation": "mother",
      "phone": "+998907776655",
      "work_address": null,
      "position": null,
      "created_by": "Nodir Rasulov",
      "created_at": "2026-07-30T14:00:00.000Z",
      "updated_by": null,
      "updated_at": null
    }
  ]
}
```

### Get one guardian
- **GET** `/guardians/:id`
- `404` if not found (or out of the teacher's scope).

**Example request**
```http
GET /guardians/3
```

**Example response**
```json
{
  "ok": true,
  "message": "Guardian retrieved successfully",
  "result": {
    "id": 3,
    "person_id": 100,
    "full_name": "Valijon Valiyev",
    "relation": "father",
    "phone": "+998901112233",
    "work_address": "Tashkent, Chilanzar 5",
    "position": "Engineer",
    "created_by": "Nodir Rasulov",
    "created_at": "2026-07-31T09:00:00.000Z",
    "updated_by": null,
    "updated_at": null
  }
}
```

### Create guardian
- **POST** `/guardians`
- **Body (CreateGuardianDto):** `person_id` (int, required — `400` if the person
  does not exist), `full_name` (required), `relation` (required), `phone`
  (required), `work_address` (optional), `position` (optional).

**Example request**
```json
{
  "person_id": 100,
  "full_name": "Valijon Valiyev",
  "relation": "father",
  "phone": "+998901112233",
  "work_address": "Tashkent, Chilanzar 5",
  "position": "Engineer"
}
```

**Example response**
```json
{
  "ok": true,
  "message": "Guardian created successfully",
  "result": {
    "id": 3,
    "person_id": 100,
    "full_name": "Valijon Valiyev",
    "relation": "father",
    "phone": "+998901112233",
    "work_address": "Tashkent, Chilanzar 5",
    "position": "Engineer",
    "created_by": "Nodir Rasulov",
    "created_at": "2026-07-31T09:00:00.000Z",
    "updated_by": "Nodir Rasulov",
    "updated_at": "2026-07-31T09:00:00.000Z"
  }
}
```

### Update guardian
- **PATCH** `/guardians/:id`
- **Body (UpdateGuardianDto):** partial of the create fields. `404` if the
  guardian is missing; `400` if the body is empty or a changed `person_id`
  points to a missing person. Teacher scoping applies to both the current and
  any replacement person.

**Example request**
```http
PATCH /guardians/3
```
```json
{
  "phone": "+998909998877",
  "position": "Senior Engineer"
}
```

**Example response**
```json
{
  "ok": true,
  "message": "Guardian updated successfully",
  "result": {
    "id": 3,
    "person_id": 100,
    "full_name": "Valijon Valiyev",
    "relation": "father",
    "phone": "+998909998877",
    "work_address": "Tashkent, Chilanzar 5",
    "position": "Senior Engineer",
    "created_by": "Nodir Rasulov",
    "created_at": "2026-07-31T09:00:00.000Z",
    "updated_by": "Nodir Rasulov",
    "updated_at": "2026-07-31T10:00:00.000Z"
  }
}
```

### Delete guardian
- **DELETE** `/guardians/:id`
- Returns `204 No Content` (empty body); `404` if not found or out of scope.

**Example request**
```http
DELETE /guardians/3
```

## Student include

Guardians can also be loaded as a nested relation on student read endpoints by
passing `include=guardians` (see [Students API](students.md#relations-attached-to-read-responses)):

```http
GET /students?person_id=100&include=guardians
GET /students/12?include=guardians
```

## Error responses
| Status | Condition |
| --- | --- |
| `400 Bad Request` | Person not found; empty update body |
| `403 Forbidden` | Teacher does not control the student; missing permission |
| `404 Not Found` | Guardian not found |

## Frontend suggestions
- Create and update one guardian row per request.
- Use `person_id` to display guardians on a student detail page.
- Use `include=guardians` on student list/detail endpoints to embed guardian data
  without a separate request.
