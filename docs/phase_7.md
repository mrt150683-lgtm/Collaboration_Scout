\# docs/phases/Phase\_07.md

\# Phase 7 — Pass 2 keyword expansion (two-pass discovery)



\## Goal

Use Pass 1 results to:

\- aggregate keywords from top K repos

\- generate up to maxQueries search strings

\- run Pass 2 GitHub searches with lower stars threshold

\- hydrate + analyze new repos

\- mark provenance (pass\_number) in DB



\## Deliverables

\### 1) Keyword aggregation

From `analyses.output\_json.keywords`:

\- normalize keywords (trim, lowercase optional, de-dupe)

\- count frequency + weighted by repo final\_score

\- store aggregated run-level keywords in `keywords` with `repo\_id = NULL`



Strategy:

\- choose top K repos by final\_score (default 20)

\- produce:

&nbsp; - top M primary keywords (default 30)

&nbsp; - derived search\_queries (default 10)

Store:

\- `keywords.kind = primary|secondary|query`

\- `keywords.weight = frequency\_weighted`



\### 2) Pass 2 search params

Defaults:

\- `pass2Stars = 15` (configurable)

\- `days` same as pass1 unless overridden

\- reuse `fork:false archived:false`

\- keep `top N` manageable per query (e.g., 20–50) to avoid token/DB blowups



\### 3) Pass 2 orchestration

`src/scout/pass2.ts`

Steps:

\- `keyword\_aggregate`

\- `github\_search\_pass2` (for each generated query)

\- `hydrate\_readme` (only for new repos)

\- `llm\_repo\_analysis` (same as Phase 6)

\- record `github\_queries.pass = 2`

\- record repo provenance:

&nbsp; - `repos.last\_seen\_run\_id`

&nbsp; - `github\_queries.query\_id` links



Deduping:

\- always dedupe by `full\_name`

\- optionally skip if readme\_sha256 already exists (strong dedupe)



\### 4) Budget caps

Hard caps to prevent accidental API/LLM runaway:

\- maxQueries (default 10)

\- maxNewReposTotal (default 200)

\- maxLLMAnalysesTotal (default 200)

When cap hits:

\- stop gracefully, mark step stats with `{ capped: true, reason }`



---



\## Tests

\- keyword aggregation determinism:

&nbsp; - same analyses -> same aggregated keywords ordering

\- pass2 dedupe:

&nbsp; - if pass2 finds a repo already in pass1 -> no new readme fetch, no new analysis

\- query budget enforced:

&nbsp; - if generator produces >10 queries, only 10 executed and an audit event logged



---



\## Self-QA

Run:

1\) pass1 run (real or fixture)

2\) `pnpm scout:expand --runId X --pass2Stars 15 --maxQueries 10`



Verify DB:

\- github\_queries has pass=2 rows

\- keywords has repo\_id NULL rows for aggregated keywords

\- new repos inserted and analyzed

\- audit\_log includes cap events if triggered



---



\## Acceptance criteria

\- Pass 2 expands repo set without duplicates

\- All pass 2 artifacts are provenance-linked

\- Caps prevent accidental “token bonfire”

