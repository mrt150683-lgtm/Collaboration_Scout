# Logging Guide

## Overview

All logs are structured JSON lines. Two sinks:
1. **Console** (stdout for info/debug, stderr for error/fatal)
2. **DB `audit_log`** (always-on, compact payload, searchable)

## Required Fields

Each log event includes (as applicable):

| Field | Type | Description |
|-------|------|-------------|
| `timestamp` | ISO 8601 string | When the event occurred |
| `level` | string | `trace`, `debug`, `info`, `warn`, `error`, `fatal` |
| `message` | string | Human-readable description |
| `run_id` | string or null | Correlation ID for the current run |
| `step` | string | Stable step name (e.g., `github_search_pass1`) |
| `module` | string | Source module (e.g., `github.client`) |
| `pass` | number | Discovery pass (1 or 2) |
| `repo_full_name` | string | When repo-scoped |
| `request_id` | string | When HTTP-scoped |
| `duration_ms` | number | For step completion events |

## Canonical Step Names

- `init_run`
- `github_rate_limit_snapshot`
- `github_search_pass1`
- `hydrate_repo_metadata`
- `hydrate_readme`
- `llm_repo_analysis`
- `keyword_aggregate`
- `github_search_pass2`
- `llm_brief_generate`
- `export_markdown`

## Canonical Audit Events

- `run.created`
- `step.started`
- `step.finished`
- `step.failed`
- `github.throttle` — rate limit hit; data: `{ bucket, wait_ms, reason, status, reset_at }`
- `github.rate_limit_snapshot`
- `repo.hydrate.started`
- `repo.readme.fetched`
- `repo.readme.missing`
- `repo.hydrate.failed`
- `llm.output.invalid_json`

## Secret Redaction

Secrets are redacted before any log output by key-name pattern matching. See `docs/security.md`.
