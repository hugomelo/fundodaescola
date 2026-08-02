# CLAUDE.md

Guidance for AI agents (and humans) working in this repository.

## What this is

**Fundo da Escola** — a web app to track a Waldorf school class's **trip fund**.
Parents/guardians see only their own child's contributions (how much they've paid,
how much they're ahead or behind their pledge); everyone sees an aggregate,
non-identifying view of the fund's progress toward its goal. Multiple **grades**
(turmas) are supported, each with its own admins.

Product/UI language is **Brazilian Portuguese**; currency is **BRL**.

## Repository layout (monorepo)

```
api/     Rails 8 API-only backend (Ruby 3.4.4, PostgreSQL, JWT auth)
web/     Vue 3 + Vite SPA frontend (Portuguese, BRL)
deploy/  Caddyfile (reverse proxy / TLS)
docker-compose.yml         Production stack: Postgres + API + Caddy
.github/workflows/pages.yml GitHub Pages deploy for web/
```

- **Frontend** deploys to **GitHub Pages**; **backend** runs on a VPS at
  `api.fundodaescola.com.br` (Caddy terminates TLS, proxies to Puma).
- Auth is **JWT Bearer** (cross-origin; frontend and API are different origins).

## Tech / versions

- Ruby **3.4.4** (pinned in `.ruby-version`, managed via `rbenv`), Rails **8.1**.
- Node **22**, Vite, Vue 3, Vue Router (hash history), Pinia, Axios.
- PostgreSQL (dev: Docker container on port **5433**; prod: Docker service).

## Data model (`api/app/models`)

| Model | Purpose / key fields |
|---|---|
| **Grade** | turma; `name`, `school_name`, `target_total_cents`, `currency`, `school_year_start/end`, `description` |
| **Student** | `grade_id`, `full_name`, `display_name`, `enrolled_from`, `enrolled_until`, `active` |
| **MonthlyPledge** | `student_id`, `month` (1st of month), `amount_cents`, `status` enum(`pledged`/`not_applicable`); unique per (student, month) |
| **Payment** | `grade_id`, `student_id?`, `payer_mapping_id?`, `paid_on`, `paid_time`, `description` (payer), `amount_cents` (signed), `kind` enum(`student_contribution`/`event`), `external_ref` (dedup), `needs_review` |
| **PayerMapping** | `grade_id`, `payer_text`, `student_id?`, `maps_to_event`; maps a bank-statement payer name to a student or "Evento" |
| **InvestmentEntry** | `grade_id`, `month`, `amount_cents`, `note`; monthly investment yield entered manually |
| **Event** | `grade_id`, `name`, `starts_on`, `ends_on?`; event dates used to flag ambiguous payments |
| **Trip** | `grade_id`, `name`, `level` (e.g. "5º"), `trip_year`, `position`; a destination the grade travels to in a given year |
| **TripCostEntry** | `trip_id`, `year`, `amount_cents` (per student); a real reported cost for a year; unique (trip, year) |
| **User** | `email`, `password_digest` (has_secure_password), `name`, `role` enum(`super_admin`/`grade_admin`/`parent`), `grade_id?` |
| **StudentAccess** | join `user_id` ↔ `student_id` (many parents per student, siblings per parent) |

### Core formulas
- Student **contributed** = Σ their `student_contribution` payments (signed).
- Student **expected** (to date) = Σ `pledged` pledges for months ≤ current month.
- Student **balance** = contributed − expected (positive = ahead, negative = behind).
- Grade **net raised** = Σ all payments (both kinds, signed) + Σ investment entries.
- Grade **progress** = net raised ÷ `target_total_cents`.

Contributions are **derived from payments** (no manual monthly "contributed"
field). Events count toward the grade total but never toward a student's balance.
Payment **amount sign** encodes income vs. expense/refund.

