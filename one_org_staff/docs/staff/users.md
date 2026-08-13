# Users API

**Base path:** `/users`

Manage application users (staff accounts), self lookup, user statistics, and
profile pictures.

## Auth
- Guard: `RolesGuard` + permission checks via `@RequirePermissions`.
- Permissions:
  - Read (statistics, get one): `users.read`
  - Export: `users.export`
  - Create: `users.create`
  - Update (incl. picture upload/remove): `users.update`
  - List, `/me`, upload, get picture: authenticated

## Endpoints

| Method | Path | Description | Permission |
| --- | --- | --- | --- |
| GET | `/users` | List users | authenticated |
| GET | `/users/me` | Get current user | authenticated |
| GET | `/users/statistics` | Headline summary counts | `users.read` |
| GET | `/users/statistics/trend` | Counts per created date | `users.read` |
| GET | `/users/statistics/by-status` | Counts grouped by status | `users.read` |
| GET | `/users/statistics/by-role` | Counts grouped by role | `users.read` |
| GET | `/users/export` | Export users to Excel | `users.export` |
| GET | `/users/:id` | Get one user (with permissions) | `users.read` |
| POST | `/users/upload` | Bulk import from Excel | authenticated |
| POST | `/users/create` | Create a user | `users.create` |
| PATCH | `/users/update/:id` | Update a user | `users.update` |
| GET | `/users/:id/picture` | Get a user's picture URL | authenticated |
| POST | `/users/:id/picture` | Upload/replace a user's picture | `users.update` |
| DELETE | `/users/:id/picture` | Remove a user's picture | `users.update` |

### List users
- **GET** `/users`
- Returns all users ordered by `created_at` descending; `password` is stripped.

**Example request**
```http
GET /users
```

**Example response**
```json
{
  "ok": true,
  "meta": { "total": 1 },
  "users": [
    {
      "id": 2,
      "username": "ali",
      "full_name": "Ali Vali",
      "picture_url": null,
      "phone_number": "+998901112233",
      "email": "ali@example.com",
      "telegram_id": null,
      "status": "active",
      "roles": ["teacher"],
      "created_at": "2025-08-01T09:00:00.000Z",
      "updated_at": "2025-08-01T09:00:00.000Z"
    }
  ]
}
```

### Get current user
- **GET** `/users/me`
- Validates the token and returns the authenticated user.

**Example request**
```http
GET /users/me
```

**Example response**
```json
{
  "ok": true,
  "user": {
    "id": 2,
    "username": "ali",
    "full_name": "Ali Vali",
    "status": "active",
    "roles": ["teacher"]
  }
}
```

## Statistics

All `/users/statistics*` endpoints share the same optional filters
(`GetUserStatisticsDto`): `status`, `role`, `has_group` (boolean — whether the
user teaches a group), `date`, `start_date` / `end_date` (applied to
`created_at`, date-only). Every response echoes the applied filters under
`meta` (unused ones as `null`); grouped endpoints add `meta.total` = number of
buckets. `meta` examples below are abbreviated.

### Summary
- **GET** `/users/statistics`

**Example request**
```http
GET /users/statistics?status=active
```

**Example response**
```json
{
  "ok": true,
  "message": "User statistics retrieved successfully",
  "meta": {
    "status": "active", "role": null, "has_group": null,
    "date": null, "start_date": null, "end_date": null
  },
  "result": {
    "total": 24,
    "active": 24,
    "inactive": 0,
    "with_email": 20,
    "with_telegram": 12,
    "with_group": 16,
    "without_group": 8
  }
}
```

### Trend
- **GET** `/users/statistics/trend`
- `result`: `[{ date, total }]` per `created_at` date, ascending.

**Example request**
```http
GET /users/statistics/trend?start_date=2025-08-01&end_date=2025-08-31
```

**Example response**
```json
{
  "ok": true,
  "message": "User trend retrieved successfully",
  "meta": { "start_date": "2025-08-01", "end_date": "2025-08-31", "total": 2 },
  "result": [
    { "date": "2025-08-01", "total": 20 },
    { "date": "2025-08-15", "total": 4 }
  ]
}
```

### By status
- **GET** `/users/statistics/by-status`
- `result`: `[{ status, total }]` ordered by `total` descending.

**Example request**
```http
GET /users/statistics/by-status
```

**Example response**
```json
{
  "ok": true,
  "message": "User statistics by status retrieved successfully",
  "meta": { "total": 2 },
  "result": [
    { "status": "active", "total": 22 },
    { "status": "blocked", "total": 2 }
  ]
}
```

