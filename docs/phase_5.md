\# docs/phases/Phase\_05.md

\# Phase 5 — Pass 1 scout pipeline (search → hydrate → store)



\## Goal

Implement Pass 1:

\- build GitHub search query string with qualifiers

\- fetch top N repos

\- hydrate README (raw) + minimal metadata

\- store provenance in DB: queries, repos, readmes linked to run/pass



\## Deliverables

\### 1) DB migrations: add github\_queries, repos, readmes

Add tables (as in your master plan):

\- `github\_queries(query\_id TEXT PK, run\_id TEXT, pass INTEGER, query\_string TEXT, params\_json TEXT, created\_at TEXT)`

\- `repos(repo\_id TEXT PK, full\_name TEXT UNIQUE, url TEXT, stars INTEGER, forks INTEGER, topics\_json TEXT, language TEXT, license TEXT, pushed\_at TEXT, archived INTEGER, fork INTEGER, last\_seen\_run\_id TEXT)`

\- `readmes(readme\_id TEXT PK, repo\_id TEXT, sha256 TEXT, content\_text TEXT, fetched\_at TEXT, etag TEXT, source\_url TEXT)`



Indices:

\- `repos(full\_name)`

\- `readmes(repo\_id)`

\- `github\_queries(run\_id, pass)`



\### 2) Query builder

`src/github/query\_builder.ts`

Inputs:

\- `query` (user text)

\- `days` (default 180)

\- `stars` (default 50)

\- `archived:false`

\- `fork:false` (default exclude forks)

\- `pushed:>=YYYY-MM-DD`

\- optionally `language:TypeScript` etc.

\- optionally `in:readme`



Note: `in:readme` is a real-world qualifier used in repo searches; keep it configurable in case GitHub changes behavior. :contentReference\[oaicite:2]{index=2}



\### 3) GitHub endpoints

Implement in `src/github/api.ts`:

\- `searchRepos({ q, per\_page, page, sort, order })`

\- `getReadmeRaw({ owner, repo })`

&nbsp; - use README endpoint raw media type :contentReference\[oaicite:3]{index=3}



\### 4) Orchestrator step graph (Pass 1 only)

`src/scout/pass1.ts`

Steps:

1\) `github\_rate\_limit\_snapshot` (Phase 4)

2\) `github\_search\_pass1`

3\) `hydrate\_readme` (iterate repos; throttle + cache)

4\) `store\_results`



Each repo hydration writes audit events:

\- `repo.hydrate.started`

\- `repo.readme.fetched` (include sha256, bytes)

\- `repo.hydrate.failed` (include status/error)



\### 5) Deduping

Deduplicate by:

\- `full\_name` unique constraint

\- optional “readme sha” dedupe later; not required in pass 1



---



\## Tests (mocked GitHub)

Fixtures:

\- `src/tests/fixtures/github/search\_repos\_page1.json`

\- `src/tests/fixtures/github/readme\_raw\_\*.txt`



Integration test:

\- Run pass1 with `--top 10`

\- Mock GitHub search returns 10 repos

\- Mock readme endpoint returns content + ETag

Assertions:

\- 1 github\_queries row (pass=1)

\- 10 repos inserted/updated

\- 10 readmes inserted (sha256 computed)



Edge tests:

\- missing README: readme endpoint 404

&nbsp; - store repo row

&nbsp; - store audit event `repo.readme.missing`

&nbsp; - analysis skipped later



---



\## Self-QA

Run:

\- `pnpm scout:run --query "vector database" --top 10`

Expected DB artifacts:

\- runs + steps success

\- github\_queries pass=1 created

\- repos count == 10

\- readmes count <= 10 (if some missing)

Expected logs:

\- throttle behavior visible but not spammy



---



\## Acceptance criteria

\- Pass 1 completes with mocked GitHub

\- Real GitHub run works with a valid token

\- Provenance is complete: run\_id + pass + rank preserved

