# Mini App Students API

**Base path:** `/mini-app/students`

Cookie-authenticated student list endpoints for the Telegram mini app.

## Middleware behavior
- Protected mini-app student routes validate the mini app token first.
- If a route includes `student_id` in params, query, or body, middleware verifies that the authenticated Telegram user is linked to that student through `contacts`.
- Student-specific routes should use `student_id` as the request field name so the middleware can validate access consistently.
- Controllers can read the access-validated student through the `@StudentId()` decorator instead of manually parsing `req.params`, `req.query`, or `req.body`.

## Accessible students
- **GET** `/mini-app/students/accessible`
- **Purpose:** return the students available to the currently authenticated mini app user.
- **Auth:** required via mini app token middleware

### Behavior
- Reads the mini app token from the cookie or bearer token.
- Resolves the linked `telegram_id` from Redis.
- Returns students reachable through contacts linked to that Telegram id.

### Example response
```json
{
  "ok": true,
  "message": "Accessible students resolved successfully",
  "result": {
    "students": [
      {
        "id": 25,
        "la_id": "LA-00025",
        "full_name": "Ali Valiyev",
        "nickname": "Ali",
        "picture": "https://cdn.example.com/students/25.jpg",
        "status": "active",
        "groups": [
          {
            "student_group_id": 77,
            "id": 14,
            "join_date": "2026-01-10",
            "leave_date": null,
            "status": "studying",
            "name": "Grade 7 - A",
            "grade": 7,
            "class": "A",
            "class_pair": "7-A",
            "class_pair_compact": "7A",
            "teacher_name": "Jane Doe"
          }
        ]
      }
    ]
  }
}
```

### No match response
```json
{
  "ok": true,
  "message": "No accessible students found",
  "result": {
    "students": []
  }
}
```

Student schedule documentation was moved to `docs/mini-app/schedule.md`.