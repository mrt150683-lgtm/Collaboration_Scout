# docs/phases/Phase_02.md
# Phase 2 — SQLite storage + migrations

## Goal
Introduce an audit-friendly SQLite DB with:
- migrations
- a DB access layer
- core tables: `meta`, `runs`, `run_steps`, `audit_log`
- CLI commands: `db:migrate`, `db:status` (optional), `doctor` now validates schema

## Key constraints
- Local-first, single SQLite file
- No secrets stored in DB
- Foreign keys ON
- Migrations are immutable and ordered

---

## Deliverables
### 1) DB driver + wrapper
Pick one:
- `better-sqlite3` (fast, sync) + minimal wrapper
- OR `sqlite`/`sqlite3` async wrapper

Minimum DB wrapper capabilities:
- open connection with pragmas:
  - `PRAGMA foreign_keys = ON;`
  - `PRAGMA journal_mode = WAL;`
  - `PRAGMA synchronous = NORMAL;`
- `transaction(fn)` helper
- `exec(sql)` and `all/get/run` helpers

### 2) Migration system
- Create folder: `src/db/migrations/`
- Migrations named like:
  - `0001_init.sql`
  - `0002_indexes.sql`
- Create table `meta` to store schema version and app version.

### 3) Initial schema (v1 subset)
Create tables (subset; more later):
- `meta(schema_version INTEGER NOT NULL, app_version TEXT, created_at TEXT)`
- `runs(run_id TEXT PK, created_at TEXT, args_json TEXT, git_sha TEXT, config_hash TEXT)`
- `run_steps(step_id TEXT PK, run_id TEXT FK, name TEXT, started_at TEXT, finished_at TEXT, status TEXT, stats_json TEXT)`
- `audit_log(ts TEXT, level TEXT, run_id TEXT, scope TEXT, event TEXT, message TEXT, data_json TEXT)`

Add:
- indices on `(run_id)` where needed
- status constraints (enforced in code in v1; optional CHECK constraints)

### 4) Commands
- `pnpm db:migrate` applies migrations
- `pnpm db:vacuum` (stub ok; full in Phase 9)
- Update `doctor`:
  - if DB file missing: report “not initialized yet”
  - if present: validate schema version in `meta`

---

## Implementation steps
1) `src/db/index.ts`
- `openDb({ path })`
- apply pragmas
- `close()`

2) `src/db/migrate.ts`
- read migration files
- keep `schema_migrations` table:
  - `id TEXT PRIMARY KEY, applied_at TEXT`
- apply in order

3) `src/db/dao/*` (optional now)
- `RunsDao.createRun(...)`
- `StepsDao.createStep(...)`
- `AuditDao.write(...)`

4) Add `config_hash`
- compute SHA256 of normalized config (sorted keys JSON)
- store in `runs`

---

## Tests
### Unit/integration (DB)
- Create temp DB path in tests
- Run migrations
- Insert run + step + audit row
- Read back and assert:
  - foreign keys enforced
  - schema_version is correct
  - WAL mode is set (optional check)

---

## Self-QA
Run:
- `pnpm db:migrate`
- `pnpm doctor --json`

Expected:
- doctor shows DB ok=true
- schema_version matches your migration head

Also verify:
- deleting DB file makes doctor say “not initialized yet” (not a crash)

---

## Acceptance criteria
- Migrations apply cleanly on fresh DB
- DB schema version tracked
- Minimal DAOs exist OR DB wrapper is clean enough to use directly