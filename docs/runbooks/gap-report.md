# Gap report — repo vs. design

**Date:** 2026-08-12 · **Verified against:** [docs/design/software-development-department.md](../design/software-development-department.md) · **Method:** full-repo read + on-paper pipeline walk-through ([example-pbi.md](../onboarding/example-pbi.md))

Overall: the §11 week-1 scope is complete and weeks 2–3 are largely pre-built (all ten agents, four pipeline workflows, digest, onboarding kit). The gaps below are grouped by who they wait on. Items marked **(walk-through)** were found by tracing the example PBI end to end.

---

## A. Waiting on the human

### A1. Open design choices — all decided 2026-08-12 (PR "chore: resolve open choices 1-7")

- [x] **choice-1 — notification channel** = **email**: digest mailed daily (guarded email step in `digest.yml`, activates when the `MAIL_*` secrets are set); critical devops alerts go by email *plus* `@`-mention; the GitHub issue labeled `digest` stays as the always-works fallback. Resolved in `README.md`, `agents/devops.md`, `.github/workflows/digest.yml`.
- [x] **choice-2 — design gate rhythm** = **review as soon as ready** — a design PR waits only for the PO, never for a calendar. First anchored with a `TODO(choice-2)` marker in `workflows/README.md` § How the phases chain (it was marked nowhere), then resolved there.
- [x] **choice-3 — mobile release train** = **Tue/Fri confirmed** — submission days, store review lands 1–2 days later. Dormant until ryd onboards. Resolved in `agents/release-manager.md`.
- [x] **choice-4 — regression core journeys** = **fixed PO-owned list** (initial, opentms-next: login; order → plan → execute → invoice chain; batch invoice run; tenant isolation on list endpoints), automatically extended with every critical-class E2E scenario from approved design docs. Resolved in `agents/test-engineer.md`.
- [x] **choice-5 — monthly budget ceiling** = **€500 hard cap** on the dev-department workspace; digest shows month-to-date consumption (Admin cost-report API, activates when `ANTHROPIC_ADMIN_KEY` is set); revisit after one month of real PBIs. Resolved in `README.md`, `workflows/README.md`, `docs/runbooks/budget.md`, `.github/workflows/digest.yml`.
- [x] **choice-6 — documentation languages** = **the product's ABP localization configuration is the single source of truth**, read at run time (never a hardcoded list); source language EN (ryd) / NL (opentms-next); all other configured languages are generated translations with human spot checks. Resolved in `agents/documentation.md`.
- [x] **choice-7 — performance budgets** = **all default numbers confirmed**, including 99.9% availability; mobile rows defined but dormant until ryd onboards. Resolved in `conventions/performance-budgets.md`.

### A2. Human setup actions (documented, not yet performed)

- [x] Claude Platform workspace `dev-department` + `ANTHROPIC_API_KEY` + spend cap (§2; `docs/runbooks/budget.md`; cap decided: €500). **Done 2026-08-12:** workspace created, spend cap set, API key stored for product onboarding.
- [x] `MAIL_*` secrets for digest email delivery (`MAIL_SMTP_URL`, `MAIL_USERPASS`, `MAIL_FROM`, `MAIL_TO`) — set 2026-08-12; the first four digest runs failed SMTP auth (curl exit 67) during the `MAIL_USERPASS` setup iterations until the `user:password` form was stored. **First delivery confirmed 2026-08-12** — the digest run logs "Digest mailed", receipt confirmed by the PO.
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
- [x] **Architect starved and tool-less on the first real design (2026-08-13)**: `design.yml` passed no `--allowedTools`, so the headless run denied every mutating tool call — 25 permission denials in 51 turns, no branch, no PR — and the 50-turn cap ran out on ceremony. **Fixed 2026-08-13:** explicit architect allowlist in `design.yml` (write doc, branch/commit/push, open PR, report conflicts); `max-turns` became a caller-configurable input on every pipeline workflow with per-role defaults (intake 25, reviewer 30, architect 80, implementers 60, documentation 40 — the architect produces the largest single artifact in the pipeline); one-write efficiency rule added to `agents/architect.md` — PR "fix: architect capability + per-role turn budgets".
- [ ] **Same missing-allowlist defect latent in `build.yml`/`fix.yml` mutating agents**: the implementer, test-engineer and documentation invocations pass no `allowed-tools` either and will deny-loop exactly like the architect the moment phase 3 activates. Their grants are necessarily broader (builds, tests, package managers) — decide them deliberately at phase-3 activation, before enabling `dept-build.yml`/`dept-fix.yml`.

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

- [ ] Digest budget line is a manual pointer to the console — no automated spend reporting (acceptable until choice-5; noted for completeness). **Status 2026-08-12: implemented, deliberately inactive (individual org).** The automation shipped in PR 2 (Admin cost-report fetch, guarded on `ANTHROPIC_ADMIN_KEY`) but stays dormant by decision: Admin API keys require a *team* organization and this Console account is an *individual* one — converting it for one convenience line is not worth it. The workspace spend cap is the actual guardrail; the digest shows the cap plus a setup pointer. Activates by setting `ANTHROPIC_ADMIN_KEY` if the org ever converts to team.
- [ ] Per-agent API attribution needs key-per-workflow split (documented as refinement in `docs/runbooks/budget.md`, not done).

---

**Reading order for fixing:** B1 items 1–3 before the first real PBI runs (the docs deadlock guarantees a failed first feature; the missing constitution reads and the ×5 perf test are two-line agent edits); A2 branch protection on this repo at the same moment; everything else follows the §11 phase it belongs to.
