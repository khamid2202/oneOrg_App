# Invoice Templates API

**Base path:** `/invoice-templates`

Manage invoice templates (formerly *billings*) — the billable line items
(code, category, amount) that invoice generation multiplies across student
enrollments.

## Auth
- Guard: `RolesGuard` + permission checks via `@RequirePermissions`.
- Permissions:
  - Update: `invoice_templates.update`
  - Delete: `invoice_templates.delete`
  - List / get one / create: authenticated

## Endpoints

| Method | Path | Description | Permission |
| --- | --- | --- | --- |
| GET | `/invoice-templates` (or `/invoice-templates/all`) | List templates (filtered) | authenticated |
| GET | `/invoice-templates/:id` | Get one template | authenticated |
| POST | `/invoice-templates` | Create a template | authenticated |
| PATCH | `/invoice-templates/:id` | Update a template | `invoice_templates.update` |
| DELETE | `/invoice-templates/:id` | Delete a template | `invoice_templates.delete` |

### List invoice templates
- **GET** `/invoice-templates` (alias **GET** `/invoice-templates/all`)
- **Query (GetInvoiceTemplateDto), all optional:** `ids` (int[] as JSON, max
  100), `codes` (string[] as JSON), `categories` (string[] as JSON, 1-50 chars
  each), `is_active` (boolean).
- Results are cached in Redis (7-day TTL, keyed per query); mutations invalidate
  the cache.

**Example request**
```http
GET /invoice-templates?categories=["tuition_fee"]&is_active=true
```

**Example response**
```json
{
  "ok": true,
  "message": "Invoice templates retrieved successfully",
  "meta": {
    "total": 1,
    "query": { "categories": ["tuition_fee"], "is_active": true }
  },
  "invoiceTemplates": [
    {
      "id": 3,
      "code": "TUITION_10A",
      "amount": 120,
      "description": "Grade 10A monthly tuition",
      "is_active": true,
      "category": "tuition_fee"
    }
  ]
}
```

### Get one
- **GET** `/invoice-templates/:id`
- `400` if not found.

**Example request**
```http
GET /invoice-templates/3
```

**Example response**
```json
{
  "ok": true,
  "message": "Invoice template retrieved successfully",
  "invoiceTemplate": {
    "id": 3,
    "code": "TUITION_10A",
    "amount": 120,
    "description": "Grade 10A monthly tuition",
    "is_active": true,
    "category": "tuition_fee"
  }
}
```

### Create
- **POST** `/invoice-templates`
- **Body (CreateInvoiceTemplateDto):** `code` (1-20 chars, unique — `409` on
  duplicate), `description` (1-300 chars), `amount` (int 0-1,000,000),
  `is_active` (bool), `category` (1-50 chars).

**Example request**
```json
{
  "code": "DORM_2025",
  "description": "Monthly dormitory fee",
  "amount": 80,
  "is_active": true,
  "category": "dormitory_fee"
}
```

**Example response**
```json
{
  "ok": true,
  "message": "Invoice template created successfully",
  "invoiceTemplate": {
    "id": 7,
    "code": "DORM_2025",
    "amount": 80,
    "description": "Monthly dormitory fee",
    "is_active": true,
    "category": "dormitory_fee"
  }
}
```

### Update
- **PATCH** `/invoice-templates/:id`
- **Body (UpdateInvoiceTemplateDto):** partial of the create fields. Changing
  `code` re-checks uniqueness (`400` on duplicate); `400` if the template does
  not exist.

**Example request**
```http
PATCH /invoice-templates/7
```
```json
{
  "amount": 90
}
```

**Example response**
```json
{
  "ok": true,
  "message": "Invoice template updated successfully",
  "invoiceTemplate": {
    "id": 7,
    "code": "DORM_2025",
    "amount": 90,
    "description": "Monthly dormitory fee",
    "is_active": true,
    "category": "dormitory_fee"
  }
}
```

### Delete
- **DELETE** `/invoice-templates/:id`
- Returns `204 No Content` (empty body). `400` if the template does not exist
  **or is still referenced by a student enrollment's `invoice_template_ids`**.

**Example request**
```http
DELETE /invoice-templates/7
```

## Usage notes
- Templates are referenced by `invoice_template_ids` arrays on groups and
  student enrollments; invoice generation bills each enrollment × template.
- Prefer deactivating (`is_active: false`) over deleting once a template has
  been billed.

## Frontend suggestions
- Provide filter chips for `category` and `is_active`.
- Validate `amount` client-side to avoid 400s.
