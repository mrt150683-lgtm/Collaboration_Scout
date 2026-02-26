\# docs/phases/Phase\_09.md

\# Phase 9 — Hardening: replay, pruning, CI



\## Goal

Make the system operationally sane:

\- debug replay without network

\- rerun LLM analyses with prompt/model changes and keep history

\- pruning commands for cache/logs

\- CI checks (optional but recommended)



\## Deliverables

\### 1) Replay mode (no network)

`debug:replay --runId X`

Must:

\- refuse to run if network calls attempted

\- recompute:

&nbsp; - deterministic scoring from stored llm\_scores\_json + scoring\_policy

&nbsp; - candidate grouping

&nbsp; - brief deterministic scoring + thresholding

Should NOT:

\- call GitHub

\- call OpenRouter

Store output:

\- either write a “replay report” to disk or store a new `run\_steps` entry tagged `replay`



Acceptance test:

\- replay produces identical deterministic outputs for same stored inputs



\### 2) Rerun LLM (controlled)

`debug:rerun-llm --analysisId Y \[--promptVersion v2] \[--model ...]`

Rules:

\- fetch stored input snapshot + readme hash

\- run OpenRouter again

\- store a NEW analyses row linked to same repo/run (or a new run, your choice)

\- mark it with a `supersedes\_analysis\_id` field (add column if desired)



\### 3) Pruning commands

\- `cache:prune --days 30`

&nbsp; - delete from http\_cache where fetched\_at < cutoff

\- `logs:prune --days 90`

&nbsp; - delete audit\_log older than cutoff

\- `runs:archive --runId X`

&nbsp; - export run bundle zip

&nbsp; - optionally delete big blobs (readme content) after export (configurable)

\- `db:vacuum`

&nbsp; - run `VACUUM` (or `VACUUM INTO` to a backup file)



\### 4) CI

GitHub Actions workflow:

\- node setup

\- pnpm install

\- lint

\- typecheck

\- test

Optionally run a “mocked full run” integration test.



\### 5) Final QA playbook

Update `docs/qa.md` with:

\- “happy path” commands

\- expected DB row counts

\- how to inspect a run bundle

\- how to diagnose rate limiting



---



\## Tests

\- replay determinism:

&nbsp; - compute hash of “deterministic outputs” and compare to stored baseline

\- prune correctness:

&nbsp; - insert old rows, run prune, assert deleted

\- rerun-llm:

&nbsp; - new analyses row exists, old remains, linkage stored



---



\## Self-QA

1\) Run a real small run (top=5)

2\) Export run bundle

3\) Run replay and confirm deterministic results unchanged

4\) Prune cache/logs in a dev DB and confirm no crashes



---



\## Acceptance criteria

\- You can debug a run from DB alone

\- You can evolve prompts without losing history

\- Maintenance commands prevent DB bloat

