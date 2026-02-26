\# docs/phases/Phase\_03.md

\# Phase 3 — Logging + audit events (always-on) + run/step orchestration skeleton



\## Goal

Make debugging painless by ensuring:

\- every command creates a `run\_id`

\- every major operation is a `run\_step`

\- logs go to:

&nbsp; - console (structured)

&nbsp; - file (rotating optional in v1)

&nbsp; - DB `audit\_log` (always-on, smaller payload)



Also add a fixture-only “dry” mode for pipeline testing without external calls.



---



\## Deliverables

\### 1) Run lifecycle utilities

Create:

\- `src/scout/run\_context.ts` (or `src/logging/context.ts`)

&nbsp; - `createRun(args) -> run\_id`

&nbsp; - `startStep(run\_id, name) -> step\_id`

&nbsp; - `finishStep(step\_id, status, stats)`

&nbsp; - `logAudit({run\_id, scope, event, ...})`



\### 2) Correlation IDs

Every log line includes:

\- `run\_id`

\- `step`

\- `module`

\- `duration\_ms` (for step completion events)



\### 3) DB audit sink

Write minimal structured audit events:

\- `event`: machine-readable

\- `message`: human-readable

\- `data\_json`: compact JSON (no blobs)



\### 4) CLI integration

\- All main commands create a run record:

&nbsp; - `runs.args\_json` includes CLI args + defaults applied

\- `doctor` does NOT create a run (keep doctor cheap)

\- Add `scout:run --dry`:

&nbsp; - creates run + steps + audit events

&nbsp; - uses fixtures instead of GitHub/LLM



---



\## Implementation steps

1\) Extend Phase 2 DAOs:

\- `RunsDao.create({ args\_json, git\_sha, config\_hash })`

\- `StepsDao.start({ run\_id, name })`

\- `StepsDao.finish({ step\_id, status, stats\_json })`

\- `AuditDao.write({ ... })`



2\) Logging

\- Console logger (pino-style):

&nbsp; - `logger.info({run\_id, step, ...}, "message")`

\- File logging optional:

&nbsp; - if implemented, rotate by size/day

&nbsp; - file contains same JSON lines



3\) Step timing

\- `started\_at` set at start

\- `finished\_at` set at end

\- `duration\_ms` computed and added to `stats\_json`



4\) Define canonical step names for later phases (stable strings):

\- `init\_run`

\- `github\_rate\_limit\_snapshot`

\- `github\_search\_pass1`

\- `hydrate\_repo\_metadata`

\- `hydrate\_readme`

\- `llm\_repo\_analysis`

\- `keyword\_aggregate`

\- `github\_search\_pass2`

\- `llm\_brief\_generate`

\- `export\_markdown`



---



\## Tests

1\) `scout:run --dry`:

\- creates exactly 1 run row

\- creates steps with status=success

\- writes at least N audit logs (e.g., >=3)



2\) Audit log redaction:

\- ensure no env tokens written

\- assert audit\_log.data\_json doesn’t include known token strings



---



\## Self-QA

Run:

\- `pnpm scout:run --dry --query "anything"`

Then query DB:

\- runs row exists

\- run\_steps reflect correct ordering and timings

\- audit\_log contains events like:

&nbsp; - `run.created`

&nbsp; - `step.started`

&nbsp; - `step.finished`



---



\## Acceptance criteria

\- A failed step marks status=failed and the command exits non-zero

\- Logs are usable without reading source code

\- Dry mode is deterministic and does not touch network

