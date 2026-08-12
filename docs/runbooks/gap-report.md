# Gap report — repo vs. design

**Date:** 2026-08-12 · **Verified against:** [docs/design/software-development-department.md](../design/software-development-department.md) · **Method:** full-repo read + on-paper pipeline walk-through ([example-pbi.md](../onboarding/example-pbi.md))

Overall: the §11 week-1 scope is complete and weeks 2–3 are largely pre-built (all ten agents, four pipeline workflows, digest, onboarding kit). The gaps below are grouped by who they wait on. Items marked **(walk-through)** were found by tracing the example PBI end to end.

---

## A. Waiting on the human

### A1. Open design choices (TODO(choice-N))

- [ ] **choice-1 — notification channel** (digest + critical alerts): marked in `README.md`, `agents/devops.md`, `.github/workflows/digest.yml`. Interim: GitHub issue labeled `digest`; critical devops escalation = `@`-mention.
- [ ] **choice-2 — design gate rhythm**: ⚠️ **marked nowhere** — the only choice without a `TODO(choice-2)` anchor. The de-facto interim is "review as soon as ready" (the design PR simply waits for your merge). Needs a marker (likely in `workflows/README.md` § How the phases chain) or a decision.
- [ ] **choice-3 — release train days** (Tue/Fri vs. store lead times): marked in `agents/release-manager.md`.
- [ ] **choice-4 — regression suite core journeys** (fixed list vs. derived): marked in `agents/test-engineer.md`. Interim: design docs' E2E scenarios.
- [ ] **choice-5 — monthly budget ceiling**: marked in `README.md`, `workflows/README.md`, `docs/runbooks/budget.md`, `.github/workflows/digest.yml`.
- [ ] **choice-6 — documentation languages**: marked in `agents/documentation.md`. Interim: source language only.
- [ ] **choice-7 — performance budget numbers** (esp. 99.9%): marked in `conventions/performance-budgets.md`.

### A2. Human setup actions (documented, not yet performed)

- [ ] Claude Platform workspace `dev-department` + `ANTHROPIC_API_KEY` + spend cap (§2; `docs/runbooks/budget.md`).
- [ ] ryd onboarding itself: copy `CLAUDE.md` (fill `TODO(fill-from-repo)` stubs), labels, issue form, callers, secrets, `PRODUCT_REPOS` variable (`docs/onboarding/product-onboarding.md`).
- [ ] Branch protection on the product repo's `main` (§8; onboarding step 5).
- [ ] **Branch protection on `dev-department` itself**: `conventions/README.md` promises "changes only via reviewed PRs", but this repo's `main` is unprotected — this entire build was pushed straight to main. Consistent for bootstrap, inconsistent from the moment the department operates.

---

## B. Genuine gaps (waiting on work)

### B1. Department repo — buildable now

