# qa.md — Collaboration Scout QA Playbook (Backend-First, Audit-Grade)

This document is the operator/tester playbook for verifying Collaboration Scout works end-to-end **without guesswork**. It assumes:
- CLI-first execution
- SQLite local DB
- External calls (GitHub/OpenRouter) can be mocked for deterministic tests

---

## 0) Quality gates (must pass before merge)
Required checks for any PR:
- `pnpm lint`
- `pnpm typecheck`
- `pnpm test`

Network-facing changes must also include:
- an integration test covering rate limiting + caching behavior
- a run bundle export check (structure + no secrets)

---

## 1) Quickstart verification (fresh machine)
### 1.1 Install + baseline
```bash
pnpm install
pnpm lint
pnpm typecheck
pnpm test
pnpm doctor --json

Expected:

all commands exit 0

doctor prints stable JSON

doctor must NOT print tokens (ever)

1.2 Environment sanity

Minimum env variables (example):

CS_DB_PATH=./data/collaboration-scout.db

CS_LOG_LEVEL=info

GITHUB_TOKEN=... (optional for mocked runs; required for real)

OPENROUTER_API_KEY=... (optional for mocked runs; required for real)

Never commit .env.

2) DB initialization & schema QA
2.1 Migrations apply cleanly
pnpm db:migrate
pnpm doctor --json

Expected:

doctor reports DB ok=true

schema version matches latest migration

DB file exists at CS_DB_PATH

2.2 Migration upgrade test (required in CI)

Integration test must:

create DB at version N-1 (fixtures or applying subset of migrations)

run db:migrate

assert schema_version == N

assert foreign keys enabled

3) Logging & audit QA (Phase 3+)
3.1 Dry run creates audit artifacts (no network)
pnpm scout:run --dry --query "anything" --top 10

Expected DB artifacts:

runs: +1 row

run_steps: multiple rows (init + pipeline stages)

audit_log: multiple rows (run created, step start/finish, etc.)

Expected log qualities:

each log line has run_id

step start/finish events exist

failures (if any) set step status = failed and exit non-zero

3.2 No secrets in logs

Hard requirement:

console logs, file logs, and audit_log must not contain raw token strings

Test requirement:

include a test that sets GITHUB_TOKEN="SENTINEL_TOKEN" and asserts that value does not appear in any logged output.

4) GitHub client QA (Phase 4+)
4.1 Rate-limit snapshot stored per run

If a github:ping or the run pipeline calls /rate_limit:

DB must store a snapshot row (table name you chose, e.g. github_rate_limits)

audit_log includes github.rate_limit_snapshot

4.2 HTTP cache / conditional requests

Run the integration test suite that mocks:

first call returns 200 with ETag

second call returns 304

Assertions:

second call returns cached body

cache row fetched_at updates

audit_log includes a cache hit/miss event (recommended)

4.3 Throttle behavior

Mock a 403/429 response with headers:

Retry-After OR X-RateLimit-Reset

Assertions:

client waits (use fake timers)

audit event recorded: github.throttle

run does not spin infinitely (bounded retry)

5) Pass 1 pipeline QA (Phase 5+)
5.1 Mocked Pass 1 (deterministic)
pnpm scout:run --dry --query "vector database" --top 10

Expected (mock mode):

github_queries pass=1: +1

repos: == topN inserted/updated

readmes: <= topN (404 allowed for missing README, but must be recorded)

Required audit events per repo (minimum):

repo.hydrate.started

either repo.readme.fetched OR repo.readme.missing OR repo.hydrate.failed

5.2 Real Pass 1 smoke test (small!)

Only for manual QA (not CI), with real token:

pnpm scout:run --query "vector database" --top 5 --days 180 --stars 50

Expected:

completes without rate-limit meltdown

readmes stored with sha256

steps show realistic durations

6) LLM analysis QA (Phase 6+)
6.1 Schema validation is hard fail

Integration test must cover:

valid JSON output → stored analysis row

malformed JSON output → retries then FAIL

run_step status=failed

audit event llm.output.invalid_json (or equivalent)

command exit non-zero

6.2 Deterministic scoring

Unit test must confirm:

given LLM scores + scoring_policy_vX weights → exact final score

stable rounding strategy (define it once, test it)

6.3 Prompt + model provenance

For each analysis row, verify stored fields exist:

model

prompt_id

prompt_version

input_snapshot_json (or a hash + reconstruction strategy)

output_json

llm_scores_json

final_score

reasons_json

7) Pass 2 expansion QA (Phase 7+)
7.1 Keyword aggregation determinism

Unit test:

same set of analyses → same aggregated keywords ordering + weights

7.2 Query budget caps

Integration test:

generator produces > maxQueries

only maxQueries executed

audit event recorded: scout.pass2.capped (or equivalent)

step stats_json includes { capped: true, reason }

7.3 Deduping

Integration test:

pass 2 returns repos already seen in pass 1

no duplicate repo rows created

optional: no repeated readme fetch if sha256 matches

8) Brief generation & export QA (Phase 8+)
8.1 Brief thresholding

Run (mocked):

pnpm briefs:generate --runId <RUN_ID> --minScore 0.75 --maxBriefs 20

Expected:

all briefs stored in DB

any brief below threshold has status rejected_by_threshold

any above threshold has status shortlisted

8.2 Export structure
pnpm briefs:export --runId <RUN_ID> --out ./out

Expected filesystem:

./out/run_<RUN_ID>/index.md

./out/run_<RUN_ID>/briefs/<brief_id>.md

./out/run_<RUN_ID>/briefs/<brief_id>_outreach.md

Content requirements:

“Manual review required” banner present

Outreach drafts do NOT claim actions not taken

No secrets in any exported file

9) Replay / rerun / pruning QA (Phase 9+)
9.1 Replay is strictly offline
pnpm debug:replay --runId <RUN_ID>

Hard requirements:

no GitHub calls

no OpenRouter calls

deterministic outputs match stored baselines (hash compare recommended)

9.2 Rerun LLM keeps history
pnpm debug:rerun-llm --analysisId <ANALYSIS_ID> --promptVersion v2

Expected:

new analyses row exists

old analyses row remains

linkage recorded (either supersedes_analysis_id or equivalent mapping)

9.3 Pruning commands
pnpm cache:prune --days 30
pnpm logs:prune --days 90
pnpm db:vacuum

Expected:

old rows removed (only those older than cutoff)

DB remains consistent

vacuum completes without errors

10) Run bundle QA (recommended feature)

If run bundles exist:

export contains: args, queries, repo snapshots, readme hashes, analyses JSON, briefs JSON/MD

export excludes: tokens, auth headers, .env

include a MANUAL_REVIEW_REQUIRED.md or banner in index.md

Test:

create a bundle in mocked mode and scan for sentinel tokens:

SENTINEL_TOKEN must not appear

11) Troubleshooting (fast diagnosis)
Common failure: rate limiting

Symptoms:

repeated 403/429

long pauses

Checks:

confirm bucket caps

confirm github.throttle events written

inspect stored X-RateLimit-Reset times in audit logs

Common failure: invalid LLM JSON

Symptoms:

retries then fail

Checks:

verify prompt includes strict JSON-only instruction

verify schema matches expected fields

inspect stored raw response (if you store it) and compare to schema

Common failure: non-determinism

Symptoms:

golden tests flaky

replay mismatch

Checks:

sort all collections before hashing

inject a clock into code

ensure stable floating rounding rules

12) Definition of Done (v1)

A build is “done” when:

full mocked end-to-end pipeline passes in CI

at least one small real run (top=5) works manually without rate-limit abuse

replay works offline and matches deterministic outputs

exports are clean and bannered

no secrets ever appear in logs/DB/exports