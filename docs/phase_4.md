\# docs/phases/Phase\_04.md

\# Phase 4 — GitHub client + caching + throttling (REST v1)



\## Goal

Implement a safe GitHub REST client with:

\- authenticated requests

\- rate limit awareness

\- token-bucket throttling (separate buckets: search vs core)

\- conditional requests (ETag/Last-Modified)

\- persistent HTTP cache table (`http\_cache`)

\- initial rate limit snapshot stored per run



\## Why this matters

GitHub’s `GET /rate\_limit` endpoint does not count against your \*\*primary\*\* REST rate limit. :contentReference\[oaicite:0]{index=0}  

The README endpoint supports a “raw” media type. :contentReference\[oaicite:1]{index=1}  

So we can be polite and efficient.



---



\## Deliverables

\### 1) DB migration: add http\_cache (+ github rate snapshot storage)

Add table:

\- `http\_cache(cache\_key TEXT PK, url TEXT, method TEXT, status INTEGER, etag TEXT, last\_modified TEXT, body\_blob BLOB, fetched\_at TEXT, expires\_at TEXT)`

Optional small table for rate limit snapshots:

\- `github\_rate\_limits(run\_id TEXT, captured\_at TEXT, payload\_json TEXT)`



\### 2) GitHub client module

`src/github/client.ts`:

\- base URL `https://api.github.com`

\- headers:

&nbsp; - `Authorization: Bearer <token>` (or `token <token>` depending on your choice)

&nbsp; - `Accept: application/vnd.github+json`

&nbsp; - `X-GitHub-Api-Version: 2022-11-28` (or latest you decide)

\- request wrapper:

&nbsp; - consult cache -> conditional request -> store result



\### 3) Throttling

Implement token bucket:

\- bucket `search`: max 30/min (configurable)

\- bucket `core`: default 5000/hr or rely on headers

Also implement “secondary limit” backoff:

\- on 403/429, respect `Retry-After` when present

\- else use `X-RateLimit-Reset` epoch seconds to sleep until reset



Persist throttle events to `audit\_log` with:

\- `event: github.throttle`

\- `data\_json: { bucket, wait\_ms, reason, status, reset\_at }`



\### 4) Endpoints you must support (Phase 4 only)

\- `GET /rate\_limit`

\- “dumb” GET passthrough used by mocks/tests



(Actual search/readme endpoints used in Phase 5.)



---



\## Implementation steps

1\) Cache key strategy

Cache key must include:

\- method

\- url

\- accept header (media type matters)

\- auth scope doesn’t need to be included (same user)



Example:

`sha256("${method} ${url} accept=${accept}")`



2\) Conditional requests

If cache row has etag:

\- set `If-None-Match: <etag>`

If cache row has last\_modified:

\- set `If-Modified-Since: <last\_modified>`

On `304 Not Modified`:

\- return cached body, update fetched\_at



3\) Store response metadata

Store:

\- status

\- etag / last\_modified

\- body\_blob

\- fetched\_at

\- expires\_at (can be null; GitHub rarely sets caching for API responses)



---



\## Tests (mocked HTTP)

Use a fetch-interceptor suitable for Node fetch (examples):

\- MSW (node)

\- Undici MockAgent



Test cases:

1\) First request 200 with ETag stored

2\) Second request sends If-None-Match and receives 304

&nbsp;  - body returned equals cached body

&nbsp;  - cache fetched\_at updated

3\) Rate limit handling:

&nbsp;  - simulate 403 with headers `X-RateLimit-Reset`

&nbsp;  - client sleeps (mock timers) and logs `github.throttle`



---



\## Self-QA

Run:

\- `pnpm scout:run --dry` (still dry)

\- plus a new `github:ping` dev command (optional) that calls `/rate\_limit`



Expected:

\- DB contains `github\_rate\_limits` snapshot for run

\- audit log includes `github.rate\_limit\_snapshot`



---



\## Acceptance criteria

\- Cache + conditional requests work

\- Throttling events are persisted

\- No secrets are logged