### By role
- **GET** `/users/statistics/by-role`
- Roles is an array column; each user counts once per role. `result`:
  `[{ role, total }]` ordered by `total` descending.

**Example request**
```http
GET /users/statistics/by-role?status=active
```

**Example response**
```json
{
  "ok": true,
  "message": "User statistics by role retrieved successfully",
  "meta": { "status": "active", "total": 3 },
  "result": [
    { "role": "teacher", "total": 16 },
    { "role": "cashier", "total": 4 },
    { "role": "admin", "total": 2 }
  ]
}
```

### Export users
- **GET** `/users/export`
- Streams an `.xlsx` file (`users.xlsx`) of all users, ordered by `created_at`
  descending, with columns: `ID`, `Username`, `Full Name`, `Phone Number`,
  `Email`, `Telegram ID`, `Status`, `Roles`, `Created At`, `Updated At`.
- **`password` is never included.**

### Get one
- **GET** `/users/:id`
- Returns the user with the effective `permissions` resolved from their roles.
  `400` if not found.

**Example request**
```http
GET /users/2
```

**Example response**
```json
{
  "ok": true,
  "user": {
    "id": 2,
    "username": "ali",
    "full_name": "Ali Vali",
    "status": "active",
    "roles": ["teacher"],
    "permissions": ["my_lessons.read", "points.create", "points.read"]
  }
}
```

### Upload users (Excel)
- **POST** `/users/upload`
- **Body:** `multipart/form-data` with `file` (Excel workbook). `400` if the
  file is missing or contains no valid rows.
- Rows with an `id` update the existing user; others insert.

**Example request**
```http
POST /users/upload
Content-Type: multipart/form-data; boundary=----X

------X
Content-Disposition: form-data; name="file"; filename="users.xlsx"
Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet

<binary>
------X--
```

**Example response**
```json
{
  "ok": true,
  "inserted": 8,
  "updated": 2
}
```

### Create user
- **POST** `/users/create`
- **Body (CreateUserDto):** `username` (required, unique — `400` on duplicate),
  `password` (min 6 chars), `full_name` (required), optional `email`, `phone`.

**Example request**
```json
{
  "username": "gulnora",
  "password": "s3cret-pass",
  "full_name": "Gulnora Tosheva",
  "email": "gulnora@example.com"
}
```

**Example response**
```json
{
  "ok": true,
  "user": {
    "id": 25,
    "username": "gulnora",
    "full_name": "Gulnora Tosheva",
    "email": "gulnora@example.com",
    "status": "active",
    "roles": ["teacher"],
    "created_at": "2026-07-01T09:00:00.000Z"
  }
}
```

### Update user
- **PATCH** `/users/update/:id`
- **Body (UpdateUserDto, all optional):** `username` (unique), `email`,
  `password` (min 6), `full_name`, `phone`, `status` (`active|blocked`),
  `roles` (string[]).
- `400` if the user is missing or the new username is taken.

**Example request**
```http
PATCH /users/update/25
```
```json
{
  "roles": ["teacher", "cashier"],
  "status": "active"
}
```

**Example response**
```json
{
  "ok": true,
  "user": {
    "id": 25,
    "username": "gulnora",
    "full_name": "Gulnora Tosheva",
    "status": "active",
    "roles": ["teacher", "cashier"]
  }
}
```

### Profile picture

#### Get picture
- **GET** `/users/:id/picture` → `{ ok, picture_url }`.

**Example request**
```http
GET /users/25/picture
```

**Example response**
```json
{
  "ok": true,
  "picture_url": "https://cdn.example.com/users/25/9f86d081884c7d65.jpg"
}
```

#### Upload/replace picture
- **POST** `/users/:id/picture` → `multipart/form-data` with an image `file`;
  uploads to R2 and best-effort deletes the previous object. `400` if missing.

**Example response**
```json
{
  "ok": true,
  "picture_url": "https://cdn.example.com/users/25/9f86d081884c7d65.jpg"
}
```

#### Remove picture
- **DELETE** `/users/:id/picture` → clears the stored URL.

**Example response**
```json
{
  "ok": true,
  "picture_url": null
}
```

## Usage notes
- Passwords are hashed (SHA-256) server-side; responses never include them.
- `GET /users/:id` is the only read that resolves effective `permissions`.

## Frontend suggestions
- Hide create/update actions from users lacking `users.create` / `users.update`.
- Drive a role/status filter UI from the statistics endpoints.
