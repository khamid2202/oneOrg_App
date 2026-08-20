# Staff Notifications API

Endpoints for staff members to manage device FCM tokens, view in-app notifications, mark notifications as read, and dispatch push notifications.

## Authentication & Authorization
- **Header Required**: `Authorization: Bearer <token>`
- **Permission for sending push**: `notifications.create` (or `admin` wildcard)

---

## Endpoints

### 1. Register Device Token
Register or update FCM device registration token for current logged-in staff user.

```http
POST /notifications/device-token
Content-Type: application/json

{
  "token": "fcm_device_token_string",
  "platform": "web"
}
```

#### Response `201 Created`
```json
{
  "id": 1,
  "user_id": 4,
  "person_id": null,
  "telegram_id": null,
  "token": "fcm_device_token_string",
  "platform": "web",
  "created_at": "2026-08-12T09:00:00.000Z",
  "updated_at": "2026-08-12T09:00:00.000Z"
}
```

---

### 2. Unregister Device Token
Remove registered FCM token.

```http
DELETE /notifications/device-token
Content-Type: application/json

{
  "token": "fcm_device_token_string"
}
```

#### Response `204 No Content`

---

### 3. Get Notifications List
Retrieve paginated notifications for current staff user.

```http
GET /notifications?page=1&limit=20&is_read=false
```

#### Response `200 OK`
```json
{
  "items": [
    {
      "id": 10,
      "user_id": 4,
      "person_id": null,
      "title": "New Payment Received",
      "body": "Payment of 500,000 UZS was successfully processed.",
      "data": { "invoice_id": 12 },
      "type": "payment",
      "is_read": false,
      "read_at": null,
      "created_at": "2026-08-12T08:30:00.000Z"
    }
  ],
  "total": 1,
  "page": 1,
  "limit": 20,
  "pages": 1,
  "unread_count": 1
}
```

---

### 4. Get Unread Count
Get count of unread notifications for current staff user.

```http
GET /notifications/unread-count
```

#### Response `200 OK`
```json
{
  "unread_count": 1
}
```

---

### 5. Mark Notification as Read

```http
PATCH /notifications/:id/read
```

#### Response `200 OK`
```json
{
  "id": 10,
  "user_id": 4,
  "is_read": true,
  "read_at": "2026-08-12T09:05:00.000Z"
}
```

---

### 6. Mark All Notifications as Read

```http
POST /notifications/read-all
```

#### Response `200 OK`
```json
{
  "success": true
}
```

---

### 7. Send Notification (Admin / Staff)
Send a notification to the selected recipients. Requires `notifications.create` permission.

```http
POST /notifications/send
Content-Type: application/json

{
  "target_type": "user",
  "user_id": 4,
  "title": "Important Announcement",
  "body": "Please attend the staff meeting at 3 PM.",
  "type": "announcement",
  "data": { "key": "value" }
}
```

#### Delivery contract
Every recipient-based target behaves identically:

1. Recipients are resolved from `target_type`.
2. One notification row is written per recipient — these are what `GET /notifications` and `GET /mini-app/notifications` return.
3. A push is then sent to each recipient's registered devices.

Persistence happens first and push is **best-effort**: a recipient with no registered device, or whose push FCM rejects, still receives the in-app notification. A push failure never fails the request — check `devices_pushed` in the response instead.

#### Target Types
| `target_type` | Recipients | Writes inbox rows |
| --- | --- | --- |
| `user` | The user given by `user_id` (required) | Yes |
| `person` | The student/guardian given by `person_id` (required) | Yes |
| `staff` | All users with `status = 'active'` | Yes |
| `students` | All persons with a `present` student enrollment | Yes |
| `all` | Both of the above | Yes |
| `topic` | Raw FCM topic given by `topic` (defaults to `'all'`) | **No** |

`topic` is a delivery-only escape hatch: there is no recipient list behind an FCM topic, so nothing can be persisted and the in-app inbox will not show it. It also requires devices to have been subscribed to that topic out of band — the API never subscribes them. Use `staff`, `students` or `all` for broadcasts.

#### Response `201 Created`
```json
{
  "success": true,
  "target_type": "staff",
  "recipients": 128,
  "notifications_created": 128,
  "devices_targeted": 74,
  "devices_pushed": 71,
  "push_failures": 3
}
```

| Field | Meaning |
| --- | --- |
| `recipients` | Distinct people addressed |
| `notifications_created` | Inbox rows written |
| `devices_targeted` | Registered devices the push was attempted against |
| `devices_pushed` | Devices FCM accepted the push for |
| `push_failures` | Devices FCM rejected |

`devices_pushed: 0` alongside a non-zero `notifications_created` means delivery is broken (FCM misconfigured, or nobody has registered a device) while the in-app notification still landed.

For `user` and `person` targets the created row is also returned, as before:

```json
{
  "success": true,
  "target_type": "user",
  "recipients": 1,
  "notifications_created": 1,
  "devices_targeted": 2,
  "devices_pushed": 2,
  "push_failures": 0,
  "notification": {
    "id": 11,
    "user_id": 4,
    "person_id": null,
    "title": "Important Announcement",
    "body": "Please attend the staff meeting at 3 PM.",
    "data": { "key": "value" },
    "type": "announcement",
    "is_read": false,
    "read_at": null,
    "created_at": "2026-08-12T09:00:00.000Z"
  }
}
```

Device tokens FCM reports as permanently unregistered are deleted automatically after a send, so `devices_targeted` does not drift upward as apps are uninstalled.
