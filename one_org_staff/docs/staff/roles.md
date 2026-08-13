# Roles & Permissions API

**Base path:** `/roles`

Manage roles and their granular permissions. See [Authorization](../AUTHORIZATION.md)
for the overall model.

## Auth
- Guard: `PermissionsGuard` (global).
- Requires the matching `roles.read` / `roles.create` / `roles.update` / `roles.delete` permission.
- The `admin` role is a wildcard and holds every permission.

## Response shape
- List/detail endpoints return the role object(s) with their `permissions`.
- A `Role` is `{ id, name, label, is_system, permissions: Permission[], created_at, updated_at }`.
- A `Permission` is `{ id, key, resource, action, description }`.

## Endpoints

### List the permission catalog
- **GET** `/roles/permissions`
- **Permission:** `roles.read`
- **Returns:** the full permission catalog (`{ key, resource, action }[]`) defined in `src/permissions/permissions.catalog.ts`.

**Example request**
```http
GET /roles/permissions
```

**Example response**
```json
[
  { "key": "invoices.read", "resource": "invoices", "action": "read" },
  { "key": "invoices.create", "resource": "invoices", "action": "create" },
  { "key": "payments.read", "resource": "payments", "action": "read" }
]
```

### List roles
- **GET** `/roles`
- **Permission:** `roles.read`
- **Returns:** all roles (ordered by `name`) with their permissions.

**Example request**
```http
GET /roles
```

**Example response**
```json
[
  {
    "id": 1,
    "name": "admin",
    "label": "Administrator",
    "is_system": true,
    "permissions": [],
    "created_at": "2025-01-01T00:00:00.000Z",
    "updated_at": "2025-01-01T00:00:00.000Z"
  },
  {
    "id": 7,
    "name": "finance_viewer",
    "label": "Finance Viewer",
    "is_system": false,
    "permissions": [
      { "id": 12, "key": "invoices.read", "resource": "invoices", "action": "read", "description": null }
    ],
    "created_at": "2026-07-01T10:00:00.000Z",
    "updated_at": "2026-07-01T10:00:00.000Z"
  }
]
```

### Get a role
- **GET** `/roles/:id`
- **Permission:** `roles.read`

**Example request**
```http
GET /roles/7
```

**Example response**
```json
{
  "id": 7,
  "name": "finance_viewer",
  "label": "Finance Viewer",
  "is_system": false,
  "permissions": [
    { "id": 12, "key": "invoices.read", "resource": "invoices", "action": "read", "description": null },
    { "id": 18, "key": "payments.read", "resource": "payments", "action": "read", "description": null }
  ],
  "created_at": "2026-07-01T10:00:00.000Z",
  "updated_at": "2026-07-01T10:00:00.000Z"
}
```

### Create a role
- **POST** `/roles`
- **Permission:** `roles.create`
- **Body (CreateRoleDto):**
  - `name` (string, required, lowercase letters/numbers/underscores, unique)
  - `label` (string, optional)
  - `permissionKeys` (string[], optional) — must be valid catalog keys
- **Behavior:** rejects duplicate names and unknown permission keys; reloads the permission cache.

**Example request**
```json
{
  "name": "finance_viewer",
  "label": "Finance Viewer",
  "permissionKeys": ["invoices.read", "payments.read"]
}
```

**Example response** (the created `Role` object)
```json
{
  "id": 7,
  "name": "finance_viewer",
  "label": "Finance Viewer",
  "is_system": false,
  "permissions": [
    { "id": 12, "key": "invoices.read", "resource": "invoices", "action": "read", "description": null },
    { "id": 18, "key": "payments.read", "resource": "payments", "action": "read", "description": null }
  ],
  "created_at": "2026-07-01T10:00:00.000Z",
  "updated_at": "2026-07-01T10:00:00.000Z"
}
```

### Update a role
- **PATCH** `/roles/:id`
- **Permission:** `roles.update`
- **Body (UpdateRoleDto):**
  - `label` (string, optional)
  - `permissionKeys` (string[], optional) — replaces the role's permissions
- **Behavior:** validates keys; reloads the permission cache.

**Example request**
```http
PATCH /roles/7
```
```json
{
  "permissionKeys": ["invoices.read"]
}
```

**Example response** (the updated `Role` object)
```json
{
  "id": 7,
  "name": "finance_viewer",
  "label": "Finance Viewer",
  "is_system": false,
  "permissions": [
    { "id": 12, "key": "invoices.read", "resource": "invoices", "action": "read", "description": null }
  ],
  "created_at": "2026-07-01T10:00:00.000Z",
  "updated_at": "2026-07-02T08:00:00.000Z"
}
```

### Delete a role
- **DELETE** `/roles/:id`
- **Permission:** `roles.delete`
- **Behavior:** system roles (`admin`, `cashier`, `teacher`) cannot be deleted; reloads the permission cache.

**Example request**
```http
DELETE /roles/7
```

**Example response**
```json
{ "ok": true }
```

## Notes for the frontend
- Build a role editor from `GET /roles/permissions` (group by `resource`) and toggle keys per role.
- The `admin` role is a wildcard; granting it any subset of permissions is moot — it always has full access.
