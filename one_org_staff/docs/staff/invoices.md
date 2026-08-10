# Invoices API

**Base path:** `/students/invoices`

Manage student invoices within an academic year.

## Auth
- Guard: `RolesGuard`
- Roles: `owner`, `cashier` for all endpoints.

## Endpoints

### List invoices (filtered)
- **GET** `/students/invoices`
- **Query filters (all optional):**
	- `ids` (int[])
	- `student_group_ids` (int[])
	- `academic_year_ids` (int[])
	- `years` (int[], 2000-2100)
	- `months` (int[], 1-12)
	- `billing_ids` (int[])
	- `statuses` (string[], `Not Paid|Partially Paid|Paid|Overpaid|Refunded|Partially Refunded|Voucher`)

### Create invoice
- **POST** `/students/invoices`
- **Body (CreateInvoiceDto):** `academic_year_id` (int), `year` (2000-2100), `month` (1-12).

### Update invoice
- **PATCH** `/students/invoices/:id`
- **Body (UpdateInvoiceDto, all optional):** `academic_year_id`, `year`, `month`, `billing_id`, `subtotal_required_amount`, `discount_percent` (0-100), `total_required_amount`, `status` (`Not Paid|Partially Paid|Paid|Overpaid|Refunded|Partially Refunded|Voucher`).
- **Notes:** When `subtotal_required_amount` or `discount_percent` change and `total_required_amount` is not provided, it auto-recalculates; resolves wallet/payments after update.

### Update many invoices (by filters)
- **PATCH** `/students/invoices`
- **Body:**
	- `filter` (optional): same fields as list filters
	- `data` (required): `subtotal_required_amount`, `discount_percent`, `total_required_amount`, `status`
- **Notes:** Bulk update cannot change `academic_year_id`, `year`, `month`, or `billing_id`. Resolves wallet/payments after update.

### List invoices by academic year
- **GET** `/students/invoices/:academic_year_id`
- **Params:** `academic_year_id` (number).

### Delete invoice
- **DELETE** `/students/invoices/:id`

### Delete many invoices (by filters)
- **DELETE** `/students/invoices`
- **Body:**
	- `filter` (required): same fields as list filters

## Usage notes
- Designed to align with billings/discounts per student group; ensure academic year consistency.

## Example request
- **Method:** POST
- **Path:** `/students/invoices`
- **Request body:**
```json
{
	"academic_year_id": 1,
	"year": 2025,
	"month": 10
}
```

## Bulk update example
- **Method:** PATCH
- **Path:** `/students/invoices`
- **Request body:**
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

## Bulk delete example
- **Method:** DELETE
- **Path:** `/students/invoices`
- **Request body:**
```json
{
	"filter": {
		"ids": [9001, 9002]
	}
}
```

## Example response
```json
{
	"ok": true,
	"invoice": {
		"id": 9001,
		"academic_year_id": 1,
		"year": 2025,
		"month": 10
	}
}
```

## Frontend suggestions
- Block submit if `month` is outside 1-12.
- After create, refresh invoices list for the academic year.
