# Design: Software Development Department of AI Agents

**Status:** approved concept
**Author:** Claude, commissioned by Marinus
**Date:** 11 August 2026
**Scope:** initial setup for ryd; reusable for the OpenTMS next rebuild

---

## 1. Goal and principles

A software development department of AI agents running entirely on infrastructure outside the founder's own machine (GitHub + Anthropic cloud), where Marinus keeps three roles:

1. Writing product backlog items (PBIs) in GitHub
2. Operating two gates: design approval and PR review
3. Curating the rulebook (conventions, lessons learned)

Core principles:

- **First-time-right over speed.** Building only starts once the intake and design phases have established that the feature is fully specified. Iterations on a PR are a failure of intake, not "just how it works".
- **Permission boundaries are technical, not agreements.** Agents cannot merge, cannot deploy to production, and cannot reach secrets they don't need.
- **Everything is a file in git.** Agent definitions, conventions, design documents, lessons learned — versioned, reviewable, with history.
- **Failure is visible.** Every agent run logs to a central place; a daily digest shows what ran, what failed, and what is waiting on Marinus.

---

## 2. Where does this run? (honest note up front)

"On Anthropic infrastructure" is currently partially achievable, and that must be explicit:

| Workload | Runs on | Why |
|---|---|---|
| Event-driven agents (issue → design, PR comment → fix) | **GitHub Actions** with `anthropics/claude-code-action` | The only mature event-driven integration. Runs on GitHub infra (not your machine); model calls go to Anthropic. |
| Scheduled tasks (nightly audit, retrospective, digest) | **Claude Code cloud tasks** (Anthropic infra) or GitHub Actions `schedule` | Cloud tasks run on Anthropic infrastructure, even when everything on your side is off. |
| Interactive work (you + Claude Code) | Local or Claude Code on the web | For the things you do yourself. |

Practical consequence: the center of gravity is GitHub Actions. That satisfies the real requirement (nothing runs on own hardware, everything auditable) even though it is strictly GitHub infra with Anthropic models. Where Anthropic's cloud tasks suffice, we use those.

Billing: automation at this scale belongs on an **API key via Claude Platform** (separate workspace "dev-department" with a budget cap), not on a personal subscription. Predictable costs, hard cap, per-agent visibility in the console.

---

## 3. Repository structure

**One repository for the department, separate repositories per product.**

```
github.com/<org>/
├── dev-department/            ← the "department" itself
│   ├── agents/                ← all agent definitions (markdown + frontmatter)
│   ├── workflows/             ← reusable GitHub Actions workflows
│   ├── conventions/           ← CLAUDE.md building blocks: architecture, code, test, security
│   ├── templates/             ← PBI template, design doc template, retrospective template
│   ├── lessons/               ← curated lessons learned (see §9)
│   └── docs/                  ← this document, runbooks, product onboarding
│
├── ryd/                       ← product repo 1
│   ├── .claude/               ← thin layer: references dev-department + product-specific
│   ├── .github/workflows/     ← thin callers of the reusable workflows
│   ├── CLAUDE.md              ← product-specific conventions + import of department conventions
│   └── src/ ...
│
└── opentms-next/              ← product repo 2 (later)
```

Mechanism: product repos consume the department via (a) **reusable workflows** (`uses: <org>/dev-department/.github/workflows/design.yml@main`) and (b) a sync step that fetches `agents/` and `conventions/` fresh on every run. An improvement to an agent is thereby immediately active in all products, without submodule friction. The department is literally what a department should be: shared people (agents), shared way of working (workflows), shared culture (conventions) — across products.

### 3.1 Product onboarding: the domain map

The department is domain-agnostic: agents know the *mechanism* (modules with hard boundaries, implementers scoped per domain, cross-domain only via events/contracts), not the domains themselves. Each product therefore delivers a **domain map** in its CLAUDE.md at onboarding — mandatory artifact; no map, no agents on the product.

