# Users API

**Base path:** `/users`

Manage application users and provide self lookup.

## Auth
- Implicit auth via `AuthService.validate` in create/update/me; no roles on controller except inline admin checks.
- Admin checks are done manually inside create/update.

## Endpoints

### List users
- **GET** `/users`
- **Query (GetUserDto):** optional `fields` (string[]), `q` (search), `filter` object `{ ids, status, roles, permissions, has_group }`, `sort` array `{ field, direction }`.

### Get current user
- **GET** `/users/me`
- **Returns:** `{ ok: true, user }` after token validation.

### Upload users (Excel)
- **POST** `/users/upload`
- **Body:** `multipart/form-data` with `file`.
- **Validations:** file required.

### Create user
- **POST** `/users/create`
- **Body (CreateUserDto):** `username` (required), optional `email`, `phone`, `status` (`active|blocked`), `role`; `password` min 6; `full_name` required.
- **Authorization:** requires requester to have `admin` in `user.roles` (validated in controller).

### Update user
- **PATCH** `/users/update/:id`
- **Body (UpdateUserDto):** partial of create fields plus optional `roles` and `permissions` string arrays.
- **Authorization:** admin-only check as above.

## Usage notes
- All operations rely on `AuthService.validate(req, true)` to pull user and roles from the request.
- Upload/import feeds Excel buffer to service for processing.

## Example request
- **Method:** GET
- **Path:** `/users`
- **Query:** `?q=ali`
- **Request body:**
```json
{}
```

## Example response
```json
{
	"ok": true,
	"users": [
		{ "id": 2, "username": "ali", "full_name": "Ali Vali", "status": "active" }
	]
}
```

## Frontend suggestions
- Hide create/update actions for non-admins.
- Offer role/permission filters in advanced search UI.
