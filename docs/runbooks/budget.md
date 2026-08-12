# Runbook: budget

How the department's spend is bounded and what to do when the bound is hit (design §2, §8).

## How the cap works

- All agent workflows call the API with the `ANTHROPIC_API_KEY` from the **Claude Platform workspace `dev-department`** (console.anthropic.com) — a workspace separate from any personal use, so department spend is isolated and visible.
- The workspace carries a **monthly hard cap of €500** (decided 2026-08-12; the console bills and caps in USD, so set the USD equivalent — revisit after one month of real PBIs). When the cap is reached, API calls fail; agents stop mid-month rather than overspending. That is the intended behavior, not an outage.
- Per run, every agent is additionally bounded by a conservative `--max-turns` (set in the workflows) — an agent stuck in a loop costs at most one run budget (§8).

## Reading consumption

- **Total and per-key**: Console → workspace `dev-department` → Usage. With the single shared key (v1), this gives department totals per day/model.
- **Per agent**: create one API key per workflow (intake, design, build, fix) in the workspace and set them as separate secrets when per-agent attribution matters — the console then breaks usage down per key. Until then, approximate per-agent cost from the Actions side: run counts and durations per workflow in each repo's Actions tab, and the daily digest's 24h run summary.
- **Anomaly signal**: the digest shows run counts per repo per day. A jump in runs without a jump in PBIs is the early warning — look before the cap does it for you.
- **Digest consumption line**: set the `ANTHROPIC_ADMIN_KEY` secret on dev-department (an organization Admin API key, `sk-ant-admin...` — a different key type than the workspace API key) and optionally the `ANTHROPIC_WORKSPACE_ID` variable to scope to the dev-department workspace; the daily digest then shows month-to-date spend from the Admin cost-report API. Without the secret it shows the cap and a setup pointer instead.

## When the cap is hit mid-month

Symptoms: agent runs start failing fast with API billing errors; ⚠️ failure comments appear on issues/PRs (silent failure is forbidden), and the digest lists the failed runs.

1. **Don't raise the cap first.** First establish *why* it was hit: normal month-end with unusually many features, or a runaway (one issue with dozens of runs, an agent burning max-turns every run)?
   - Check the digest and `gh run list` per repo for run-count outliers.
   - A runaway is an incident: follow [incident.md](incident.md) (kill switch first).
2. **Legitimate exhaustion** — decide as PO, it is a prioritization call:
   - raise the cap in the console (workspace settings → limits), or
   - let the department idle until the month resets, and re-trigger paused phases afterwards (see [kill-switch.md](kill-switch.md) § Resume — same re-labeling mechanic).
3. **Either way**: nothing is lost. Runs failed loudly, branches and issues are intact; every paused phase resumes with a label re-apply.

## Hygiene

Review the €500 cap against actual spend — first revisit after one month of real PBIs, then quarterly; a cap at 3× the normal month is an alarm that still bounds damage, a cap at 1.05× is a monthly outage generator.
