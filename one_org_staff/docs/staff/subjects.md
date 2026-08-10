# Subjects API

**Base path:** `/subjects`

Manage academic subjects with optional Excel import.

## Auth
- Guard: `RolesGuard`
- Roles: `owner`, `admin`, `moderator` for create/update/delete/upload; read is guarded.

## Endpoints

### List subjects
- **GET** `/subjects` (alias: `/subjects/all`)

### Get one
- **GET** `/subjects/:id`

### Upload subjects (Excel)
- **POST** `/subjects/upload`
- **Body:** `multipart/form-data` with `file` (Excel buffer).

### Create subject
- **POST** `/subjects`
- **Body (CreateSubjectDto):** `name` (string), optional `description`.

### Update subject
- **PATCH** `/subjects/:id`
- **Body:** partial of create fields.

### Delete subject
- **DELETE** `/subjects/:id`

## Usage notes
- Upload validates presence of `file`; imports run under user context for audit.
- Responses may be cached via Redis in the service layer.

## Example request
- **Method:** POST
- **Path:** `/subjects`
- **Request body:**
```json
{
	"name": "Mathematics",
	"description": "Algebra and geometry"
}
```

## Example response
```json
{
	"id": 44,
	"name": "Mathematics",
	"description": "Algebra and geometry"
}
```

## Frontend suggestions
- Debounce subject search inputs when listing.
- Show upload progress for bulk imports.
