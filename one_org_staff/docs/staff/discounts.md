# Discounts API

**Base path:** `/discounts`

Manage discounts applied to student groups for specific billings.

## Auth
- Guard: `RolesGuard`
- Roles: not enforced per-controller, assume authenticated; tighten if needed.

## Endpoints

### Create discount
- **POST** `/discounts`
- **Body (CreateDiscountDto):** `student_group_id` (int), `billing_id` (int), `name` (3-100 chars), `reason` (string), `percent` (1-100), `start_date` (ISO), `end_date` (ISO).
- **Side effects:** Re-resolves payments for the student group after creation.

### Update discount
- **PATCH** `/discounts/:id`
- **Body (UpdateDiscountDto, all optional):** `student_group_id`, `billing_id`, `name`, `reason`, `percent` (1-100), `start_date` (ISO), `end_date` (ISO).
- **Notes:** Validates that billing remains associated with the student group; rejects `start_date` later than `end_date`; re-resolves payments for the student group after update.

### List discounts
- **GET** `/discounts`
- **Query (GetDiscountDto):** optional arrays `ids`, `billing_ids`, `names`, `student_group_ids` (validated ints/strings, max 100 each).

### Delete discount
- **DELETE** `/discounts/:id`

## Usage notes
- Billing must belong to the student group; backend validates associations and percent range.
- Import via Excel is commented-out/not available in controller.

## Example request
- **Method:** POST
- **Path:** `/discounts`
- **Request body:**
```json
{
	"student_group_id": 22,
	"billing_id": 5,
	"name": "Sibling",
	"reason": "Sibling discount",
	"percent": 15,
	"start_date": "2025-09-01",
	"end_date": "2026-05-31"
}
```

## Example response
```json
{
	"ok": true,
	"discount": {
		"id": 91,
		"student_group_id": 22,
		"billing_id": 5,
		"name": "Sibling",
		"percent": 15
	}
}
```

## Frontend suggestions
- Provide date pickers for `start_date` and `end_date`.
- Show validation hints for percent range (1-100).
