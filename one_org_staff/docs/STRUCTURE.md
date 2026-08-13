# File Structure (Target)

Status: **proposal** — documentation only. No code has been moved as a result of
this file. When/if we migrate, update this doc and add a `CHANGELOG.md` entry.

This is a React + Vite role-based app (admin / teacher / shared), ~178 source
files. The bones are good — features are mostly co-located — but several
inconsistencies make the project harder to navigate than it needs to be.

---

## Problems in the current structure

| Issue | Where | Why it hurts |
|---|---|---|
| **Mixed folder casing** | `Hooks/` `Library/` `Layouts/` `Pages/` `UI/` (Pascal) vs `providers/` `routes/` `utils/` `assets/` (lower) | No rule to follow; import paths are guesswork |
| **God context** | `Hooks/UseContext.jsx` = **711 lines, 41 state/callbacks**, one giant `value` | Payments, dorm, course students, billings, classes, teachers, timetable all in one provider. Any change re-renders everything; hard to reason about |
| **Contexts live in `Hooks/`** | `AuthContext`, `UseContext` (a provider) | They're providers, not hooks — misleading location |
| **Three data-fetching patterns** | god-context, per-page hooks (`useExamReportData`, `useDormitoryData`…), and inline `api.get` in components | No single way to fetch; every new page reinvents it |
| **`Library/` is really the API layer** | `RequestMaker`, `Endpoints`, `Authenticate` | Fine code, misleading name |
| **Naming smells** | `Invoices2.0` (dot in folder), `Billlings` (typo), `PaymentNew`, dead `Auth.jsx`, two `Help.jsx`, two `Classes.jsx` | Confusing; looks unfinished |
| **6-level nesting** | `Pages/admin/ManagementPage/Dormitory/components/…` | Long paths, long imports |

---

## Target structure

Feature-first, lowercase folders, one fetch pattern. Keep it simple — this is
the right level of structure for the project; don't over-engineer.

```
src/
├── main.jsx
├── App.jsx
│
├── app/                      ← app-wide wiring (was scattered)
│   ├── providers.jsx         ← AppProviders + AuthProvider composed here
│   └── routes/               ← (was routes/) AppRoutes + modules/
│
├── api/                      ← (was Library/) the API layer
│   ├── client.js             ← RequestMaker (axios instance + interceptor)
│   ├── endpoints.js
│   └── auth.js               ← Authenticate
│
├── auth/                     ← (was Pages/auth/) auth is a concern, not a page
│   ├── AuthContext.jsx       ← moved out of Hooks/
│   ├── ProtectedRoute.jsx
│   └── Login/
│
├── shared/                   ← cross-feature reusable pieces
│   ├── components/           ← (was UI/ + generic Layouts/Custom/)
│   ├── layout/               ← Layout (page frame) + Custom/ dropdowns
│   ├── navigation/           ← Navbar + navigationConfig (the shared nav map)
│   └── hooks/                ← truly global hooks (useGlobalSearchShortcut)
│
├── features/                 ← (was Pages/admin + Pages/teacher)
│   ├── payments/
│   │   ├── PaymentsPage.jsx
│   │   ├── components/
│   │   ├── hooks/            ← usePayments() lives WITH the feature
│   │   └── utils/
│   ├── dormitory/
│   ├── timetable/
│   ├── attendance/
│   ├── exams/
│   ├── invoices/             ← renamed from Invoices2.0
│   ├── billing/              ← fix the typo
│   └── … (one folder per domain)
│
└── styles/
```

---

## The two rules that fix most of the pain

1. **Kill the god context.** Split `UseContext.jsx` so each domain owns its own
   state + fetching in `features/<x>/hooks/use<X>.js`. We already do this for
   exams, dormitory, and assessments — make it the *only* pattern. Keep
   `AuthContext` global (it genuinely is). Only promote data to a shared
   provider if two or more features truly need the same live data.

2. **One folder = one feature**, flat under `features/`, instead of nesting
   everything beneath `admin/ManagementPage/…`. Role (admin vs teacher) is an
   *access* concern — enforce it in routing, not in the folder tree.

