# Reusable workflows — caller contract

The workflow YAMLs live in [`.github/workflows/`](../.github/workflows/) (GitHub requires reusable workflows there); this folder documents the contract a product repo must satisfy to call them. The shared agent-runner step is the composite action [`.github/actions/run-agent`](../.github/actions/run-agent/action.yml), which every workflow reaches through the department sync checkout.

Deploy/release workflows are deliberately absent — they are product-specific and are created at product onboarding (`docs/onboarding/`).

## What every workflow does (design §5, §8, §2)

- **Kill switch**: checks the caller repo's variable `AGENTS_ENABLED` first and exits cleanly when it is `false`. Unset counts as enabled.
- **Fresh sync**: checks out `marinusbrink/dev-department@main` into `.dev-department/` at the start of every run — agents, conventions, templates and lessons are never stale copies.
- **Concurrency**: one run per issue at a time (`dept-issue-<n>`; the fix loop serializes per PR). Re-triggers queue, they don't duplicate work.
- **Budget bound**: conservative `--max-turns` per agent run — a stuck agent costs at most one run budget. Monthly ceiling for the API workspace: TODO(choice-5).
- **Failure is visible**: any errored run posts a ⚠️ comment on the triggering issue/PR with the run log link. Silence never means "all good".
- **RESULT contract**: every agent ends with a machine-readable `RESULT:` line; a run without one fails loudly.

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

`status:intake` → intake agent → (`ready` flips to `status:design`) → architect opens design PR → **human merges it (gate 1)** → `design-merged` flips to `status:build` → build pipeline (backend → frontend → draft PR → tests → reviewer, max one internal fix round per stage) → zero blockers → PR leaves draft and awaits **gate 2** → human comments trigger `fix.yml` (same PR, new commits, reviewer pre-check) → human merges. If the build pipeline pauses (blocked / findings remain), it says so on the issue; re-applying `status:build` runs another pass on the same branch.

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
