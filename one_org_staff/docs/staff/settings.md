# Settings API

**Base path:** `/settings`

Settings endpoints for authenticated users.

## Auth
- Protected by `AuthMiddleware` (token required).
- User identity is taken from request context via `@UserId()`.

## Endpoints

### Update password
- **PATCH** `/settings/password`
- **Body (UpdatePasswordDto):**
  - `current_password` (string, required)
  - `new_password` (string, required, min length: 6)
- **Validation/behavior:**
  - Rejects when `new_password` is the same as `current_password`.
  - Rejects when `current_password` does not match existing password.
  - Password is hashed (`sha256`) before saving.

## Example request
- **Method:** PATCH
- **Path:** `/settings/password`
- **Request body:**
```json
{
  "current_password": "old-secret",
  "new_password": "new-secret-123"
}
```

## Example response
```json
{
  "ok": true,
  "message": "Password updated successfully"
}
```

## Common error examples
```json
{
  "statusCode": 400,
  "message": "Current password is incorrect",
  "error": "Bad Request"
}
```

```json
{
  "statusCode": 400,
  "message": "New password must be different from current password",
  "error": "Bad Request"
}
```

## Frontend suggestions
- Use a dedicated form with three fields: current password, new password, confirm new password (client-side confirmation).
- Show success toast and force re-login only if your product policy requires token/session rotation.
