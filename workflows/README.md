# Reusable workflows — caller contract

The workflow YAMLs live in [`.github/workflows/`](../.github/workflows/) (GitHub requires reusable workflows there); this folder documents the contract a product repo must satisfy to call them. The shared agent-runner step is the composite action [`.github/actions/run-agent`](../.github/actions/run-agent/action.yml), which every workflow reaches through the department sync checkout.

Deploy/release workflows are deliberately absent — they are product-specific and are created at product onboarding (`docs/onboarding/`).

## What every workflow does (design §5, §8, §2)

- **Kill switch**: checks the caller repo's variable `AGENTS_ENABLED` first and exits cleanly when it is `false`. Unset counts as enabled.
- **Fresh sync**: checks out `marinusbrink/dev-department@main` into `.dev-department/` at the start of every run — agents, conventions, templates and lessons are never stale copies.
- **Concurrency**: one run per issue at a time (`dept-issue-<n>`; the fix loop serializes per PR). Re-triggers queue, they don't duplicate work.
- **Budget bound**: `--max-turns` per agent run is **headroom, not a target** (PO decision 2026-08-18): caps sit at 2–3× observed successful-run turn counts and exist to catch pathology — a run killed at the cap costs its full spend *plus* the convergence round that re-does the work, so tight caps waste tokens rather than save them. The operative brakes are the convergence `max-rounds`, the workspace spend cap (€500 hard, decided 2026-08-12) and `AGENTS_ENABLED`. The retrospective after ~5 shipped features tightens caps from the run artifacts' `num_turns`/cost data — optimizing agents so the caps can come DOWN is part of that retro's mandate.
- **Failure is visible**: any errored run posts a ⚠️ comment on the triggering issue/PR with the run log link. Silence never means "all good".
- **RESULT contract**: every agent ends with a machine-readable `RESULT:` line; a run without one fails loudly.
- **Model is workflow-owned**: every reusable workflow takes a `model` input (default `claude-sonnet-4-6`) and passes it as `--model` to every agent run, so neither checked-in `.claude` settings files nor the CLI's dynamic default-model resolution can ever decide the department's model (incident 2026-08-13: agent runs failed on a server-resolved `claude-opus-5[1m]` interactive alias the SDK rejects). Callers may override per call with `with: model:`; raising a role's model is a PO decision, not an agent or default drift.
- **The build phase converges** (PO decision 2026-08-17, supersedes the single-fix-round reading of §4.6): a mechanical compile gate (caller's `verify-command`) with its own fix round runs inside every build pass, and a run that ends without a gate-2-ready PR — findings left, blockers left, or a failed step — dispatches its own next round via `workflow_dispatch`, bounded by `max-rounds` (default 3). At the cap it pauses loudly; `AGENTS_ENABLED` kills the whole loop. Gate 2 stays human — convergence targets the *internal* green, never the merge.
- **Capability is workflow-owned, toolchain is caller-owned**: every agent run gets an explicit `--allowedTools` list covering exactly the duties its definition orders — headless runs deny every tool call outside it (incident 2026-08-13, run 31714423931: no allowlist → 28 denials burned the architect's whole budget). Product build/test/package-manager commands are the one part the reusable workflows cannot know; the caller grants them via `extra-allowed-tools` on `build.yml`/`fix.yml`, filled from the product's CI (see the caller templates).

## The caller stub

One file in the product repo covers the whole pipeline:

```yaml
# .github/workflows/department.yml in the product repo
name: department pipeline
on:
  issues:
    types: [labeled]
  pull_request:
    types: [closed]
  pull_request_review:
    types: [submitted]

jobs:
  intake:
    if: github.event_name == 'issues' && github.event.label.name == 'status:intake'
    uses: marinusbrink/dev-department/.github/workflows/intake.yml@main
    with:
      issue-number: ${{ github.event.issue.number }}
    secrets:
      ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}

  design:
    if: github.event_name == 'issues' && github.event.label.name == 'status:design'
    uses: marinusbrink/dev-department/.github/workflows/design.yml@main
    with:
      issue-number: ${{ github.event.issue.number }}
    secrets:
      ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}

  design-merged:   # gate 1: a human merging the design PR is the approval act
    if: >-
      github.event_name == 'pull_request' &&
      github.event.pull_request.merged == true &&
      startsWith(github.event.pull_request.title, 'Design:')
    uses: marinusbrink/dev-department/.github/workflows/design.yml@main
    with:
      mode: design-merged
      pr-number: ${{ github.event.pull_request.number }}
    secrets:
      ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}

  build:
    if: github.event_name == 'issues' && github.event.label.name == 'status:build'
    uses: marinusbrink/dev-department/.github/workflows/build.yml@main
    with:
      issue-number: ${{ github.event.issue.number }}
    secrets:
      ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}

  fix:             # gate 2 comments: same PR, new commits (§5)
    if: >-
      github.event_name == 'pull_request_review' &&
      github.event.review.state != 'approved' &&
      !endsWith(github.actor, '[bot]') &&
      startsWith(github.event.pull_request.title, 'Feature:')
    uses: marinusbrink/dev-department/.github/workflows/fix.yml@main
    with:
      pr-number: ${{ github.event.pull_request.number }}
    secrets:
      ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
```

Caller jobs inherit the repo's default `GITHUB_TOKEN` permissions — the repo (or the caller jobs) must grant at least `contents: write`, `issues: write`, `pull-requests: write` for design/build/fix, and read+issues for intake.

## Required in the product repo

**Secrets**
| Secret | Purpose |
|---|---|
| `ANTHROPIC_API_KEY` | API key from the Claude Platform workspace "dev-department" (budget-capped, §2). Required by every workflow. |
| `DEPT_SYNC_TOKEN` | Only while `dev-department` is private: a read token for the sync checkout. Omit if public. |

**Variables**
| Variable | Purpose |
|---|---|
| `AGENTS_ENABLED` | The kill switch (§8). Set to `false` to stop all agent workflows; `true`/unset means enabled. |

**Labels** (issue forms and workflows assume they exist):

```bash
gh label create "status:intake"     --color FBCA04 --description "PBI awaiting/in intake check"
gh label create "status:design"     --color 1D76DB --description "Ready — architect designs"
gh label create "status:build"      --color 0E8A16 --description "Design approved — build phase"
gh label create "status:released"   --color 5319E7 --description "Merged and released"
gh label create "approved-by-agent" --color C2E0C6 --description "Reviewer agent: zero blockers"
```

**Files**
- `CLAUDE.md` **with the domain map** (§3.1) — mandatory onboarding artifact; the intake agent refuses to run without it.
- `docs/designs/` — where the architect's design PRs land.
- `.github/ISSUE_TEMPLATE/pbi.yml` — copy from `templates/`+`.github/ISSUE_TEMPLATE/` in this repo so new PBIs get `status:intake` automatically.

**Branch protection on `main`** (§8): require human review + green CI; agents are technically excluded from merging and from pushes to main. The workflows never merge — gate 1 is a human merging the design PR, gate 2 a human merging the feature PR.

## How the phases chain

`status:intake` → intake agent → (`ready` flips to `status:design`) → architect opens design PR → **human merges it (gate 1)** (gate rhythm, decided 2026-08-12: review as soon as ready — a design PR waits only for the PO, never for a calendar) → `design-merged` flips to `status:build` → build pipeline (backend → frontend → draft PR → tests → documentation draft → reviewer, max one internal fix round per stage) → zero blockers → PR leaves draft and awaits **gate 2** → human comments trigger `fix.yml` (same PR, new commits, reviewer pre-check) → human merges. If the build pipeline pauses (blocked / findings remain), it says so on the issue; re-applying `status:build` runs another pass on the same branch.

## RESULT lines (what workflows branch on)

| Agent | Lines |
|---|---|
| intake | `ready` \| `questions:<N>` |
| architect | `design-pr:<N>` \| `blocked` |
| implementers | `done` \| `blocked` |
| test engineer | `passed` \| `findings:<N>` |
| reviewer | `approved` \| `blockers:<N>` |

## Pinning

Product repos call `@main` deliberately (§3): an improvement to an agent or workflow is immediately active in every product. Pin to a tag only if a product must temporarily freeze department behavior — and treat that as an incident, not a habit.