---

## Open decision: role-first vs domain-first

The one real judgment call is whether the top level is organized by **role**
(current `admin/` `teacher/`) or by **domain** (`features/payments`,
`features/exams`).

Recommendation: **domain-first.** Several things (Classes, Help, attendance)
already exist under both roles and got duplicated; a flat `features/` folder
removes that duplication. Choose role-first only if the two apps are genuinely
separate products that won't share code.

---

## Current → target mapping

| Current | Target |
|---|---|
| `src/Library/` | `src/api/` ✅ done 2026-06-26 |
| `src/Hooks/AuthContext.jsx` | `src/auth/AuthContext.jsx` ✅ done 2026-06-26 |
| `src/Hooks/UseContext.jsx` | split into `src/features/<x>/hooks/` — ⏳ data hooks moved to `features/<x>/hooks/` ✅ 2026-06-26; the composing `DataProvider` still lives at `src/Hooks/UseContext.jsx` |
| `src/Hooks/useGlobalSearchShortcut.js` | `src/shared/hooks/` ✅ done 2026-06-26 |
| `src/providers/AppProviders.jsx` | `src/app/providers.jsx` ✅ done 2026-06-26 |
| `src/routes/` | `src/app/routes/` ✅ done 2026-06-26 |
| `src/UI/` | `src/shared/components/` ✅ done 2026-06-26 |
| `src/Styles/` | `src/styles/` ✅ done 2026-06-26 |
| `src/Layouts/` | `src/shared/layout/` ✅ done 2026-06-26 |
| `src/utils/` | `src/shared/utils/` ✅ done 2026-06-26 → later moved to `src/shared/navigation/` (with `Navbar.jsx`) on 2026-06-28; `shared/utils/` removed |
| `src/Pages/auth/` | `src/auth/` ✅ done 2026-06-26 |
| `src/Pages/admin/**`, `src/Pages/teacher/**` | `src/features/<domain>/` ✅ done 2026-06-26 (domain-first, fully flat) |
| `Invoices2.0/` | `features/invoices/` (folder renamed to `invoices/` ✅ 2026-06-26) |
| `Billings/Billlings.jsx` | `features/billing/Billing.jsx` (typo fixed → `Billing.jsx` ✅ 2026-06-26; **feature removed entirely 2026-07-01**) |
| `Pages/auth/Auth.jsx` (dead) | delete ✅ done 2026-06-26 (already removed) |

---

## Suggested migration order (lowest risk first)

1. Cosmetic renames: casing, `Library/ → api/`, fix `Billlings` / `Invoices2.0`,
   delete dead `Auth.jsx`.
2. ~~Move contexts/providers/routes into `app/` and `auth/`.~~ **DONE
   2026-06-26.**
3. ~~**Highest impact:** split the 711-line god context into per-feature
   hooks.~~ **DONE 2026-06-26** — decomposed into per-domain hooks under
   `src/Hooks/data/` with the public `useGlobalContext` API unchanged. See
   [CHANGELOG.md](CHANGELOG.md). Next refinement: when flattening into
   `features/`, move each `Hooks/data/use<X>Data.js` to its feature folder and
   (optionally) give it a dedicated provider instead of the single composed one.
4. ~~Flatten `Pages/admin|teacher/**` into `features/`.~~ **DONE 2026-06-26**
   (domain-first, fully flat). Added a `@` → `src/` path alias
   (`vite.config.js` + `jsconfig.json`) so cross-boundary imports use `@/...`
   instead of `../../../` chains; data hooks moved into their feature
   `hooks/` folders.

Steps 1–2 are find-and-replace on imports. Step 3 (done) was the real work and
the real payoff. Step 4 (done) removed the role/ManagementPage nesting.

## Import convention

Use the `@` alias for any import that crosses a top-level boundary
(`@/features/...`, `@/shared/...`, `@/api/...`, `@/auth/...`). Keep `./` and
`../` only for imports **within** the same feature. This keeps moves cheap and
paths readable.
