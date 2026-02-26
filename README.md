# Collaboration Scout

**Why this exists:** I wanted a way to find GitHub projects worth building with — not massive frameworks that already have everything figured out, but active, focused repos in a similar space that could genuinely benefit from combining efforts. The kind of collaborations that actually happen when two maintainers realise they're building complementary things.

This tool automates the discovery part. You describe your space, it finds candidates, scores them, and generates collaboration briefs — concrete write-ups of what a joint build could look like. Everything stays local and nothing gets sent anywhere.

---

## Core idea

You point it at a topic (or your own repo), it:

1. Searches GitHub for active repos in that space — filtered to projects small enough to still care about collaborators (star limits keep out the giant established projects that don't need you)
2. Reads each repo's README and metadata, analyzes it with an LLM, and scores it deterministically (not just vibes)
3. Runs a second pass using keywords extracted from the best results to find adjacent projects you wouldn't have searched for directly
4. Pairs up the best candidates and generates ranked collaboration briefs — what to build together, why it makes sense, and a draft outreach message for you to review and send yourself

Everything is stored in a local SQLite database. Runs are reproducible. Scores have reasons. Nothing is automated beyond discovery and drafting.

---

## Using your own repo as the starting point

The `--query` flag accepts any GitHub search string, so you can seed it from your own project's domain:

```bash
# Search around your project's space
pnpm scout:run --query "typescript agent framework" --stars 10 --max-stars 3000

# Or use your repo's topics/language directly
pnpm scout:run --query "vector store embedding typescript" --stars 10 --max-stars 3000
```

The star limits matter here: `--stars 10` picks up active early-stage projects, `--max-stars 3000` excludes the projects that already have a full team and a roadmap — they're not looking for the same kind of collaboration.

### One-command workflow (Windows)

```powershell
.\run-production-search.ps1 -Query "your topic here" -Stars 10 -MaxStars 3000
```

This runs the full pipeline: search → analyze → generate briefs → export Markdown.

---

## Setup

**Prereqs:** Node.js, pnpm, a GitHub token (read-only), an OpenRouter API key.

```bash
pnpm install
```

**`.env`:**
```
GITHUB_TOKEN=...
OPENROUTER_API_KEY=...
CS_DB_PATH=./data/collaboration_scout.sqlite
CS_LOG_LEVEL=info
```

```bash
pnpm db:migrate       # initialize the database
pnpm doctor --json    # verify everything is connected
```

---

## Key commands

```bash
# Full pipeline (individual steps)
pnpm scout:run --query "rag framework" --stars 10 --max-stars 3000 --top 50
pnpm briefs:generate --run-id <RUN_ID> --min-score 0.65 --max-briefs 20
pnpm briefs:export --run-id <RUN_ID> --out ./output

# Database maintenance
pnpm db:migrate
```

**PowerShell helpers (Windows):**
```powershell
# Full end-to-end run
.\run-production-search.ps1 -Query "topic" -Stars 10 -MaxStars 3000

# Remove high-star repos already in the database
.\purge-high-stars.ps1 -MaxStars 3000 -DryRun   # preview
.\purge-high-stars.ps1 -MaxStars 3000             # apply
```

---

## Star limits: why they matter

Big projects (10k+ stars) have dedicated teams, established roadmaps, and aren't looking for the kind of collaboration this tool is designed to surface. The sweet spot is roughly 10–3000 stars: active enough to have traction, small enough that the maintainer is still making real decisions about direction.

`--stars 10` (minimum) filters out abandoned or toy projects.
`--max-stars 3000` (maximum) filters out projects that already have full visibility.

Adjust to taste — if you're in a space where 5k-star projects are still small teams, raise it.

---

## Guardrails

- **No automated outreach.** The tool generates draft messages. You read them, edit them, send them yourself (or don't).
- **Local-first.** All data stays on your machine. No cloud sync, no telemetry.
- **Reproducible.** Prompt versions, model IDs, README hashes, and scoring weights are all stored so any run can be re-examined.
- **Explainable scores.** Every score has stored reasons and evidence quotes from the README.

---

## Contributing

Useful directions:

- Better grouping heuristics (smarter 2–4 repo combinations)
- Better scoring policies (still deterministic, still explainable)
- Integration test fixtures
- Non-Windows workflow scripts

If you contribute: don't add auto-posting features, keep prompts versioned, keep logs free of secrets, keep scoring deterministic.

---

**Output is suggestions. You review everything before acting on it.**
