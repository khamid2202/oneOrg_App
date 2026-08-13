# Invoices API

**Base path:** `/invoices`

Manage student invoices within an academic year. Invoices are keyed per student
enrollment × invoice template × period (`academic_year_id` + `year` + `month`).

## Auth
- Guard: `RolesGuard` + permission checks via `@RequirePermissions`.
- Permissions: `invoices.create`, `invoices.read`, `invoices.update`,
  `invoices.delete` per endpoint.

## Endpoints

| Method | Path | Description | Permission |
| --- | --- | --- | --- |
| POST | `/invoices` | Generate invoices for a period | `invoices.create` |
| GET | `/invoices` (or `/invoices/all`) | List invoices (filtered) | `invoices.read` |
| GET | `/invoices/statistics` | Aggregate totals | `invoices.read` |
| GET | `/invoices/statistics/by-status` | Totals grouped by status | `invoices.read` |
| GET | `/invoices/statistics/trend` | Totals grouped by year/month | `invoices.read` |
| GET | `/invoices/statistics/by-academic-year` | Totals grouped by academic year | `invoices.read` |
| GET | `/invoices/:academic_year_id` | List invoices for one academic year | `invoices.read` |
| PATCH | `/invoices/:id` | Update one invoice | `invoices.update` |
| PATCH | `/invoices` | Update many invoices (by filters) | `invoices.update` |
| DELETE | `/invoices/:id` | Delete one invoice | `invoices.delete` |
| DELETE | `/invoices` | Delete many invoices (by filters) | `invoices.delete` |

## Filters (`InvoiceFilterDto`)

Shared by the list, statistics, bulk-update and bulk-delete endpoints. All fields
are optional arrays (max 200 items each unless noted). In query strings each
array is passed as a JSON string, e.g. `?months=[10]&statuses=["Not Paid"]`:

- `ids` (int[])
- `student_ids` (int[]) — student enrollment ids
- `group_ids` (int[])
- `grades` (int[], 1-20)
- `academic_year_ids` (int[])
- `years` (int[], 2000-2100)
- `months` (int[], 1-12)
- `invoice_template_ids` (int[])
- `statuses` (string[], max 100, `Not Paid|Partially Paid|Paid|Refunded|Voucher`)

`group_ids` and `grades` resolve through the student's group.

### List invoices (filtered)
- **GET** `/invoices` (alias **GET** `/invoices/all`)
- **Query:** any of the shared filter fields above.
- Returns `{ ok, message, meta: { total, query }, invoices }`. Each invoice
  includes `created_by` / `updated_by` resolved to the user's full name.

**Example request**
```http
GET /invoices?academic_year_ids=[3]&months=[10]&statuses=["Paid"]
```

**Example response**
```json
{
  "ok": true,
  "message": "Invoices retrieved successfully",
  "meta": {
    "total": 1,
    "query": { "academic_year_ids": [3], "months": [10], "statuses": ["Paid"] }
  },
  "invoices": [
    {
      "id": 88,
      "student_id": 12,
      "academic_year_id": 3,
      "year": 2025,
      "month": 10,
      "invoice_template_id": 3,
      "subtotal_required_amount": 120,
      "discount_percent": 0,
      "total_required_amount": 120,
      "total_paid_amount": 120,
      "status": "Paid",
      "created_by": "Kamola Karimova",
      "created_at": "2025-10-01T09:00:00.000Z",
      "updated_by": null,
      "updated_at": "2025-10-01T09:00:00.000Z"
    }
  ]
}
```

### Invoice statistics (summary)
- **GET** `/invoices/statistics`
- **Query:** shared filters.
- Returns `{ ok, message, meta: { query }, result }` where `result` is
  `{ total, subtotal_required, total_required, total_paid, outstanding }`
  (`outstanding = total_required - total_paid`).

**Example request**
```http
GET /invoices/statistics?academic_year_ids=[3]&months=[10]
```

**Example response**
```json
{
  "ok": true,
  "message": "Invoice statistics retrieved successfully",
  "meta": { "query": { "academic_year_ids": [3], "months": [10] } },
  "result": {
    "total": 128,
    "subtotal_required": 15360,
    "total_required": 14800,
    "total_paid": 11200,
    "outstanding": 3600
  }
}
```

