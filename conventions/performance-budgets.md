# Performance budgets

These budgets (design §6, layer 0) are defaults for review: the architect states which budgets a feature touches, the test engineer tests against them, the reviewer blocks on violations, and traffic-splitting promotion measures against them in production.

> **Confirmed 2026-08-12 (choice 7):** every number in the table below — including the 99.9% availability target (≈ 43 min/month) — is the binding review default. The mobile rows are defined but dormant until ryd onboards. Changing a number is a PO edit to this file via a reviewed PR, never an agent decision.

| Interaction class | Requirement | Enforcement |
|---|---|---|
| Interactive reads (grids, detail screens) | API p95 < 300 ms; screen interactive < 1 s | nightly load test (k6) per core endpoint with a budget; overrun = prioritized issue |
| Mutations (save, plan, accept) | API p95 < 500 ms; perceived latency ~0 via optimistic updates | same + reviewer check on optimistic update per design |
| Heavy operations (route optimization, reporting, batch invoicing) | always asynchronous with progress indication; never block a request > 2 s | reviewer blocker on synchronous heavy calls |
| Web frontend | Core Web Vitals: LCP < 2.5 s, INP < 200 ms; bundle-size budget per route in CI | CI failure on budget overrun |
| Mobile app | cold start < 2 s; core actions work offline-first with a sync queue (a driver in a warehouse has no signal) | E2E tests with network simulation |
| Availability of core flows | 99.9% per month (≈ 43 min budget), measured via synthetic journeys | SLO alerting on budget burn |

## How an agent checks each row

- **Interactive reads** — k6 scenario per core endpoint in the nightly workflow, with the budget encoded as a k6 threshold (`http_req_duration: ['p(95)<300']`) so an overrun fails the run mechanically; the agent reads the k6 summary JSON and opens a prioritized issue. At design time: the reviewer checks that every new list query is paged and that the migration ships the indexes the stated volume needs.
- **Mutations** — same k6 thresholds (`p(95)<500`). Additionally the reviewer diffs the design's optimistic-update list against the frontend mutation hooks: every designated interaction updates optimistically, every mutation has a visible failure path.
- **Heavy operations** — the reviewer flags any controller/app-service that invokes route optimization, reporting, or batch invoicing synchronously (blocker). The test engineer asserts the endpoint enqueues a Hangfire job and returns immediately (202 / job id), and an E2E step asserts progress indication is shown.
- **Web frontend** — Lighthouse CI assertions for LCP/INP and a per-route bundle-size budget in the frontend CI job; the build fails on overrun, so no agent judgment is involved — the agent's job is to fix, not to argue.
- **Mobile app** — E2E suite runs core actions with network simulation: airplane-mode scenarios must queue mutations and sync on reconnect; a profiling step measures cold start against the 2 s budget on the release train.
- **Availability of core flows** — synthetic journeys (log in, create order, generate invoice) run on schedule against the health tenant; Cloud Monitoring SLO burn-rate alerts fire a `repository_dispatch` that triggers the devops agent for triage.

## The error budget gate

When a core flow's error budget for the month is spent, the release manager **freezes feature releases for that area**: only fixes and performance improvements pass until the budget recovers. This is what makes "user experience before features" enforceable rather than an intention.
