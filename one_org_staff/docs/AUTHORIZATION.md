# Authorization

The backend uses **role-based access with a granular, DB-backed permission layer**.

## Roles

There are three roles (`src/roles/roles.enum.ts`):

| Role      | Description                                                        |
| --------- | ----------------------------------------------------------------- |
| `admin`   | Full access. **Wildcard** — bypasses all permission checks.        |
| `cashier` | Finance staff. Granted `payments.*` and `invoices.*` by default.  |
| `teacher` | Teaching staff. Granted `attendance.*`, `contacts.*`, `my_lessons.read` by default. |

> The legacy roles `owner`, `moderator` (and the never-implemented `superadmin`)
> were collapsed into `admin`. A user's `roles` column holds role **names**.

## Permissions

Permissions are fine-grained keys of the form `resource.action`, e.g.
`users.create`, `payments.read`. The standard actions are `read`, `create`,
`update`, `delete` (plus `export` on a few resources). The full catalog is the
single source of truth in [`src/permissions/permissions.catalog.ts`](../src/permissions/permissions.catalog.ts).

Permissions are mapped to roles in the database:

- `permissions` — the catalog (one row per key)
- `roles` — `admin`, `cashier`, `teacher`, plus any custom roles
- `role_permissions` — many-to-many join

A user's effective permissions are the union of the permissions of their roles.

## How enforcement works

- A **global** `PermissionsGuard` (`src/permissions/permissions.guard.ts`) runs on
  every request.
- Routes opt in to a check with the `@RequirePermissions('resource.action')`
  decorator (`src/permissions/require-permissions.decorator.ts`).
- Resolution order in the guard:
  1. No `@RequirePermissions` metadata → **allowed** (open to any authenticated
     user; this is why read/list endpoints without the decorator are public to
     staff).
  2. The user has the `admin` role → **allowed** (wildcard).
  3. Otherwise the user's role-derived permissions must contain **all** required
     keys, else `403 Forbidden`.
- `PermissionsService` caches the role→permission map in memory and exposes
  `reload()`, which is called automatically whenever a role is created/updated/deleted.

Authentication (who the user is) is still handled by `AuthMiddleware`, which
attaches `req.user` (including `roles`). The teacher-only routes additionally use
`TeacherRoleMiddleware`.

## Managing roles & permissions

Admins manage roles through the Roles API (`/roles`, see
[staff/roles.md](staff/roles.md)):

- `GET /roles/permissions` — list the permission catalog
- `GET /roles` — list roles
- `POST /roles` — create a custom role with a set of permission keys
- `PATCH /roles/:id` — update a role's label/permissions
- `DELETE /roles/:id` — delete a custom role (system roles are protected)

Each module doc's **Auth** section lists the permission keys that gate its
endpoints.
