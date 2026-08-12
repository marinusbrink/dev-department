# Example PBI + on-paper pipeline walk-through

A realistic small ryd feature traced through the whole pipeline, naming per step the file that governs the behavior. Steps without a governing file are gaps — collected in [docs/runbooks/gap-report.md](../runbooks/gap-report.md). Written 2026-08-12; also usable as the smoke-test PBI at onboarding.

## The PBI (as filed via the issue form)

> **Title:** PBI: Driver reorders today's stops manually
>
> **Story:** As a driver I want to reorder today's stops manually because the optimizer doesn't know about a customer's dock times.
>
> **Affected area:** driver app — today's route / stop list
>
> **Tenant dimension:** identical for all tenants
>
> **Expected volumes:** ≤ 30 stops per trip; a handful of reorders per driver per day
>
> **Known edge cases:** planner replans the trip while the driver is reordering (concurrency); driver is offline in a warehouse when reordering; does a later optimizer run overwrite the manual order?; empty stop list
>
> **Privacy note:** none — no new personal data

## The walk-through

| # | Step | What happens | Governing file(s) | Verdict |
|---|---|---|---|---|
| 1 | PBI filed | Issue form applies `status:intake` on creation | `.github/ISSUE_TEMPLATE/pbi.yml` (product copy), `templates/pbi.md` | ✅ |
| 2 | Intake triggered | Label event → caller → reusable workflow: kill-switch gate, fresh department sync, per-issue concurrency, failure-comment guarantee | `docs/onboarding/ryd-workflows/dept-intake.yml`, `.github/workflows/intake.yml`, `.github/actions/run-agent/action.yml` | ✅ |
| 3 | Intake judgment | Checklist vs. the domain map; never interpret charitably. Realistic outcome here: **questions first** — "does the manual order survive an optimizer rerun?" and "what happens on planner/driver concurrent edits?" are exactly the §4.1 doubt cases | `agents/intake.md`, `conventions/saas-constitution.md`, ryd `CLAUDE.md` (domain map) | ✅ |
| 4 | PO answers | Answers as issue comment, then **re-applies `status:intake`** — the re-run reads the comment history and won't re-ask | intake re-run: same files; re-trigger mechanic: documented only in `docs/onboarding/product-onboarding.md` §7 | ⚠️ gap (manual re-label; B1) |
| 5 | Ready | Fixed summary comment; label flips to `status:design` (agent + workflow, idempotent) | `agents/intake.md`, `.github/workflows/intake.yml` | ✅ |
| 6 | Architect designs | Design PR `docs/designs/<n>-manual-stop-reorder.md`, all nine sections: Domain impact (Planning & Route owns stop order; Execution & POD renders it; `StopOrderChanged`-style event to be specified), API contract for the reorder mutation, optimistic update designated (mutations budget: p95 < 500 ms), flag `Planning.ManualStopReorder` default off, assumptions listed for gate 1 | `agents/architect.md`, `templates/design-doc.md`, `conventions/*`, `.github/workflows/design.yml` (architect mode), `docs/onboarding/ryd-workflows/dept-design.yml` | ✅ |
| 7 | **GATE 1** | Human reviews assumptions first, merges the design PR; merge event flips issue to `status:build` | branch protection (`docs/onboarding/product-onboarding.md` §5), `.github/workflows/design.yml` (design-merged mode) | ✅ (protection = human setup, A2) |
| 8 | Backend build | Implementer scoped to Planning & Route on `feature/<n>`: concurrency handling per design, additive migration if stop order is persisted new, no PII in logs | `agents/implementer-backend.md`, `conventions/coding-conventions.md`, `.github/workflows/build.yml` | ✅ |
| 9 | Frontend/mobile build | Driver-app reorder UI against the typed client, optimistic update per design, offline behavior… **which conventions?** The driver app is mobile; conventions and the frontend agent are web-shaped (shadcn/ui, query layer); offline-first sync queue exists only as a budget row | `agents/implementer-frontend.md`, `conventions/performance-budgets.md` (mobile row) | ⚠️ gap (no mobile guidance; B1) |
| 10 | Draft feature PR | Created draft; stays draft until zero blockers | `.github/workflows/build.yml` | ✅ |
| 11 | Tests | Risk analysis executed: tenant-isolation tests on the reorder endpoint (can driver of tenant A reorder tenant B's trip?), concurrency test (planner vs. driver), E2E per risk class | `agents/test-engineer.md`, `conventions/performance-budgets.md` | ✅ — but the §6 "×5 volume performance test" obligation is nowhere (B1) |
| 12 | Manual draft | The feature changes user behavior, so the PR must contain a manual page (§5, §7.1)… **no step in `build.yml` runs the documentation agent** | `agents/documentation.md` exists — but nothing invokes it | ❌ **gap (pipeline deadlock; B1 top item)** |
| 13 | Agent review | Full checklist against the design; item 11 (docs) **blocks** because step 12 never happened → with the current wiring this PBI cannot reach gate 2 | `agents/reviewer.md`, `.github/workflows/build.yml` | ❌ consequence of step 12 |
| 14 | **GATE 2** | (Assuming step 12 fixed:) human reviews the ready PR; comments → fix commits on the same PR + reviewer pre-check; decline-as-design-flaw → close PR, back to `status:design` (manual, thinly documented) | branch protection, `docs/onboarding/ryd-workflows/dept-fix.yml`, `.github/workflows/fix.yml`; decline path: comment in `fix.yml` only | ✅ / ⚠️ (decline path; B1) |
| 15 | Merge → CI → deploy | Product CI (build + regression), Cloud Run deploy with traffic splitting vs. budgets, auto-rollback | **no governing file** — product-specific, §11 phase 3–4 (`agents/release-manager.md` waits for its harness) | ⚠️ deferred (B2) |
| 16 | Flag rollout + docs publish | Flag activation order per design; docs published at activation | `agents/release-manager.md`, `agents/documentation.md` — prose only, no harness | ⚠️ deferred (B2) |
| 17 | `status:released` + retrospective | Label flip and per-PR retrospective run | **no governing file** (no release workflow, no retrospective trigger) | ⚠️ deferred (B1/B2) |
| 18 | Visibility throughout | Every run, failure, and waiting item in the next morning's digest | `.github/workflows/digest.yml` | ✅ |

## Conclusion

From filing to gate 2 the pipeline is governed by a named file at every step except one: **the manual-draft step (12) has an agent but no invocation**, and its absence hard-blocks step 13 — the single wiring change the gap report ranks first. Steps 15–17 are ungoverned by design until onboarding phases 3–4. The three ⚠️ mechanics (manual intake re-trigger, mobile conventions, decline path) are real but survivable with human awareness; the ❌ is not.