- [x] **Documentation agent is wired into nothing** **(walk-through, most important gap)**: `build.yml` never runs `agents/documentation.md`, yet `agents/reviewer.md` checklist item 11 blocks every user-behavior PR without a docs change (§5, §7). As built, every real feature PR deadlocks on a blocker no agent in the pipeline can resolve. Fix direction: a documentation step in `build.yml` between implementers and reviewer. **Fixed 2026-08-12:** documentation-draft step added to `build.yml` (after tests, before reviewer; reviewer now depends on it) + chain updated in `workflows/README.md` — PR "fix: close gap-report B1 items 1-3".
- [x] **Constitution not referenced by 3 of 10 agents** (§4.0 requires it in *every* agent prompt): `agents/devops.md`, `agents/documentation.md`, `agents/retrospective.md` have no read-the-constitution instruction. (Verified by grep; the other seven have it.) **Fixed 2026-08-12:** "Before anything else — Read `conventions/saas-constitution.md`" sections added to all three; grep now finds ten — PR "fix: close gap-report B1 items 1-3".
- [x] **Test engineer misses the §6 obligation** "performance test at expected volume ×5 for risk class critical/high" — absent from `agents/test-engineer.md` and from the build pipeline. **Fixed 2026-08-12:** ×5 obligation added to the SaaS obligations in `agents/test-engineer.md`, incl. missing-volume-is-a-finding rule — PR "fix: close gap-report B1 items 1-3".
- [ ] **No devops workflow harness** (§6 layer 2): `agents/devops.md` exists, but there is no `repository_dispatch` receiver for alert webhooks and no nightly-audit schedule. Scheduled for §11 week 4+, but currently the agent is unreachable.
- [ ] **No retrospective workflow harness** (§4.9, §5): nothing triggers the agent on `status:released`, and the quarterly pruning run (§9) has no schedule. Scheduled "only after" per §11.
- [ ] **Nothing ever sets `status:released`** (§5): the label exists in the required set, but no workflow flips it (depends on deploy/release workflows — deferred by instruction to onboarding phase 3–4, together with the release-manager harness).
- [ ] **§10 per-domain serialization is not enforced**: build concurrency is per *issue* (`dept-issue-<n>`); two issues touching the same domain can build in parallel. Current mitigation is PO discipline (onboarding phase table). Fix direction: a domain-derived concurrency key or a scheduling check in `build.yml`.
- [ ] **§5 "implementers parallel per domain, own worktree/branch" is simplified**: one backend agent covers all domains sequentially on one branch (documented in `build.yml` header). Acceptable v1 deviation; recorded here so it's a decision, not an accident.
- [ ] **Mobile has no implementer/conventions coverage** **(walk-through)**: `agents/implementer-frontend.md` and `conventions/coding-conventions.md` are web-shaped (shadcn/ui, Core Web Vitals); the mobile budget row (offline-first, sync queue, cold start) has no corresponding build guidance. First mobile-touching PBI will expose this.
- [ ] **Intake re-trigger after answered questions is manual re-label** **(walk-through)**: §5's "Marinus completes → intake again" works only if the label is re-applied (documented in the smoke test + failure comments, but easy to miss; no comment-triggered re-run).
- [ ] **Gate-2 "decline due to design flaw" path** (§5) is described only in a `fix.yml` comment — no runbook step for closing the PR and resetting to `status:design`.

### B2. Product-side — scheduled to arrive with onboarding phases (§11), not slipped

- [ ] Product CI: build + regression on merge; migration test against a production-like schema *with data* (§4.5).
- [ ] k6 nightly load tests per budget row; Lighthouse/bundle budgets in CI (`conventions/performance-budgets.md` enforcement).
- [ ] Deploy/release workflows: Cloud Run traffic splitting + auto-rollback, contract calendar tooling, mobile release train (§4.7 — agent exists, harness deliberately deferred).
- [ ] GCP layer 1 (§6): structured logging → Cloud Logging, Error Reporting, uptime checks/synthetic journeys, SLOs + burn-rate alerting, Cloud Run probes; alert webhook → `repository_dispatch`.
- [ ] Error-budget tracking that actually feeds the release manager's freeze rule (currently prose without a data source).
- [ ] Docs infrastructure (§7): docs site skeleton, demo tenant + seed data, screenshot workflow, OpenAPI publication + breaking-change detection in CI, architecture overview generation, engineering changelog.
- [ ] GitHub Environments with per-environment secrets (§8) — at deploy phase.
- [ ] OpenTMS-next domain map lands in that repo's CLAUDE.md at its onboarding (§3.1 — content already in the design doc).

### B3. Observability of the department itself

- [ ] Digest budget line is a manual pointer to the console — no automated spend reporting (acceptable until choice-5; noted for completeness).
- [ ] Per-agent API attribution needs key-per-workflow split (documented as refinement in `docs/runbooks/budget.md`, not done).

---

**Reading order for fixing:** B1 items 1–3 before the first real PBI runs (the docs deadlock guarantees a failed first feature; the missing constitution reads and the ×5 perf test are two-line agent edits); A2 branch protection on this repo at the same moment; everything else follows the §11 phase it belongs to.
