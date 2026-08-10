# Mini App Auth API

**Base path:** `/mini-app/auth`

Token-based authentication endpoints for the Telegram mini app.

## Telegram phone login
- **POST** `/mini-app/auth/telegram/phone`
- **Purpose:** validate Telegram Web App `init_data`, link the validated Telegram user id to matching contacts by phone number, create an access token, save it to Redis, and return it in the response.
- **Auth:** none

### Request body
```json
{
  "init_data": "query_id=AAHdF6IQAAAAAN0XohDhrOrc&user=%7B%22id%22%3A123456789%2C%22first_name%22%3A%22Ali%22%7D&auth_date=1746600000&hash=<telegram_hash>",
  "contact": {
    "phone_number": "+998901112233",
    "first_name": "Mubina",
    "last_name": "Xasanova",
    "user_id": 918273645
  }
}
```

### Behavior
- Validates `init_data` using `TELEGRAM_BOT_TOKEN`.
- Extracts the Telegram user id from `init_data.user.id`.
- Stores and returns `telegram_id` as a string so 64-bit ids are not rounded by JSON number parsing.
- Accepts `contact.user_id` as either a string or number when the frontend forwards Telegram contact data.
- Links that Telegram id to all matching contacts by normalized `phone_number`.
- Throws `400` if no contact matches the provided phone number.
- Creates a Redis-backed access token and returns it in the response.

### Example response
```json
{
  "ok": true,
  "message": "Mini app login successful",
  "result": {
    "token": "<opaque_token>",
    "token_type": "Bearer",
    "expires_in": 2592000,
    "telegram_id": "123456789",
    "linked_contacts": 2,
    "telegram": {
      "auth_date": 1746600000,
      "query_id": "AAHdF6IQAAAAAN0XohDhrOrc",
      "user": {
        "id": 123456789,
        "first_name": "Ali"
      }
    }
  }
}
```

## Telegram id login
- **POST** `/mini-app/auth/telegram/id`
- **Purpose:** create an access token for an already linked Telegram id, save it to Redis, and return it in the response.
- **Auth:** none

### Request body
```json
{
  "telegram_id": "123456789"
}
```

### Behavior
- Checks that the provided Telegram id is already linked to at least one contact.
- Send `telegram_id` as a string for int64 safety.
- Throws `401` if the Telegram id is not linked.
- Creates a Redis-backed access token and returns it in the response.

### Example response
```json
{
  "ok": true,
  "message": "Mini app login successful",
  "result": {
    "token": "<opaque_token>",
    "token_type": "Bearer",
    "expires_in": 2592000,
    "telegram_id": "123456789"
  }
}
```

## Validate token
- **GET** `/mini-app/auth/validate`
- **Purpose:** validate the current mini app access token.
- **Auth:** bearer token or `body.token`

### Behavior
- Reads the token from `Authorization: Bearer`, `body.token`, or a legacy `mini_app_token` cookie.
- Validates the token against Redis.
- Ensures the resolved Telegram id is still linked to at least one contact.

### Example response
```json
{
  "ok": true,
  "message": "Token is valid",
  "result": {
    "token": "<opaque_token>",
    "telegram_id": "123456789"
  }
}
```

## Revoke token
- **POST** `/mini-app/auth/revoke`
- **Purpose:** revoke the current mini app access token.
- **Auth:** bearer token or `body.token`

### Behavior
- Deletes the token from Redis.
- Also clears the legacy `mini_app_token` cookie when present.

### Frontend integration notes
- Use `/mini-app/auth/telegram/phone` for the first login after requesting a Telegram contact.
- Use `/mini-app/auth/telegram/id` for later logins when the app already knows the linked Telegram id.
- Store `result.token` on the client and send it as `Authorization: Bearer <token>` on subsequent mini-app requests.
- After login, call `/mini-app/auth/validate` with the bearer token to confirm the session.