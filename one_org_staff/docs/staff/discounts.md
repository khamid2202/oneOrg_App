# Discounts API

**Base path:** `/discounts`

Manage discounts applied to student enrollments for specific invoice templates.
Active discounts (by date range) are summed per template during invoice
generation.

## Auth
- Guard: `RolesGuard`; no per-endpoint permissions — any authenticated staff
  user.

## Endpoints

| Method | Path | Description |
| --- | --- | --- |
| POST | `/discounts` | Create a discount |
| PATCH | `/discounts/:id` | Update a discount |
| GET | `/discounts` | List discounts (filtered) |
| DELETE | `/discounts/:id` | Delete a discount |

### Create discount
- **POST** `/discounts`
- **Body (CreateDiscountDto):** `student_id` (int — the enrollment),
  `invoice_template_id` (int — must be listed in the student's
  `invoice_template_ids`, `400` otherwise), `name` (3-100 chars), `reason`
  (string), `percent` (1-100), `start_date` (ISO), `end_date` (ISO).

**Example request**
```json
{
  "student_id": 12,
  "invoice_template_id": 3,
  "name": "Sibling",
  "reason": "Sibling discount",
  "percent": 15,
  "start_date": "2025-09-01",
  "end_date": "2026-05-31"
}
```

**Example response**
```json
{
  "ok": true,
  "message": "Discount created successfully",
  "discount": {
    "id": 91,
    "student_id": 12,
    "invoice_template_id": 3,
    "name": "Sibling",
    "reason": "Sibling discount",
    "percent": 15,
    "start_date": "2025-09-01T00:00:00.000Z",
    "end_date": "2026-05-31T00:00:00.000Z",
    "created_by": 5,
    "created_at": "2025-08-20T09:00:00.000Z"
  }
}
```

### Update discount
- **PATCH** `/discounts/:id`
- **Body (UpdateDiscountDto, all optional):** `student_id`,
  `invoice_template_id`, `name`, `reason`, `percent` (1-100), `start_date`,
  `end_date`.
- **Notes:** `400` if the discount is missing, if the effective template is not
  associated with the effective student, or if `start_date` ends up after
  `end_date`.

**Example request**
```http
PATCH /discounts/91
```
```json
{
  "percent": 20
}
```

**Example response**
```json
{
  "ok": true,
  "message": "Discount updated successfully",
  "discount": {
    "id": 91,
    "student_id": 12,
    "invoice_template_id": 3,
    "name": "Sibling",
    "reason": "Sibling discount",
    "percent": 20,
    "start_date": "2025-09-01T00:00:00.000Z",
    "end_date": "2026-05-31T00:00:00.000Z",
    "created_by": 5,
    "created_at": "2025-08-20T09:00:00.000Z",
    "updated_by": 5,
    "updated_at": "2025-09-10T10:00:00.000Z"
  }
}
```

### List discounts
- **GET** `/discounts`
- **Query (GetDiscountDto), all optional JSON arrays (max 100 each):** `ids`,
  `invoice_template_ids`, `names`, `student_ids`.
- Rows include the student's `student_name` and `created_by` / `updated_by`
  resolved to user full names.

**Example request**
```http
GET /discounts?student_ids=[12]
```

**Example response**
```json
{
  "ok": true,
  "message": "Discounts retrieved successfully",
  "meta": { "total": 1, "query": { "student_ids": [12] } },
  "discounts": [
    {
      "id": 91,
      "student_id": 12,
      "student_name": "Ali Valiyev",
      "invoice_template_id": 3,
      "name": "Sibling",
      "percent": 20,
      "reason": "Sibling discount",
      "start_date": "2025-09-01",
      "end_date": "2026-05-31",
      "created_at": "2025-08-20T09:00:00.000Z",
      "created_by": "Kamola Karimova",
      "updated_at": "2025-09-10T10:00:00.000Z",
      "updated_by": "Kamola Karimova"
    }
  ]
}
```

### Delete discount
- **DELETE** `/discounts/:id`
- Returns an empty `200` body; `400` if the discount does not exist.

**Example request**
```http
DELETE /discounts/91
```

## Usage notes
- The invoice template must be associated with the student enrollment; the
  backend validates the association and the percent range.
- New/updated discounts affect amounts the next time invoices are generated for
  the period (see [Invoices](invoices.md)).

## Frontend suggestions
- Provide date pickers for `start_date` and `end_date`.
- Show validation hints for percent range (1-100).
