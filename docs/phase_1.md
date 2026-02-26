\# docs/phases/Phase\_01.md

\# Phase 1 — Repo skeleton + standards (CLI-first, audit-grade)



\## Goal

Establish a repeatable backend skeleton with:

\- TypeScript + Node + pnpm

\- CLI entrypoint(s)

\- Config loading + validation (Zod) with secret redaction

\- Test/lint/format tooling

\- A stubbed `doctor` command that proves the plumbing works



\## Non-goals

\- DB schema/migrations (Phase 2)

\- GitHub/OpenRouter networking (later phases)



---



\## Deliverables

\### 1) Repository layout

Create this structure (minimum):



.

├─ package.json

├─ pnpm-lock.yaml

├─ tsconfig.json

├─ src/

│ ├─ cli/

│ │ ├─ index.ts

│ │ └─ commands/

│ │ └─ doctor.ts

│ ├─ config/

│ │ ├─ schema.ts

│ │ ├─ load.ts

│ │ └─ redact.ts

│ ├─ logging/

│ │ ├─ logger.ts

│ │ └─ context.ts

│ └─ index.ts

├─ docs/

│ ├─ qa.md

│ ├─ logging.md

│ └─ security.md

└─ src/tests/

└─ doctor.test.ts





\### 2) Tooling

\- TS compile: `tsc --noEmit` (typecheck)

\- Tests: `vitest`

\- Lint: ESLint

\- Format: Prettier

\- Scripts: `pnpm test`, `pnpm lint`, `pnpm format`, `pnpm doctor`



\### 3) CLI

\- Use `commander` (or `yargs`) for stable CLI parsing.

\- `scout` root command + `doctor` subcommand.

\- Ensure CLI returns non-zero exit codes on failure.



\### 4) Config

Support:

\- `.env` (via dotenv) + env vars

\- optional `config.json` (later can be added)

\- Zod validation in `src/config/schema.ts`



Minimum env keys for Phase 1:

\- `CS\_DB\_PATH` (optional for now; doctor can report “not initialized yet”)

\- `CS\_LOG\_LEVEL` (default `info`)

\- `GITHUB\_TOKEN` (optional in Phase 1; doctor reports missing but not fatal)

\- `OPENROUTER\_API\_KEY` (optional in Phase 1; doctor reports missing but not fatal)



Secret redaction rules:

\- Never log token values

\- Replace with `\*\*\*REDACTED\*\*\*`

\- Redact by key name match: `token`, `key`, `secret`, `password`, `authorization`



---



\## Implementation checklist

\### A) CLI wiring

\- `src/cli/index.ts` exports `runCli(argv)`

\- `src/index.ts` calls `runCli(process.argv)`

\- `doctor` command prints a JSON object by default:

&nbsp; - `{ ok: boolean, checks: { name, ok, message }\[] }`

\- Add `--json` and `--verbose` flags (even if minimal)



\### B) Logging baseline

\- Create `src/logging/logger.ts`:

&nbsp; - structured JSON logs

&nbsp; - log level from config

\- Create a `RunContext` object (even if run\_id is `null` in Phase 1)

&nbsp; - fields: `run\_id`, `step`, `module`, `request\_id`

\- Ensure logs can include context without global mutable state (use async-local-storage later; keep it simple now).



\### C) Docs stubs

Create:

\- `docs/security.md`: tokens never persisted; redaction rules; no outbound posting to GitHub

\- `docs/logging.md`: required log fields (future-proof)

\- `docs/qa.md`: how to run tests + doctor + expected outputs



---



\## Tests

\### Unit tests (Vitest)

1\) `doctor` runs with empty env:

\- exits 0

\- returns ok=true (because Phase 1 only validates tooling paths)

\- includes checks indicating missing tokens but “non-fatal in Phase 1”



2\) redaction:

\- given an object containing `GITHUB\_TOKEN: "abc"`

\- `redactSecrets(obj)` masks it



---



\## Self-QA (model-running-this-phase)

Run:

\- `pnpm install`

\- `pnpm test`

\- `pnpm lint`

\- `pnpm doctor --json`



Expected:

\- All commands succeed

\- `doctor` output contains:

&nbsp; - `config` check ok=true

&nbsp; - `db` check ok=false with message “DB not initialized yet”

&nbsp; - `github\_auth` ok=false (non-fatal)

&nbsp; - `openrouter\_auth` ok=false (non-fatal)



---



\## Acceptance criteria

\- Green: tests/lint/typecheck

\- `doctor` command exists, stable output, non-zero only on internal errors

\- Redaction is proven by tests

