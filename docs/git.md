\# git.md — Collaboration Scout Git Workflow



\## Branching model

\- `main` — always stable, releasable.

\- `dev` — integration branch for completed features.

\- `feature/<slug>` — short-lived feature branches.

\- `fix/<slug>` — hotfix branches (from `main` if urgent, else from `dev`).

\- `chore/<slug>` — tooling / refactors / docs.



\### Rules

\- Never commit directly to `main`.

\- `main` only advances via PR merge.

\- `dev` merges into `main` only for releases.

\- Keep feature branches small and short-lived.



---



\## Commit conventions (required)

Use \*\*Conventional Commits\*\*:

\- `feat: ...` (new feature)

\- `fix: ...` (bug fix)

\- `refactor: ...`

\- `perf: ...`

\- `test: ...`

\- `docs: ...`

\- `chore: ...`

\- `build: ...`

\- `ci: ...`



Examples:

\- `feat: add github http cache with etag`

\- `fix: handle 304 not modified for readme fetch`

\- `test: add golden fixtures for repo analysis output`



\### Commit hygiene

\- One logical change per commit where practical.

\- Include context in the body if the subject isn’t self-evident.

\- Never commit secrets, tokens, `.env`, or real run bundles containing credentials.



---



\## PR policy

\### Required checks before merge

\- `pnpm lint`

\- `pnpm test`

\- `pnpm typecheck`

\- Integration tests (mocked external calls) must pass for any network-related change.



\### PR description must include

\- What changed (short)

\- Why (one paragraph)

\- How to test (exact commands)

\- Risk notes (rate limits, schema changes, prompt changes)



\### Review checklist

\- DB migrations present when schema changes

\- Prompt versions bumped when prompts change

\- Deterministic scoring unchanged unless intentionally version-bumped

\- No accidental GitHub write endpoints introduced

\- Logging fields + audit events preserved



---



\## Versioning + releases

Use \*\*SemVer\*\*:

\- `MAJOR` — breaking schema/CLI changes, incompatible artifacts

\- `MINOR` — new functionality, backward compatible

\- `PATCH` — bugfixes only



\### Tagging

\- Tag releases on `main`: `vX.Y.Z`

\- The tag commit must have:

&nbsp; - updated `meta.app\_version` expectations (if applicable)

&nbsp; - migrations applied cleanly on a fresh DB

&nbsp; - any prompt version bumps committed



\### Release checklist

1\) Merge `dev` → `main`

2\) Run:

&nbsp;  - `pnpm test \&\& pnpm lint \&\& pnpm typecheck`

&nbsp;  - `pnpm db:migrate` on fresh DB

&nbsp;  - a small mocked end-to-end run

3\) Update `CHANGELOG.md` (if used)

4\) Tag: `git tag vX.Y.Z \&\& git push --tags`



---



\## Database migrations (strict)

\- Migrations are \*\*append-only\*\*.

\- Never edit a migration that has shipped.

\- Use sequential filenames: `0001\_\*.sql`, `0002\_\*.sql`, etc.

\- Any change to tables/indices must come with:

&nbsp; - migration file

&nbsp; - test proving migration applies on empty DB

&nbsp; - optional test proving upgrade from previous version



---



\## Prompt versioning (strict)

\- Prompts live in `prompts/\*.md`

\- Any prompt content change requires a \*\*prompt\_version bump\*\*.

\- Stored outputs must always include:

&nbsp; - `prompt\_id`

&nbsp; - `prompt\_version`

&nbsp; - `model`

&nbsp; - `input\_snapshot\_hash` (or full snapshot JSON)

\- Never “silently” change prompt behavior without bumping version.



---



\## Lockfiles + tooling

\- `pnpm-lock.yaml` must be committed.

\- Node version is pinned (recommend `.nvmrc` or `package.json#engines`).

\- CI must use the same pnpm + node versions as local dev.



---



\## Repository rules of thumb

\- No new external dependency unless justified (security + maintenance cost).

\- Prefer small, well-tested modules over cleverness.

\- Deterministic outputs must stay deterministic (order, sorting, hashing).