### Invoice statistics by status
- **GET** `/invoices/statistics/by-status`
- **Query:** shared filters.
- Returns `result[]` grouped by `status`, each row carrying the same amount
  fields as the summary, ordered by count desc.

**Example request**
```http
GET /invoices/statistics/by-status?academic_year_ids=[3]
```

**Example response**
```json
{
  "ok": true,
  "message": "Invoice statistics by status retrieved successfully",
  "meta": { "query": { "academic_year_ids": [3] }, "total": 2 },
  "result": [
    {
      "status": "Paid",
      "total": 96,
      "subtotal_required": 11520,
      "total_required": 11200,
      "total_paid": 11200,
      "outstanding": 0
    },
    {
      "status": "Not Paid",
      "total": 32,
      "subtotal_required": 3840,
      "total_required": 3600,
      "total_paid": 0,
      "outstanding": 3600
    }
  ]
}
```

### Invoice statistics trend
- **GET** `/invoices/statistics/trend`
- **Query:** shared filters.
- Returns `result[]` grouped by `year` + `month` (ascending), each with the
  amount fields.

**Example request**
```http
GET /invoices/statistics/trend?academic_year_ids=[3]
```

**Example response**
```json
{
  "ok": true,
  "message": "Invoice trend retrieved successfully",
  "meta": { "query": { "academic_year_ids": [3] }, "total": 2 },
  "result": [
    {
      "year": 2025,
      "month": 9,
      "total": 128,
      "subtotal_required": 15360,
      "total_required": 14800,
      "total_paid": 14800,
      "outstanding": 0
    },
    {
      "year": 2025,
      "month": 10,
      "total": 128,
      "subtotal_required": 15360,
      "total_required": 14800,
      "total_paid": 11200,
      "outstanding": 3600
    }
  ]
}
```

### Invoice statistics by academic year
- **GET** `/invoices/statistics/by-academic-year`
- **Query:** shared filters.
- Returns `result[]` grouped by `academic_year_id` (ascending), each with the
  amount fields.

**Example request**
```http
GET /invoices/statistics/by-academic-year?statuses=["Not Paid"]
```

**Example response**
```json
{
  "ok": true,
  "message": "Invoice statistics by academic year retrieved successfully",
  "meta": { "query": { "statuses": ["Not Paid"] }, "total": 1 },
  "result": [
    {
      "academic_year_id": 3,
      "total": 32,
      "subtotal_required": 3840,
      "total_required": 3600,
      "total_paid": 0,
      "outstanding": 3600
    }
  ]
}
```

### Create invoice
- **POST** `/invoices`
- **Body (CreateInvoiceDto):**
  - **Target period (required):** `academic_year_id` (1-100), `year` (2000-2100), `month` (1-12).
  - **Scoping filters (optional, inherited from `InvoiceFilterDto`):** `student_ids`, `group_ids`, `grades`, `invoice_template_ids`. When provided, generation is narrowed — only the matching enrollments/groups/grades get invoices, and only the listed invoice templates are billed. Omit them all to generate for every enrollment in the academic year.
  - The remaining `InvoiceFilterDto` fields (`ids`, `academic_year_ids`, `years`, `months`, `statuses`) are accepted but ignored here, since the period is fixed by the required fields above.
- **Behavior:** for each in-scope enrollment × template, creates the invoice for `(year, month)`, applying active discounts (summed per template). If an invoice already exists it is updated when the amounts changed, otherwise skipped. Templates listed on a student but missing from the templates table are skipped. Returns `{ ok, message, created, updated, skipped }`.

**Example request (all enrollments in the year)**
```json
{
  "academic_year_id": 1,
  "year": 2025,
  "month": 10
}
```

**Example request (scoped to grade 10 + specific templates)**
```json
{
  "academic_year_id": 1,
  "year": 2025,
  "month": 10,
  "grades": [10],
  "invoice_template_ids": [3]
}
```

**Example response**
```json
{
  "ok": true,
  "message": "Invoices created",
  "created": 12,
  "updated": 3,
  "skipped": 1
}
```

