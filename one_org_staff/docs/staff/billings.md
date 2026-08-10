# Billings API

**Base path:** `/billings`

Manage billing codes/categories used for invoices.

## Auth
- Guard: `RolesGuard`
- Roles:
  - Create: any authenticated
  - Update/Delete: `owner`, `admin`, `moderator`

## Endpoints

### List billings
- **GET** `/billings` (alias: `/billings/all`)
- **Query (GetBillingDto):** optional `ids` (int[] up to 100), `codes` (string[]), `categories` (string[], 1-50 chars), `is_active` (boolean).

### Get one
- **GET** `/billings/:id`

### Create
- **POST** `/billings`
- **Body (CreateBillingDto):** `code` (1-20 chars), `description` (1-300), `amount` (0-1,000,000 int), `is_active` (bool), `category` (1-50 chars).

### Update
- **PATCH** `/billings/:id`
- **Body (UpdateBillingDto):** partial of create fields.
- **Roles:** `owner`, `admin`, `moderator`.

### Delete
- **DELETE** `/billings/:id`
- **Roles:** `owner`, `admin`, `moderator`.

## Usage notes
- Cached responses; updates clear cache.
- Codes/categories enable downstream invoice matching.

## Example request
- **Method:** GET
- **Path:** `/billings`
- **Query:** `?categories=tuition&is_active=true`
- **Request body:**
```json
{}
```

## Example response
```json
{
  "ok": true,
  "meta": { "total": 1 },
  "billings": [
    {
      "id": 12,
      "code": "TUI-2025",
      "description": "Tuition",
      "amount": 500,
      "is_active": true,
      "category": "tuition"
    }
  ]
}
```

## Frontend suggestions
- Provide filter chips for `category` and `is_active`.
- Validate `amount` client-side to avoid 400s.