### Trip cost plan (how much to accumulate)
`CostPlan` (`app/services/cost_plan.rb`) projects the grade's total need. Each
**Trip** happens in a `trip_year`; its per-student cost is the most recent real
`TripCostEntry` inflated at `Grade#inflation_rate` (default 6%/yr) up to that year
— a real value entered for a later year overrides the projection from then on.
`total_per_student = Σ trip cost at its trip_year`; `total_needed = total_per_student ×
active students`. Exposed read-only to any grade member at `GET /api/grades/:id/
cost_plan`; admins manage it under `/admin/grades/:id/trips` (+ `trip_cost_entries`)
and can push the total into `target_total_cents`. Seed the legacy trips with
`rails trips:seed` (validates to R$ 23.035,21 per student).

## Roles & authorization

- `super_admin`: everything, all grades; can create grades and set any role.
- `grade_admin`: scoped to their own `grade_id`; manages that grade only; may only
  create/manage `parent` users.
- `parent`: read-only; sees only their linked student(s) via `StudentAccess`.

Enforced in `ApplicationController` (`authenticate!`, `authorize!`,
`require_admin!`) and `User#can_admin_grade?` / `#can_access_student?` /
`#accessible_grade_ids`. Admin controllers live under
`api/app/controllers/api/admin/` and inherit `Api::Admin::BaseController`.

## Key API endpoints (all under `/api`)

- `POST /auth/login`, `GET /me`
- Parent: `GET /students/:id/summary`, `GET /students/:id/payments`,
  `GET /grades/:id/overview`
- Admin (`/admin`): `grades` (CRUD + `:id/dashboard`), nested `students`,
  `payer_mappings`, `investment_entries`, `events`, `payments` (+ `POST
  .../payments/import`), plus `students` (show/update/destroy) with nested
  `monthly_pledges`, and top-level `monthly_pledges`, `payments`,
  `payer_mappings`, `investment_entries`, `events`, `users`.

Serializers are plain POROs in `api/app/serializers`.

## Importers (`api/app/services`)

**`SpreadsheetImporter`** — one-time import of the legacy Google Sheet (two CSVs in
`api/db/import_data/`). The payments tab is authoritative for the roster + all
transactions; the students tab supplies monthly pledges. Names differ between tabs
and are reconciled by token overlap. Payer mappings default to a payer's
**dominant student** (occasional event donations ignored). Run via
`rails import:spreadsheet` (see `api/lib/tasks/import.rake`).

**`BankStatementImporter`** — incremental bank-statement CSV upload (admin UI or
`POST /admin/grades/:id/payments/import`). Handles the real bank export:
- Auto-detects delimiter (`;` or `,`) and reads the header row.
- Strips Pix/transfer prefixes ("Pix recebido de <nome>", etc.) to recover payer.
- Coerces ASCII-8BIT/Latin-1 uploads to UTF-8 (needed for `unicode_normalize`).
- Auto-maps known payers via `PayerMapping`; unknown payers left unmapped.
- **Flags for review** (`needs_review`) any payment on a registered **event day**
  or from an unidentified payer (the event-vs-cake ambiguity).
- **Ignores internal investment-account transfers** (regex `investimento|aplicac|
  resgate|rdb|cdb|renda fixa`) — the money stays in the fund; only yield is entered
  manually. Re-import removes any previously imported such rows.
- Idempotent via `external_ref` (MD5 of date|time|payer|amount).

`rails import:rebuild_mappings` rebuilds/retro-applies payer mappings.

## Frontend structure (`web/src`)

- `api/client.js` — Axios instance; injects JWT from `localStorage` (`cc_token`);
  redirects to login on 401. Base URL from `VITE_API_BASE_URL`.
- `stores/auth.js` — login/me/logout, role getters. `stores/admin.js` — grade list
  and currently selected grade (`cc_admin_grade`).
- `router/index.js` — hash history; guards for auth + admin.
- Views: `LoginView`, `HomeView`, `ParentDashboardView`, and
  `views/admin/*` (`AdminLayout`, `DashboardView`, `PaymentsView` (with review
  queue), `EventsView`, `StudentsView`, `StudentPledgesView`, `MappingsView`,
  `InvestmentsView`, `UsersView`, `SettingsView`). `components/GradeOverview.vue`.
