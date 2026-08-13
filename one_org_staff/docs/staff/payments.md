# Payments API

**Base path:** `/payments`

Record student payments (and refunds) against a specific invoice. Creating a
payment updates the target invoice's paid total and status directly.

## Auth
- Guard: `RolesGuard` + permission checks via `@RequirePermissions`.
- Permissions: `payments.create`, `payments.read`, `payments.update`,
  `payments.delete` per endpoint (smart pay uses `payments.create`).

## Endpoints

| Method | Path | Description | Permission |
| --- | --- | --- | --- |
| POST | `/payments` | Record a payment/refund | `payments.create` |
| POST | `/payments/smart-pay` | Prepay & settle upcoming invoices | `payments.create` |
| GET | `/payments/:id` | Get one payment | `payments.read` |
| GET | `/payments` | List payments (not implemented) | `payments.read` |
| PATCH | `/payments/:id` | Update a payment | `payments.update` |
| DELETE | `/payments/:id` | Delete a payment | `payments.delete` |

### Create payment
- **POST** `/payments`
- **Body (CreatePaymentDto):**
  - `student_id` (int, required) — the student **enrollment** (student-group) id.
  - `invoice_id` (int, required) — must belong to that enrollment.
  - `amount` (int, -50000…50000) — positive for a payment, negative for a refund.
  - `method` (string, required) — e.g. `cash`, `cheque`, `transfer`.
  - `date` (ISO date string, optional — defaults to today).
  - `comment` (string, optional).
  - `is_refund` (bool, default `false`).
- **Validation:**
  - Enrollment and its person must exist; the invoice must exist and belong to
    the enrollment.
  - Sign must match the flag: `is_refund=true` requires a negative `amount`;
    otherwise `amount` must be positive.
  - **Applicability:** the payment may not push the invoice's paid total **over**
    its required amount (`400` with the remaining amount), and a refund may not
    push it **below** zero (`400` with the amount paid so far).
- **Effect:** in a single transaction, the payment row is saved and the invoice's
  `total_paid_amount` and `status` are updated in place. Voucher invoices are
  left untouched (no applicability check, no paid-total update).

**Example request**
```json
{
  "student_id": 22,
  "invoice_id": 88,
  "amount": 500,
  "method": "cash",
  "comment": "paid at front desk",
  "is_refund": false
}
```

**Example response**
```json
{
  "ok": true,
  "message": "Payment recorded and invoice updated",
  "meta": { "is_refund": false },
  "payment": {
    "id": 3001,
    "student_id": 22,
    "invoice_id": 88,
    "amount": 500,
    "date": "2026-07-01",
    "method": "cash",
    "comment": "paid at front desk",
    "is_refund": false,
    "created_by": 5,
    "created_at": "2026-07-01T09:30:00.000Z"
  }
}
```

### Smart pay (prepay & settle)
- **POST** `/payments/smart-pay`
- A single lump sum that **first clears the student's outstanding unpaid
  invoices, then pre-bills and settles upcoming tuition** through the end of the
  academic year.
- **Body (SmartPayDto):**
  - `student_id` (int, required) — the student **enrollment** id.
  - `amount` (int, 1…10,000,000) — the lump sum to apply (positive only; smart
    pay never creates refunds).
  - `method` (string, required) — e.g. `cash`, `cheque`, `transfer`.
  - `date` (ISO date string, optional — defaults to today; used on every created
    payment).
  - `comment` (string, optional — copied to every created payment).
- **How it works:**
  1. Builds an ordered settlement plan:
     - **Part 1 — outstanding debt first:** every existing invoice for the
       student that is `Not Paid` / `Partially Paid`, earliest first (this
       includes past-due months, not just upcoming ones).
     - **Part 2 — upcoming months:** the not-yet-generated invoices for each
       month from the current month to the academic year's end month (months
       before the year's start are excluded; the year must have
       `start_date`/`end_date` set), with active discounts applied.
  2. Sums the **total still owed** across the plan (outstanding balance for
     Part 1, freshly-computed required amount for Part 2).
  3. **If `amount` exceeds that total, the whole request is rejected (`400`) and
     nothing is created.**
  4. Otherwise, in a single transaction, it walks the plan in order and, for each
     invoice it can still pay, **creates the invoice if needed** (Part 2 only)
     and records a **payment** settling it — fully, until the amount runs out
     (the last invoice may be settled partially). Upcoming invoices beyond what
     the amount covers are **not** created. Each payment updates its invoice's
     paid total and status (`Paid` / `Partially Paid`). `Voucher`/`Refunded`
     invoices are skipped.