The domain map contains, per domain: name, responsibility in one sentence, the key entities, and the published events/interfaces to other domains. In addition, every map names one **horizontal platform layer** (not a business domain): ABP core (identity, permissions, tenancy, localization, audit), mail delivery, long-running task management, generic document generation/storage, and notifications. Rule: the dependency arrow always points downward — the platform knows no business domain. Platform changes always pass the design gate and are treated by the reviewer as risk class critical by default, because every domain depends on them. The map belongs to the PO; agents may *propose* splits or shifts (via the retrospective route), never apply them.

**ryd starter map** (deliberately coarse — a greenfield app splits modules when they pinch, not up front):

| Domain | Responsibility | Core entities |
|---|---|---|
| **Orders** | Intake (incl. mailbox scanning as adapter), order lifecycle, acceptance | Order, OrderLine, IntakeSource |
| **Planning & Route** | Combining accepted trips, route optimization (Valhalla/VROOM as external service) | Trip, Stop, RoutePlan |
| **Execution & POD** | En-route status, delivery, capturing and sharing POD with parties | Execution, POD, StatusEvent |
| **Invoicing** | Direct or batched invoicing, delivery, payment status | Invoice, InvoiceLine, Batch |
| **Master Data** | Relations, addresses, vehicles, driver/user | Relation, Address, Vehicle |
| *Platform (horizontal)* | ABP core, mail, background jobs, document generation, notifications | — |

Cross-domain flows run via events: `OrderAccepted` → Planning; `DeliveryCompleted` → Invoicing and party notification.

**OpenTMS next map** (six domains + platform; goes into the CLAUDE.md of opentms-next at onboarding):

| Domain | Responsibility |
|---|---|
| **Orders** | Intake via all channels, order lifecycle |
| **Planning & Execution** | Planboard, trips, assignment, realtime status, POD, track & trace |
| **Financial** | Internal modules: Tariffs & Calculation, Invoicing, Purchasing/Carrier settlement, Transport-unit balances |
| **Master Data** | Relations, addresses, vehicles, drivers |
| **Integrations** | EDI, OTM5, accounting links, partner links; anti-corruption layer |
| **Reporting** | Dashboards (incl. LOS), data warehouse, sustainability/CO₂; read-only |
| *Platform (horizontal)* | As with ryd |

The current app tiles (Planboard, Finance, portals, …) remain as UI navigation structure; they are views on these domains, not modules. Heavyweights such as Financial and Planning & Execution keep a strict internal submodule structure so that a later split is a deployment decision, not a rebuild.

---

## 4. The agents — roles and SaaS/GCP best practices

All agents are markdown definitions in `dev-department/agents/`. Per agent: role, system prompt, allowed tools, and an enforced output format, so the chain stays machine-readable.

### 4.0 Department-wide SaaS constitution

These rules live in `conventions/saas-constitution.md` and are part of *every* agent prompt. They are not negotiable per feature; an agent wanting to deviate must mark it explicitly in its output so it is visible at a gate.

1. **Tenant isolation is sacred.** Every query, job, export and log line is tenant-scoped (ABP data filter). Disabling the filter (`IgnoreMultiTenancy`) is only allowed with a documented reason in a code comment *and* the design doc. Cross-tenant data leaks are the cardinal sin of SaaS — one incident costs more trust than a hundred features build.
2. **Zero downtime is the default.** Migrations follow expand/contract (roll out additively first; remove the old column/endpoint only in a later release once nothing depends on it). API changes are backwards-compatible; breaking changes only through versioning.
3. **Everything idempotent and restartable.** Hangfire jobs, webhooks and integration consumers must tolerate double execution without double invoices, mails or orders. External calls use retry-with-backoff and an outbox pattern where ordering matters.
4. **Feature flags decouple deploy from release.** New behavior goes behind a flag, activatable per tenant. This is also the canary mechanism: first the own health tenant, then friendly customers, then everyone.
5. **Privacy by design.** No PII in logs (tenant id and entity ids yes; names/addresses/license plates no). Every new entity holding personal data gets an answer at design time to: does this fall under export/erasure requests (GDPR art. 15/17), and how?
6. **Cost is a design criterion.** GCP resources (extra Cloud SQL capacity, egress, Cloud Run min instances, external API calls per order) are estimated at design time. A feature that noticeably affects per-tenant margin must state so at gate 1.
7. **Least privilege everywhere.** New service-to-service access via Workload Identity and a specific IAM role, never a widened existing role "because it's faster".

