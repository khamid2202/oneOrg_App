# Payments API

**Base path:** `/students/payments`

Handle student payments tied to invoices/wallets.

## Auth
- Guard: `RolesGuard`
- Roles: `owner`, `cashier` for all endpoints.

## Endpoints

### Create payment
- **POST** `/students/payments`
- **Body (CreatePaymentDto):** `student_group_id` (int), `purpose` (string), `amount` (int between -50000 and 50000), `method` (string), optional `comment`, `is_refund` (bool, default false).

### Get payment (single)
- **GET** `/students/payments/:id`
- **Params:** `id` payment ID.

### Update payment
- **PATCH** `/students/payments/:id`
- **Body:** same as create DTO.

### Delete payment
- **DELETE** `/students/payments/:id`

### List payments
- **GET** `/students/payments`
- **Status:** currently throws `NotImplementedException` (not yet implemented).

## Usage notes
- All routes require cashier/owner role.
- Listing endpoint is stubbed; avoid calling until implemented.

## Example request
- **Method:** POST
- **Path:** `/students/payments`
- **Request body:**
```json
{
	"student_group_id": 22,
	"purpose": "October tuition",
	"amount": 500,
	"method": "cash",
	"comment": "paid at front desk",
	"is_refund": false
}
```

## Example response
```json
{
	"ok": true,
	"payment": {
		"id": 3001,
		"student_group_id": 22,
		"amount": 500,
		"method": "cash"
	}
}
```

## Frontend suggestions
- Disable or hide list views until list endpoint is implemented.
- Validate amount range before submit.
