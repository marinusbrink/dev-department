# Product onboarding

Checklist to connect a product repo to the department. Order matters: the domain map comes first because nothing else runs without it (§3.1 — **no map, no agents**), and the caller workflows come last so nothing triggers half-configured.

## 1. CLAUDE.md with the domain map (mandatory)

The one artifact only the PO can deliver: per domain a name, a one-sentence responsibility, the key entities, and the published events/interfaces to other domains — plus the one horizontal **platform layer** (ABP core, mail, background jobs, document generation, notifications). The dependency arrow always points downward: the platform knows no business domain. The map belongs to the PO; agents may propose changes via the retrospective route, never apply them.

- For **ryd**: copy [ryd-CLAUDE.md](ryd-CLAUDE.md) to the repo root as `CLAUDE.md` and fill the `TODO(fill-from-repo)` stubs from the actual codebase.
- The intake agent refuses to run on a product without a map — that refusal is working as designed.

## 2. Labels

```bash
R=marinusbrink/ryd
gh label create "status:intake"     --repo $R --color FBCA04 --description "PBI awaiting/in intake check"
gh label create "status:design"     --repo $R --color 1D76DB --description "Ready — architect designs"
gh label create "status:build"      --repo $R --color 0E8A16 --description "Design approved — build phase"
gh label create "status:released"   --repo $R --color 5319E7 --description "Merged and released"
gh label create "approved-by-agent" --repo $R --color C2E0C6 --description "Reviewer agent: zero blockers"
```

## 3. PBI issue form

Copy `.github/ISSUE_TEMPLATE/pbi.yml` from dev-department into the product repo (same path), so every new PBI gets `status:intake` automatically. Create `docs/designs/` (with a `.gitkeep`) — the architect's design PRs land there.

## 4. Secrets and variables

| Where | What |
|---|---|
| product repo, secret `ANTHROPIC_API_KEY` | key from the Claude Platform workspace **dev-department** (budget-capped — see `docs/runbooks/budget.md`) |
| product repo, secret `DEPT_SYNC_TOKEN` | only while dev-department is private: read token for the sync checkout |
| product repo, variable `AGENTS_ENABLED` | `true` (the kill switch, §8) |
| dev-department, variable `PRODUCT_REPOS` | append the new repo (space-separated) so the daily digest covers it |
| dev-department, secret `DIGEST_TOKEN` | only if the product repo is private: read token for the digest queries |

Deploy secrets come later (step 6, phase 3) and go into **GitHub Environments** per environment, scoped to the deploy workflows only — agents get, per workflow, only the secrets that workflow needs (§8).

## 5. Branch protection on `main` (§8)

Require: at least **1 human review**, **green CI status checks**, no force pushes, no deletions — and no bypass allowances for apps or bots. Agents work through `GITHUB_TOKEN` (the `github-actions` app); with review required and no bypass, they technically cannot merge or push to main, whatever their prompt says.

```bash
gh api -X PUT "repos/$R/branches/main/protection" \
  -f "required_pull_request_reviews[required_approving_review_count]=1" \
  -f "required_status_checks[strict]=true" -f "required_status_checks[contexts][]=CI" \
  -f "enforce_admins=false" -F "restrictions=null" -f "allow_force_pushes=false" -f "allow_deletions=false"
```

(Adjust the `CI` context name to the product's actual check; rulesets via the UI are equivalent.)

## 6. Caller workflows — phased per the §11 rollout order

The callers live in [ryd-workflows/](ryd-workflows/); copy them into the product's `.github/workflows/` **one phase at a time**:

| Phase (§11) | Copy | What becomes live |
|---|---|---|
| **1 — week 1** | `dept-intake.yml` | Every PBI gets checked against the Definition of Ready. Digest already covers the repo via `PRODUCT_REPOS`. (The reviewer participates from phase 3 — it runs inside the build/fix pipelines; a standalone reviewer trigger for human-authored PRs can be added later if wanted.) |
| **2 — weeks 2–3** | `dept-design.yml` | The design gate: architect PRs to `docs/designs/`, human merge = gate 1. Stand up the docs site skeleton and OpenAPI publication (§7) alongside, so the documentation agent participates from the first real feature. |
| **3 — weeks 2–3, after first designs** | `dept-build.yml` + `dept-fix.yml` | Full build pipeline and the gate-2 fix loop. **Start with one low-risk domain** (for ryd: Master Data) — pick the first PBIs accordingly; serialization per domain is the rule anyway (§10). |
| **4 — week 4+** | *(created at this phase)* | Deploy/release workflows (Cloud Run traffic splitting, release train) are product-specific and are built here, per `agents/release-manager.md` and `agents/devops.md`; then devops layer 1 (logging, SLOs, synthetics) and triage-only devops runs. |
| **later** | — | Devops self-resolution (rollback), retrospective automation, second product. |

## 7. Smoke test

1. Open a test PBI via the issue form → the intake run appears in Actions and posts questions or a ready verdict.
2. Answer its questions with a comment, re-apply `status:intake`, and check it reaches `ready` → `status:design`.
3. Next morning: the digest issue in dev-department lists the repo with yesterday's runs.
4. Then delete the test PBI's noise (close the issue) — or keep it as the first real feature.

## Sign-off

Onboarded means: domain map merged in `CLAUDE.md`, labels and issue form present, branch protection active, intake green on a real PBI, digest covering the repo. Everything after that is phases 2–4 of the table above.
