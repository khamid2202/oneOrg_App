# Project Documentation

Two kinds of docs live here:

- **API references** — one file per backend feature (`attendance.md`, `points.md`, `contacts.md`, …). Endpoint shape, auth, examples.
- **Internal docs** — architecture & history:
  - `STRUCTURE.md` — proposed/target file structure & conventions
  - `CHANGELOG.md` — every notable change we make, newest first

## Convention (must follow)

1. **Every new feature** gets an API doc here (copy the shape of `attendance.md`).
2. **Every change** to the codebase gets a dated entry in `CHANGELOG.md`.
3. Architecture decisions update `STRUCTURE.md`.

## Index

| Doc | What |
|-----|------|
| [STRUCTURE.md](STRUCTURE.md) | Target file structure |
| [CHANGELOG.md](CHANGELOG.md) | Change history |
| [attendance.md](attendance.md) | Attendance API |
| [points.md](points.md) | Student points API |
| [contacts.md](contacts.md) | Contacts API |