- **Result:** `amount_requested`, `amount_applied`, `invoices_created`
  (upcoming invoices generated), `invoices_paid`, and the created `payments`.

**Example request**
```http
POST /payments/smart-pay
Content-Type: application/json

{ "student_id": 22, "amount": 1500, "method": "transfer", "comment": "3 months upfront" }
```

**Example response**
```json
{
  "ok": true,
  "message": "Smart payment processed",
  "result": {
    "student_id": 22,
    "amount_requested": 1500,
    "amount_applied": 1500,
    "invoices_created": 3,
    "invoices_paid": 3,
    "payments": [
      { "id": 4001, "student_id": 22, "invoice_id": 90, "amount": 500, "date": "2026-07-08", "method": "transfer", "comment": "3 months upfront", "is_refund": false, "created_by": 5 },
      { "id": 4002, "student_id": 22, "invoice_id": 91, "amount": 500, "date": "2026-07-08", "method": "transfer", "comment": "3 months upfront", "is_refund": false, "created_by": 5 },
      { "id": 4003, "student_id": 22, "invoice_id": 92, "amount": 500, "date": "2026-07-08", "method": "transfer", "comment": "3 months upfront", "is_refund": false, "created_by": 5 }
    ]
  }
}
```

**Rejections (`400`):** student/group/academic-year not found; academic year has
no configured `start_date`/`end_date`; the student has no outstanding or upcoming
invoices to pay; or `amount` exceeds the total required to fulfil the unpaid and
upcoming invoices.

### Get payment (single)
- **GET** `/payments/:id`
- Returns the **bare payment row** (or `null` if not found — no `404`).

**Example request**
```http
GET /payments/3001
```

**Example response**
```json
{
  "id": 3001,
  "uuid": "6e1f04a0-2b89-41d3-9a0c-0305e82c3399",
  "student_id": 22,
  "invoice_id": 88,
  "amount": 500,
  "date": "2026-07-01",
  "method": "cash",
  "comment": "paid at front desk",
  "is_refund": false,
  "created_by": 5,
  "created_at": "2026-07-01T09:30:00.000Z",
  "updated_by": null,
  "updated_at": null
}
```

### Update payment
- **PATCH** `/payments/:id`
- **Body:** `CreatePaymentDto`. (Note: this currently saves the payload as-is and
  does not re-apply invoice totals.)

**Example request**
```http
PATCH /payments/3001
```
```json
{
  "student_id": 22,
  "invoice_id": 88,
  "amount": 450,
  "method": "transfer",
  "is_refund": false
}
```

**Example response** (the saved row)
```json
{
  "student_id": 22,
  "invoice_id": 88,
  "amount": 450,
  "method": "transfer",
  "is_refund": false
}
```

### Delete payment
- **DELETE** `/payments/:id`
- Returns the TypeORM delete result (does not `404` on a missing id).

**Example request**
```http
DELETE /payments/3001
```

**Example response**
```json
{ "raw": [], "affected": 1 }
```

### List payments
- **GET** `/payments`
- Currently throws `NotImplementedException` (`501`).

**Example request**
```http
GET /payments
```

**Example response**
```json
{
  "statusCode": 501,
  "message": "Not Implemented"
}
```

## Frontend suggestions
- Before submitting, show the invoice's remaining balance
  (`total_required_amount - total_paid_amount`) and cap the input so payments
  can't exceed it (refunds can't exceed the amount paid).
- The list endpoint is stubbed — hide list views until it is implemented.
