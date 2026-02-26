\# docs/phases/Phase\_08.md

\# Phase 8 — Brief generation + export (ranked collaboration concepts)



\## Goal

Generate ranked collaboration briefs that:

\- involve 2–4 repos

\- are explainable (why each repo fits)

\- include manual-only outreach drafts (no auto posting)

\- are exported as Markdown bundles



\## Deliverables

\### 1) DB migration: briefs table

Add:

\- `briefs(brief\_id TEXT PK, run\_id TEXT, score REAL, repo\_ids\_json TEXT, brief\_json TEXT, brief\_md TEXT, outreach\_md TEXT, status TEXT, created\_at TEXT)`



Status enum (code-enforced):

\- `draft | shortlisted | approved | rejected | rejected\_by\_threshold`



\### 2) Candidate selection rules

From `analyses`:

\- require `final\_repo\_score >= repo\_min` (default 0.60)

\- require `collaboration\_potential >= 0.65` (from LLM scores)

\- exclude missing readme or missing license if you choose (configurable)



\### 3) Grouping heuristics (deterministic pre-LLM)

Generate candidate groups using:

\- topic overlap:

&nbsp; - shared language OR shared topics OR overlapping keywords

\- complementary “integration\_surface”

&nbsp; - LLM-produced field, but you can treat it as tags

Hard caps:

\- max candidate combos attempted (e.g., 200)

\- max briefs stored (e.g., 50)



\### 4) Brief generation (LLM + schema)

Use `prompts/brief\_generate\_v1.md` with rules:

\- no outreach automation

\- outreach text must be polite, short, zero-pressure

Validate JSON output against `BriefOutput\_v1` schema.



Compute `brief\_score` deterministically:

\- weighted from:

&nbsp; - average final\_repo\_score of repos

&nbsp; - average collab\_potential

&nbsp; - overlap/complement signals

Store LLM’s “reasons” separately from deterministic score.



Thresholding:

\- keep all briefs in DB

\- mark `< minScore` as `rejected\_by\_threshold`

\- mark `>= minScore` as `shortlisted`



\### 5) Markdown export

`briefs:export --runId X --out ./out`

Write:

\- `out/run\_<id>/index.md`

\- `out/run\_<id>/briefs/<brief\_id>.md`

\- `out/run\_<id>/briefs/<brief\_id>\_outreach.md`

Include banner:

\- “Manual review required. This tool does not post to GitHub.”



Optionally add a “run bundle” zip:

\- args + queries + repo snapshots + hashes + analyses JSON + briefs JSON/MD



---



\## Tests

\- grouping determinism:

&nbsp; - given same analyses -> same candidate groups order

\- threshold behavior:

&nbsp; - brief\_score < 0.75 => status `rejected\_by\_threshold`

\- export structure:

&nbsp; - files created exactly where expected

&nbsp; - index links to briefs



Mock brief LLM:

\- valid JSON -> stored

\- invalid -> fail clearly, step=failed



---



\## Self-QA

Run:

\- `pnpm briefs:generate --runId X --minScore 0.75 --maxBriefs 20`

\- `pnpm briefs:export --runId X --out ./out`



Verify:

\- DB briefs exist with statuses

\- exported md readable and references repos

\- outreach drafts contain no “I already did X on your repo” claims (avoid creep)



---



\## Acceptance criteria

\- Briefs are explainable + reproducible

\- Export bundle is shareable for debugging

\- No automated outreach exists anywhere

