# Groups API

**Base path:** `/groups`

Manage class groups per academic year.

## Auth
- Guard: `RolesGuard`
- Roles:
  - Upload: `owner`
  - Read: authenticated

## Endpoints

### List groups
- **GET** `/groups`
- **Query (GetGroupDto):** optional `id`; `academic_year_id`; arrays `grades` (1-12), `classes` (strings), `teacher_ids` (ints), `class_pairs` (strings), `class_pairs` (strings). Uses array coercion via `ToArray`.

### Get one
- **GET** `/groups/:id`

### Upload groups (Excel)
- **POST** `/groups/upload`
- **Body:** `multipart/form-data` with `file` (Excel buffer).
- **Roles:** `owner`.

## Usage notes
- Upload performs bulk import; backend rejects missing file.

## Example request
- **Method:** GET
- **Path:** `/groups`
- **Query:** `?academic_year_id=1&grades=10&classes=A`
- **Request body:**
```json
{}
```

## Example response
```json
{
  "ok": true,
  "groups": [
    {
      "id": 12,
      "grade": 10,
      "class": "A",
      "academic_year_id": 1,
      "billings": [
        {
          "id": 3,
          "code": "TUITION_10A",
          "amount": "120.00",
          "category": "tuition_fee",
          "description": "Grade 10A monthly tuition",
          "is_active": true
        }
      ]
    }
  ]
}
```

## Frontend suggestions
- Normalize `class_pairs` inputs as `GRADE-CLASS` strings.
- For uploads, show progress and parse errors from backend.