### 4.1 intake agent

**Role:** gatekeeper of the Definition of Ready. Judges whether a PBI *can* be built first-time-right.

**Method:** checks the PBI against a fixed checklist and outputs either `ready` with a filled-in summary, or a numbered list of concrete questions as an issue comment. Never interprets charitably; when in doubt, ask.

**SaaS-specific checks:**
- Which functional domains are affected, and is the PBI small enough for one design (otherwise: split proposal)?
- Tenant dimension: behavior identical for all tenants, or configurable per tenant/subscription tier?
- Edge cases named: empty states, concurrency (two planners, same trip), failure paths of external parties?
- Non-functionals: expected volume (orders/day), latency expectation, offline behavior (mobile)?
- Privacy: new personal data? If so, a GDPR paragraph in the design is mandatory.
- Rollout: can this go behind a feature flag, and is there a migration path for existing tenant data?

**May:** read repo and issues, post comments, set labels. **May not:** write code, rewrite the PBI itself (proposing is fine, changing is not — the PBI belongs to the PO).

### 4.2 architect agent

**Role:** translates a `ready` PBI into a verifiable solution design for backend *and* UI. Output: design doc as a PR to `docs/designs/`, following a fixed template.

**Mandatory sections in every design:**
- **Domain impact**: which modules, which new/changed entities, which events between domains.
- **API contract**: endpoints with request/response types — after approval this becomes the source for the typed client, so frontend and backend build against the same contract.
- **Migration strategy**: expand/contract steps written out explicitly, including the "contract" step that may only happen releases later.
- **UI design**: screens, components (reuse from the existing library first), states (loading/empty/error), and which interactions get optimistic updates.
- **Test risk analysis**: a risk class per part (see test engineer) — the architect determines the risk, the test engineer the execution.
- **Flag and rollout plan**: flag name, default, activation order.
- **Cost & SLO impact**: estimated infra impact; does this touch an existing SLO?
- **Assumptions**: everything assumed is listed here, explicitly — this is what Marinus verifies at gate 1.
- **Security quickscan**: new permissions (ABP permission definitions), input validation boundaries, and whether the attack surface changes.

**Best practices the architect guards:** respect modular monolith boundaries (cross-domain communication via events/interfaces, never direct DbContext access cross-module); no new external dependencies without motivation; ABP conventions (application services, DTOs, permission model) over own inventions.

**May:** read repo, open design PR. **May not:** change application code.

### 4.3 implementer-backend

**Role:** builds exactly the approved design, per functional domain, in its own branch/worktree.

**Best practices (enforced via prompt + reviewer):**
- ABP patterns: application services + DTOs, domain services for domain logic, repositories — no raw SQL outside documented performance exceptions.
- EF Core: only additive migrations in this phase (expand); queries always paged; no lazy-loading surprises (explicit includes); new queries assessed at expected volumes (an index is part of the migration).
- Structured logging with correlation id on every service boundary and in every Hangfire job; log levels per convention (no `LogError` for expected business failures).
- Every new permission via ABP permission definitions, never a hardcoded check.
- Deviating from the design silently is not allowed: blocked → report on the issue, don't redesign on the fly.

**May:** write code in the feature branch, build, run tests. **May not:** write outside its own domain, change the API contract without referring back to design, merge.

### 4.4 implementer-frontend

**Role:** builds the UI from the design, exclusively against the generated typed API client.

**Best practices:**
- Data fetching via the standard query layer (caching, invalidation, retry) — never loose fetches; server-side paging/filtering on all lists, never client-side filtering of full datasets.
- Optimistic updates on the interactions the design designates; every mutation has a visible failure path (no silent failures).
- Component reuse first: existing library → shadcn/ui base → only then new, and new means adding to the library, not a one-off loose component.
- States complete: loading, empty, error and permission-denied are part of every screen, not an afterthought.
- Translatable strings via the localization API from line one — no hardcoded texts to "translate later".

**May/may not:** as the backend implementer, within the frontend.

