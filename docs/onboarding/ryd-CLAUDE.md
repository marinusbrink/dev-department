# CLAUDE.md — ryd

<!-- Ready-to-copy from dev-department/docs/onboarding/ryd-CLAUDE.md.
     Fill every TODO(fill-from-repo) stub from the actual codebase before
     onboarding sign-off. The domain map below is the mandatory onboarding
     artifact (§3.1): no map, no agents. -->

ryd is a multi-tenant transport SaaS operated by the dev-department agents. This file is the product-specific layer; the department conventions bind on top of it.

## Department conventions (binding)

In agent runs, the department repo is synced fresh at `.dev-department/` (never commit that directory). The following bind every agent and every human contributor:

- `.dev-department/conventions/saas-constitution.md` — part of every agent prompt, no exceptions
- `.dev-department/conventions/coding-conventions.md`
- `.dev-department/conventions/performance-budgets.md`
- `.dev-department/lessons/` — every approved lesson has the force of a convention

Working locally? Read them at [github.com/marinusbrink/dev-department](https://github.com/marinusbrink/dev-department) — CI always syncs `@main`.

## Domain map (owned by the PO — agents propose changes via the retrospective route, never apply them)

Deliberately coarse: a greenfield app splits modules when they pinch, not up front.

| Domain | Responsibility | Core entities | Publishes |
|---|---|---|---|
| **Orders** | Intake (incl. mailbox scanning as adapter), order lifecycle, acceptance | Order, OrderLine, IntakeSource | `OrderAccepted` |
| **Planning & Route** | Combining accepted trips, route optimization (Valhalla/VROOM as external service) | Trip, Stop, RoutePlan | — (to be defined as flows emerge) |
| **Execution & POD** | En-route status, delivery, capturing and sharing POD with parties | Execution, POD, StatusEvent | `DeliveryCompleted` |
| **Invoicing** | Direct or batched invoicing, delivery, payment status | Invoice, InvoiceLine, Batch | — |
| **Master Data** | Relations, addresses, vehicles, driver/user | Relation, Address, Vehicle | — |
| *Platform (horizontal)* | ABP core (identity, permissions, tenancy, localization, audit), mail delivery, background jobs (Hangfire), document generation/storage, notifications | — | — |

**Cross-domain flows** run via events, never via direct `DbContext` access across modules:

- `OrderAccepted` (Orders) → Planning & Route
- `DeliveryCompleted` (Execution & POD) → Invoicing **and** party notification (Platform)

**Platform rule** (§3.1): the dependency arrow always points downward — the platform knows no business domain. Platform changes always pass the design gate and are risk class **critical** by default.

## Stack

TODO(fill-from-repo): ABP framework version, .NET version, EF Core/PostgreSQL versions, frontend framework and component library, mobile stack, repository/solution layout (where each domain's module lives).

## Build & test commands

TODO(fill-from-repo): solution build command, backend test command (unit / integration against PostgreSQL), frontend test command, E2E command, how to run the app locally with a seeded tenant.

## Deploy

TODO(fill-from-repo at onboarding phase 3): Cloud Run service names, deploy workflow, demo environment, health tenant. Until the release workflows exist, deploys are human-only.

## Product-specific conventions

None yet — this section grows only via the lessons mechanism (retrospective proposals scoped `product-specific`, approved by the PO). It starts empty by design.
