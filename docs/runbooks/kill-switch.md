# Runbook: kill switch

How to stop the entire department, instantly and reversibly (design §8).

## Stop

The variable `AGENTS_ENABLED` is checked by every agent workflow as its first job; `false` makes them exit cleanly before any model call.

```bash
gh variable set AGENTS_ENABLED --body false --repo marinusbrink/dev-department
```

And per product repo (or once at org level — an org variable covers every repo that doesn't override it):

```bash
gh variable set AGENTS_ENABLED --body false --repo marinusbrink/ryd
```

**In-flight runs are not killed by the variable** — they finish their current run. To hard-stop them too:

```bash
gh run list --repo marinusbrink/ryd --status in_progress --json databaseId -q '.[].databaseId' | xargs -n1 gh run cancel --repo marinusbrink/ryd
```

## What keeps running

**Nothing agent-shaped.** No intake, design, build, or fix run starts; no model call is made; no comment, label, branch, or PR is created by an agent. Agents never could merge or deploy (branch protection, §8), so nothing needs additional locking.

The only thing that still runs is the **daily digest** — deliberately: it makes no model calls (pure GitHub scripting) and its first line reports the kill-switch state. So during a stop, the 07:00 digest says "KILL SWITCH ACTIVE" — and silence still unambiguously means "digest broken", never "all good" (§8).

## Resume

1. Set the variable back (or delete it — unset counts as enabled):

   ```bash
   gh variable set AGENTS_ENABLED --body true --repo marinusbrink/ryd
   ```

2. Re-trigger whatever was mid-phase: label events consumed during the stop don't replay. Re-apply the pipeline label (`status:intake`, `status:design` or `status:build`) on the affected issues — every workflow is designed to be re-triggered safely (concurrency groups queue; the build phase reuses its feature branch).
3. Check the next morning's digest confirms normal operation.

## When to pull it

Any time you'd rather think than watch: an agent looping, unexpected API spend, wrong-looking PRs piling up, or an incident (see [incident.md](incident.md) — the kill switch is its step 1). Pulling it costs one re-trigger per in-flight issue; hesitating costs more.