### 4.5 test engineer

**Role:** translates the design's risk analysis into test cases, classifies, implements and runs them.

**Risk-based matrix (fixed department asset):**

| Risk class | Examples | Mandatory coverage |
|---|---|---|
| **Critical** | money (invoicing, tariffs), tenant isolation, authorization | integration tests against real PostgreSQL + E2E on the core flow + negative tests (can I reach tenant B's data?) |
| **High** | order chain, planning, external integrations | integration tests + contract tests on the API |
| **Medium** | UI flows, reporting | component tests + targeted E2E |
| **Low** | static screens, texts | unit/snapshot |

**SaaS-specific obligations:**
- **Tenant isolation tests are standard** for every feature that reads/writes data: demonstrably no access to another tenant's data, including via list endpoints and exports.
- **Migration test**: every migration runs in CI against a copy of a production-like schema *with data*, and the old application version must keep working against the new schema (expand guarantee).
- **Idempotency tests** for jobs and webhooks: run twice, one effect.
- The regression suite (core journeys, defined by Marinus — see open choice 4) is owned by this agent and grows with every critical-class item.

**May:** write test code, use test infra. **May not:** "quickly fix" application code — a found bug goes back to the implementer as a finding.

### 4.6 reviewer agent

**Role:** last automated check before Marinus. Checklist-driven, with the design doc as the yardstick.

**Checklist (core):** conformity to design and conventions; tenant filter usage (every `IgnoreMultiTenancy` marked?); N+1 queries and missing paging; secrets or PII in code/logs; error handling on every external call; test coverage per risk class; migrations additive; new dependencies motivated; feature flag present per rollout plan.

**Output:** review comments per finding with severity (blocker/major/minor), and the `approved-by-agent` label only when there are no blockers. Blockers go back to the implementer *before* the PR reaches Marinus — gate 2 should only ever see new kinds of mistakes, never repeat mistakes.

**May:** read PR, comment, label. **May not:** approve on behalf of a human, merge, push code.

### 4.7 release manager

**Role:** guards the path from merge to production.

**Platform (Cloud Run):**
- Deploy per merge after green regression, as a new revision with **traffic splitting**: first a small percentage, automatic promotion to 100% if error rate and latency stay within SLO during the observation window; otherwise automatic rollback + issue.
- Guards the **contract calendar**: "contract" migration steps (removing a column/endpoint) are only scheduled once the corresponding expand is at least one release old and demonstrably unused.

**Mobile (release train Tue/Fri):**
- Collects merged, flag-carried features; versioning, changelog, store metadata; prepares submission (final submit click stays with Marinus until store confidence is built).
- Guards API compatibility with old app versions in the field: an endpoint may only change breakingly once the minimum supported app version no longer uses it.

**May:** trigger release workflows, tags/changelogs, traffic promotion within the defined criteria. **May not:** deploy on red regression, skip gates, advance contract steps, let feature releases through for an area whose error budget is spent (§6, layer 0).

### 4.8 devops agent

See §6 for the full design. Summarized: SLO-driven triage and diagnosis, synthetic journeys per core flow, nightly audits (slow queries, cost anomalies, CVEs), and as the only autonomous production action: rollback to the previous revision.

### 4.9 retrospective agent

**Role:** per completed PR, analyze the diff between agent output and the merged final version plus review comments; *only* on a repeatable pattern, open a proposal PR to `lessons/` or `conventions/`.

**Bar:** "which mistake happens again without this rule?" — most PRs yield *no* lesson, and that is the intent. Proposals distinguish scope: department-wide (SaaS constitution or conventions) versus product-specific (the product's CLAUDE.md).

**May:** read closed PRs and reviews, open proposal PRs to dev-department. **May not:** change conventions directly.

### 4.10 documentation agent

**Role:** keeps three documentation layers current (see §7): functional end-user documentation, integrator documentation, and the internal engineering overview.

**Method per feature:** generates from PBI + design doc a draft manual page (step-by-step, in user language — screen terms, not entity names) and delivers it as part of the feature PR, so gate 2 reviews code and documentation together. After deploy to the demo environment it triggers the screenshot workflow (§7.1) and replaces placeholder images with current captures.

**Best practices:**
- Documentation describes behavior, never implementation; if the agent needs an implementation detail to explain something, that is a UX finding that goes back into the PR as a comment.
- Multilingual from the source: pages in a translatable structure; source language Dutch (OpenTMS) resp. English (ryd), translations as a separate generation step with human spot checks.
- Integrator documentation is not written but **derived**: OpenAPI is the source; the agent only writes the guides around it (authentication, webhooks, example flows) and keeps them consistent with the generated contract.

**May:** write in `docs/`, trigger the screenshot and publication workflows. **May not:** change application code or API contracts; publish documentation of flagged features before activation.

---

## 5. The pipeline (issue-driven state machine)

GitHub Issues are the source of truth; labels are the state. Every transition is a GitHub Actions trigger.

```
PBI created (template: "As a <role> I want <goal> because <reason>")
        │
        ▼
[status: intake]  → intake agent runs
        │
        ├─ incomplete → questions as comment → Marinus completes → intake again
        │
        ▼
[status: design]  → architect agent runs → design PR
        │
        ▼
══ GATE 1: Marinus approves design PR (merge) ══
        │
        ▼
[status: build]   → implementers (parallel per domain, own worktree/branch)
        │            → test engineer → reviewer
        ▼
      feature PR (contains: code, tests, reference to design doc)
        │
        ▼
══ GATE 2: Marinus reviews PR ══
        │
        ├─ comments → same PR, agent pushes fix commits, back to gate 2
        ├─ decline due to design flaw → back to [status: design], PR closed
        │
        ▼ merge
CI: build + regression tests
        │
        ├─ platform: automatic deploy to Cloud Run (per PR)
        ├─ apps: waits for release train (Tue/Fri), features behind flags
        ▼
[status: released] → retrospective agent runs → possibly proposal PR lessons
```

Agreements that keep this first-time-right:

- The intake agent is **strict**: when in doubt, ask questions; never interpret charitably. A PBI bouncing three times through intake is cheaper than one build iteration.
- The design doc has an explicit **"assumptions"** section — everything the architect had to assume is there, so gate 1 verifies those assumptions visibly.
- On PR comments: **same PR, new commits** (review history is learning data). A new PR only on a design flaw.
- Regression red *after* merge: **automatic rollback** to the previous Cloud Run revision + issue with diagnosis. No discussion, no waiting.
- **Documentation belongs to the feature**: the feature PR contains the manual draft (§7); the reviewer agent blocks PRs that change user behavior without a docs change.

---

## 6. DevOps: the platform finds errors, not the end user

One honest reframing up front: "always perfect" does not exist in engineering — what does: **explicit performance budgets, automatic monitoring, and a release stop the moment the budget is spent**. That is what follows. Three layers: the requirements themselves, the observability foundation, and the agent that acts on it.

**Layer 0 — performance requirements (the budgets):**

These numbers are defaults for review; they live in `conventions/performance-budgets.md` and every agent checks against them.

| Interaction class | Requirement | Enforcement |
|---|---|---|
| Interactive reads (grids, detail screens) | API p95 < 300 ms; screen interactive < 1 s | nightly load test (k6) per core endpoint with a budget; overrun = prioritized issue |
| Mutations (save, plan, accept) | API p95 < 500 ms; perceived latency ~0 via optimistic updates | same + reviewer check on optimistic update per design |
| Heavy operations (route optimization, reporting, batch invoicing) | always asynchronous with progress indication; never block a request > 2 s | reviewer blocker on synchronous heavy calls |
| Web frontend | Core Web Vitals: LCP < 2.5 s, INP < 200 ms; bundle-size budget per route in CI | CI failure on budget overrun |
| Mobile app | cold start < 2 s; core actions work offline-first with a sync queue (a driver in a warehouse has no signal) | E2E tests with network simulation |
| Availability of core flows | 99.9% per month (≈ 43 min budget), measured via synthetic journeys | SLO alerting on budget burn |

**The DevOps principle that guarantees this — the error budget gate:** the moment a core flow's error budget for the month is spent, the release manager automatically freezes feature releases for that area; only fixes and performance improvements may still pass until the budget recovers. This is the only construction that makes "user experience before features" enforceable rather than an intention — and it also forces the PO (you) to prioritize quality debt immediately instead of "after this feature".

**Performance in the pipeline, not after it:** the architect states expected volumes and affected budgets per feature (already in the design template); the test engineer delivers a performance test at expected volume ×5 for risk class critical/high; and traffic-splitting promotion (§4.7) tests latency and error rate against *these* budgets — a feature that breaks the budget never reaches 100% traffic.

**Layer 1 — foundation (one-time setup):**

- **Structured logging** (JSON) from ABP to Cloud Logging; correlation id through the whole chain (request → Hangfire job → external call).
- **Cloud Error Reporting** for automatic error grouping and deduplication.
- **Uptime checks + synthetic monitoring**: scheduled checks replaying the critical user journeys (log in, create order, generate invoice) against a health tenant — errors are found before a real user hits them.
- **SLOs with alerting**: latency p95, error rate, and an availability SLO per core flow. Alert on budget burn, not on every hiccup.
- **Cloud Run**: startup CPU boost, health/readiness probes, revision-based deploys (rollback = restore previous revision).

**Layer 2 — the devops agent:**

Trigger: alert webhook (Cloud Monitoring → GitHub `repository_dispatch`) or scheduled run (nightly audit).

1. **Triage**: fetch log context around the error (via a read-only GCP service account), deduplicate against open issues, classify severity.
2. **Diagnosis**: create an issue *with* analysis: stack trace, affected module, suspected cause, related recent deploys.
3. **Self-resolution, within strict limits:**
   - Error correlates with a recent deploy → **rollback** to the previous revision (the only production action the agent may take autonomously) + issue.
   - Known, safe error class (e.g. a missing index flagged by query analysis, memory limit too tight) → **fix as PR** through the normal pipeline. Never straight to production.
   - Everything else → issue with diagnosis, priority label, and on severity "critical" a notification to Marinus (mail/Slack).
4. **Nightly audit**: slow queries, error ratios per endpoint, GCP cost anomalies, dependency vulnerabilities → findings as issues in the normal backlog stream.

Hard boundary: the devops agent has **read-only** access to GCP plus exactly two write rights: revision rollback and triggering the existing deploy workflow. No gcloud carte blanche.

---

## 7. Documentation: three layers, three audiences

Documentation is part of the definition of done, not an afterthought: a feature PR without a corresponding documentation change is incomplete (reviewer agent checks this).

### 7.1 Functional — end users

**Form:** docs-as-code. Manual pages as markdown in the product repo (`docs/manual/`), published as a static website (Docusaurus or Astro Starlight) via normal CI to Cloud Run/GitHub Pages — searchable, multilingual, one page per feature with step-by-step instructions.

**Screenshots without manual work — the core mechanism:** the E2E suite (Playwright) gets a screenshot mode that runs against a **demo tenant with fixed seed data** and captures the steps of the documented flows as images on every release. Consequences:
- Screenshots are always current; a UI change that breaks a documented flow breaks the screenshot run and is thus a CI signal instead of silent documentation rot.
- The demo tenant is the same one synthetic monitoring (§6) uses — one seed set, two purposes.
- Documenting a new feature = adding a screenshot scenario, which the test engineer and documentation agent do together (the scenario largely *is* the E2E test).

**Publication rhythm:** documentation of flagged features is built but only published at flag activation — the release manager couples docs publication to the rollout, so users never read about buttons they don't have yet.

### 7.2 Technical — integrators

**Source of truth is the generated OpenAPI contract** from ABP, published on a developer portal (same static-site approach, `docs/api/`):
- Reference documentation generated from OpenAPI, per API version.
- **Breaking-change detection in CI**: every PR diffs its OpenAPI against the published version; a breaking change without a version bump is a blocker. This gives the release manager the mechanism to make the compatibility promise to integrators (and old app versions) hard.
- Hand-written guides around it — authentication/OpenIddict, webhooks, OTM5 integration, example flows with payloads — maintained by the documentation agent, kept consistent with the contract.
- Changelog per release with explicit deprecation windows (linked to the contract calendar of §4.7).

### 7.3 Technical — internal engineers (humans following the agents)

Largely present in this design already; here made explicit as one coherent whole:
- **Why**: design docs in `docs/designs/` (per feature) and ADRs (per architecture decision) — the decision history.
- **What**: issues and PRs as the complete audit trail of agent work; the daily digest as the summary.
- **How it fits together**: an automatically generated architecture overview — domain map, events between modules, module dependency graph from the solution — refreshed on every merge. This is the page where a new (human) engineer or a due-diligence party starts.
- **Engineering changelog per release**: what was built, by which agent run, with links PBI → design → PR. Generatable from existing metadata; the documentation agent assembles it.

---

## 8. Guardrails and governance

- **Secrets**: GitHub Environments with secrets per environment; GCP access via Workload Identity Federation (no service-account keys in secrets). Agents get, per workflow, only the secrets that workflow needs.
- **Budget**: API workspace with a monthly cap; per agent a max-turns/max-budget per run in the workflow. An agent stuck in a loop costs at most one run budget.
- **Concurrency**: one build run per issue at a time (GitHub concurrency groups) — prevents a re-trigger causing duplicate work or merge conflicts.
- **Daily digest** (cloud task, 07:00): what ran, what failed, which issues/PRs wait on Marinus, budget status. One mail; silence never means "all good" but "digest broken".
- **Kill switch**: one repository variable `AGENTS_ENABLED=false` that all agent workflows check at the start.
- **Branch protection**: main requires human review + green CI; agents technically excluded from merging and from pushes to main.

---

## 9. Learning mechanism

- `lessons/` in dev-department is the curated memory: short rules with date, cause (link to PR) and scope (department-wide or product-specific).
- The retrospective agent makes **proposals** (PRs); Marinus approves. Bar: "which mistake happens again without this rule?" — no lesson per PR when there is no lesson.
- Quarterly pruning (scheduled run): rules that were not relevant in reviews for 3 months → removal proposal.
- Product repos import department conventions + their own CLAUDE.md; product-specific lessons stay in the product.

---

## 10. Deliberately NOT in v1

- **Autonomous production fixes** beyond rollback — too much blast radius, too little track record.
- **Auto-merge on green checks** — gate 2 stays human until the system has proven itself for months.
- **Multiple parallel features through the same domain** — merge conflicts between agents are unsolved territory; serialize per domain.
- **The spec agent as a separate role** — intake + architect cover this; add it once PBIs demonstrably cost Marinus too much time.

## 11. Rollout order

1. **Week 1**: dev-department repo, conventions v1, intake + reviewer agent on ryd, digest. (Smallest valuable whole: every PBI gets checked, every PR pre-reviewed.)
2. **Weeks 2–3**: architect + design gate; then implementer/test on one low-risk domain. Docs site skeleton (7.1) and OpenAPI publication (7.2) stand from here, so the documentation agent participates from the first real feature.
3. **Week 4+**: release manager, devops layer 1, then devops agent triage-only. Screenshot workflow once the first E2E flows exist.
4. **Only after that**: devops self-resolving (rollback), retrospective automation, onboarding the second product.

---

## Open choices for review

1. **Notification channel** for digest and critical alerts: mail, Slack, or GitHub-only?
2. **Design gate rhythm**: review as soon as ready, or also at fixed moments (like the 2×/week content gate)?
3. **App release train Tue/Fri**: confirm, or adjust to store review lead times?
4. **Regression suite ownership**: the test engineer agent builds it, but who determines what a "core user journey" is — a fixed list from Marinus, or derived from design docs?
5. **Budget ceiling** per month for the department?
6. **Documentation languages**: which languages at launch for the ryd manual (target markets suggest at least EN/DE/PL/FR/ES/PT — but each one is maintenance), and does OpenTMS documentation stay NL-only?
7. **Performance budgets** (§6, layer 0): confirm or adjust the proposed numbers — especially the 99.9% (43 min/month): tighter is more expensive, both in infra and in frozen releases.
