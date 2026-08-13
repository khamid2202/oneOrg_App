# Health API

**Base path:** `/health`

Public service health check used for liveness/readiness probes and monitoring.

## Auth
- None — this endpoint is public (no token or permission required).

## Endpoints

### Health check
- **GET** `/health`
- Returns process uptime, a timestamp, database and Redis connectivity, and
  RAM/CPU usage. `ok` is `true` only when **both** the database and Redis
  checks pass.

## Example response
```json
{
  "ok": true,
  "uptime": {
    "raw": 12345.67,
    "formatted": "0d 3h 25m 45s"
  },
  "timestamp": 1751366400000,
  "db": { "ok": true },
  "redis": { "ok": true },
  "ramUsage": {
    "percentage": 62,
    "raw": { "total": 104857600, "used": 65011712, "overhead": 2097152 },
    "formatted": { "total": "100.00 MB", "used": "62.00 MB", "overhead": "2.00 MB" }
  },
  "cpuUsage": {
    "percentage": 3,
    "raw": { "user": 1200000, "system": 400000 },
    "formatted": { "user": "1200.00 ms", "system": "400.00 ms" }
  }
}
```

## Usage notes
- On a dependency failure the affected block reports `{ "ok": false, "error": "..." }`
  and the top-level `ok` becomes `false` — treat a non-200 body `ok: false` as
  unhealthy in monitoring.

## Frontend / ops suggestions
- Point uptime monitors and container liveness/readiness probes here.
- Alert when `ok` is `false` or either `db.ok` / `redis.ok` is `false`.