- `utils/format.js` — `brl`, `monthLabel`, `dateLabel`, `percent`.
- Theme: warm "harvest" palette in `style.css`.

## Local development

Prereqs: rbenv Ruby 3.4.4, Node 22, Docker.

```bash
# 1. Postgres (isolated Docker instance on port 5433)
docker run -d --name colheita-pg \
  -e POSTGRES_USER=colheita -e POSTGRES_PASSWORD=colheita \
  -e POSTGRES_DB=colheita_development -p 5433:5432 postgres:17

# 2. API  (config in api/.env)
cd api
bundle install
bin/rails db:prepare
bin/rails import:spreadsheet GRADE_NAME="Turma da Nina" SCHOOL_NAME="Escola Waldorf" TARGET_TOTAL=80000
bin/rails db:seed
bin/rails s -p 3001

# 3. Frontend  (config in web/.env)
cd web && npm install && npm run dev   # http://localhost:5173
```

Because of an rbenv/PATH quirk here, prefer `rbenv exec bundle exec rails ...`
when `bin/rails` isn't resolvable.

Seed users (password `colheita123`): `admin@colheita.local` (super),
`coordenador@colheita.local` (grade admin), `responsavel@colheita.local` (parent).

## Environment variables

- **api/.env** (dev): `DATABASE_HOST/PORT/USER/PASSWORD/NAME`, `JWT_SECRET`,
  `CORS_ORIGINS`.
- **web/.env** / **web/.env.production**: `VITE_API_BASE_URL`, `VITE_BASE_PATH`.
- **Prod** (`.env` beside docker-compose, from `.env.production.example`):
  `DATABASE_*`, `SECRET_KEY_BASE`, `JWT_SECRET`, `CORS_ORIGINS`, `API_DOMAIN`.

## Deploy

- **Backend:** VPS `vps.prout.io`, served at `api.fundodaescola.com.br`. Point DNS
  at the VPS, fill `.env`, then `docker compose up -d --build`. Migrations run on
  boot (`rails db:prepare`). `config/environments/production.rb` sets
  `config.hosts`/host-authorization from `API_DOMAIN`; Caddy handles TLS
  (`assume_ssl = true`).
- **Frontend:** GitHub Pages at `fundodaescola.com.br` via
  `.github/workflows/pages.yml` on push to `main`. Build uses
  `VITE_API_BASE_URL=https://api.fundodaescola.com.br/api` and `VITE_BASE_PATH=/`;
  `web/public/CNAME` pins the custom domain. Enable Pages → GitHub Actions and set
  the custom domain in Settings.

## Conventions

- Money stored as integer **cents** (`*_cents`); format with `brl()` on the front.
- Months stored as a **date on the 1st**; normalized in model callbacks.
- Enums are Rails `enum`; serialize as strings over the API.
- New admin endpoints go under `Api::Admin::` and must call `find_grade!` /
  `find_*_in_scope!` for authorization.
- Verify backend boots cleanly with `rbenv exec bundle exec rails zeitwerk:check`.

## Gotchas / environment notes

- **Do not use the system Homebrew `postgresql@18`** here — it fails to boot due to
  a broken `timescaledb` in `shared_preload_libraries`. Use the Docker Postgres.
- **zsh reserved variables:** don't use `GID`/`UID` as shell variable names in test
  scripts — they trigger "failed to change group/user ID". Use `GRD`/`USER_ID`.
- Ruby 3.4 dropped `csv` from default gems — it's an explicit gem in the Gemfile.
- Multipart CSV uploads arrive as ASCII-8BIT; the importer forces UTF-8.
- `rails db:drop` fails while a server holds DB connections — stop Puma first.
- The legacy import CSVs under `api/db/import_data/` contain personal financial
  data and are git-ignored; `api/config/master.key` and `.env` files are ignored.

## Verification quick-reference

- Legacy import total should equal the spreadsheet exactly: **net raised R$ 61.000,75**.
- Bank import of the sample extract: 25 created, ~7 unknown payers unmapped, 1
  internal investment transfer ignored; event-day payments flagged for review.
