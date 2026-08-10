# Contacts API

**Base path:** `/contacts`

Manage student emergency and family contact documents for authenticated staff users.

## Auth
- Guard: `RolesGuard`
- Allowed roles: `teacher`
- Teachers can only access contacts for students who currently belong to a group they own (`groups.teacher_id`).

## Data model
- Each row in `contacts` stores a single contact for a student.
- Multiple rows can exist for the same `student_id`.
- Each contact row supports:
  - `full_name` (string, required, max 50)
  - `relationship` (`self` | `father` | `mother` | `brother` | `sister` | `grandfather` | `grandmother` | `uncle` | `aunt` | `cousin` | `other`)
  - `phone_number` (string, required, max 16)
  - `telegram_id` (`bigint`, nullable; handled as a string in API code for int64 safety)

## Endpoints

### Create contacts
- **POST** `/contacts`
- **Body (CreateContactDto):**
  - `student_id` (int, required)
  - `full_name` (string, required)
  - `relationship` (enum, required)
  - `phone_number` (string, required)
- **Behavior:**
  - validates student existence
  - for `teacher`, validates that the target student currently belongs to a group owned by the authenticated teacher
  - creates one contact row per request
  - trims `full_name` and `phone_number`
  - if another contact already has the same phone number and a linked `telegram_id`, copies that `telegram_id` onto the new contact
  - stores audit fields from authenticated user (`created_by`, `updated_by`)

### List contacts
- **GET** `/contacts`
- **Query (GetContactDto):**
  - `id` (int, optional)
  - `student_id` (int, optional)
  - `created_by` (int, optional)
  - `updated_by` (int, optional)
- **Response notes:**
  - for `teacher`, only returns contacts for students in the teacher's current groups
  - sorted by `created_at DESC`, then `id DESC`
  - each document includes `created_by_name` and `updated_by_name`
  - returns `meta.total` and `result` list

### Get one contact document
- **GET** `/contacts/:id`
- **Behavior:** returns one contact document by `id`; teachers can only access contacts for students in their current groups.

### Update contacts
- **PATCH** `/contacts/:id`
- **Body (UpdateContactDto):** partial of create fields.
- **Behavior:**
  - validates target document exists
  - for `teacher`, validates access to the contact's current student and to any replacement `student_id`
  - validates student existence if `student_id` changes
  - updates the contact row fields provided in the request
  - rechecks the effective `phone_number` and copies a matching contact's `telegram_id` when one already exists
  - updates audit fields (`updated_by`, `updated_at`)

### Delete contacts
- **DELETE** `/contacts/:id`
- **Behavior:** deletes by `id` (returns `204`, throws if not found); teachers can only delete contacts for students in their current groups.

## Example request
- **Method:** POST
- **Path:** `/contacts`
- **Request body:**
```json
{
  "student_id": 25,
  "full_name": "Mubina Xasanova",
  "relationship": "mother",
  "phone_number": "+998901112233"
}
```

## Example response
```json
{
  "ok": true,
  "message": "Contact created successfully",
  "result": {
    "id": 1,
    "student_id": 25,
    "full_name": "Mubina Xasanova",
    "relationship": "mother",
    "phone_number": "+998901112233",
    "created_by": 9,
    "created_by_name": "Nodir Rasulov",
    "created_at": "2026-04-29T09:40:14.482Z",
    "updated_by": 9,
    "updated_by_name": "Nodir Rasulov",
    "updated_at": "2026-04-29T09:40:14.482Z"
  }
}
```

## Frontend payload shape
- Create and update one contact row per request.
- Use `phone_number` as the field name in the staff contacts UI and API client.
- Example create payload:
```json
{
  "student_id": 25,
  "full_name": "Mubina Xasanova",
  "relationship": "mother",
  "phone_number": "+998901112233"
}
```