### Update invoice
- **PATCH** `/invoices/:id`
- **Body (UpdateInvoiceDto, all optional):** `academic_year_id`, `year`, `month`, `invoice_template_id`, `subtotal_required_amount`, `discount_percent` (0-100), `total_required_amount`, `status` (`Not Paid|Partially Paid|Paid|Refunded|Voucher`).
- **Notes:**
  - Changing `academic_year_id` or `invoice_template_id` validates the target exists.
  - Changing any of `academic_year_id` / `year` / `month` / `invoice_template_id` rejects with `400` if it would collide with another invoice for the same student, template and period.
  - When `subtotal_required_amount` or `discount_percent` change and `total_required_amount` is not provided, `total_required_amount` auto-recalculates.

**Example request**
```http
PATCH /invoices/88
```
```json
{
  "discount_percent": 25
}
```

**Example response** (`total_required_amount` recalculated from the new discount)
```json
{
  "ok": true,
  "message": "Invoice updated successfully",
  "invoice": {
    "id": 88,
    "uuid": "3f2504e0-4f89-41d3-9a0c-0305e82c3301",
    "student_id": 12,
    "academic_year_id": 3,
    "year": 2025,
    "month": 10,
    "invoice_template_id": 3,
    "subtotal_required_amount": 120,
    "discount_percent": 25,
    "total_required_amount": 90,
    "total_paid_amount": 0,
    "status": "Not Paid",
    "created_by": 5,
    "created_at": "2025-10-01T09:00:00.000Z",
    "updated_by": 5,
    "updated_at": "2025-10-15T12:30:00.000Z"
  }
}
```

### Update many invoices (by filters)
- **PATCH** `/invoices`
- **Body:**
  - `filter` (optional): shared filter fields. At least one filter value is required (`400` otherwise).
  - `data` (required): `subtotal_required_amount`, `discount_percent`, `total_required_amount`, `status`.
- **Notes:** Bulk update cannot change `academic_year_id`, `year`, `month`, or `invoice_template_id` (`400` if provided). `total_required_amount` recalculates when `subtotal_required_amount`/`discount_percent` change and it is not supplied. Returns `{ ok, message, updated, ids }`.

**Example request**
```json
{
  "filter": {
    "academic_year_ids": [1],
    "months": [10]
  },
  "data": {
    "status": "Paid"
  }
}
```

**Example response**
```json
{
  "ok": true,
  "message": "Invoices updated successfully",
  "updated": 3,
  "ids": [9001, 9002, 9003]
}
```

### List invoices by academic year
- **GET** `/invoices/:academic_year_id`
- **Params:** `academic_year_id` (number). `404` if the academic year does not exist.
- Returns `{ ok, invoices }` (raw invoice rows, no user-name resolution).

**Example request**
```http
GET /invoices/3
```

**Example response**
```json
{
  "ok": true,
  "invoices": [
    {
      "id": 88,
      "uuid": "3f2504e0-4f89-41d3-9a0c-0305e82c3301",
      "student_id": 12,
      "academic_year_id": 3,
      "year": 2025,
      "month": 10,
      "invoice_template_id": 3,
      "subtotal_required_amount": 120,
      "discount_percent": 0,
      "total_required_amount": 120,
      "total_paid_amount": 120,
      "status": "Paid",
      "created_by": 5,
      "created_at": "2025-10-01T09:00:00.000Z",
      "updated_by": null,
      "updated_at": "2025-10-01T09:00:00.000Z"
    }
  ]
}
```

### Delete invoice
- **DELETE** `/invoices/:id`
- `404` if the invoice does not exist. Returns `{ ok, message }`.

**Example request**
```http
DELETE /invoices/88
```

**Example response**
```json
{
  "ok": true,
  "message": "Invoice deleted successfully"
}
```

### Delete many invoices (by filters)
- **DELETE** `/invoices`
- **Body:** `filter` (required): shared filter fields. At least one filter value is required (`400` otherwise). Returns `{ ok, message, deleted, ids }`.

**Example request**
```json
{
  "filter": {
    "ids": [9001, 9002]
  }
}
```

**Example response**
```json
{
  "ok": true,
  "message": "Invoices deleted successfully",
  "deleted": 2,
  "ids": [9001, 9002]
}
```

## Usage notes
- Designed to align with invoice templates/discounts per student enrollment; ensure academic year consistency.

## Frontend suggestions
- Block submit if `month` is outside 1-12.
- After create, refresh the invoices list (and statistics) for the academic year.
