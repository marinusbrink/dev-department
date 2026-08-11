# Coding conventions

Starter version (design §4.3, §4.4). This file grows through the lessons mechanism — a rule earns its place by preventing a repeated mistake, not by being imaginable. Deviations follow the same escape hatch as the [SaaS constitution](saas-constitution.md): marked explicitly in your output, or blocked in review.

## Both sides

- Build exactly the approved design. Blocked or the design doesn't fit reality → report on the issue and stop; never redesign on the fly, never deviate silently.
- Stay inside your assigned domain. Cross-domain communication goes via events/interfaces per the domain map — never direct `DbContext` access into another module.
- The API contract in the design doc is the single source: backend implements it, frontend consumes it via the generated typed client. Changing the contract means going back to design, not editing both sides to match.

## Backend (.NET / ABP)

**ABP patterns**
- Application services + DTOs at the boundary; domain logic in domain services; data access via repositories. No raw SQL outside documented performance exceptions.
- Every new permission is an ABP permission definition checked via the authorization system — never a hardcoded role or id check.
- Follow ABP conventions (module structure, DI, localization resources) over own inventions.

**EF Core**
- Migrations are additive only in the expand phase; the contract step (drop/rename) is a separate, later release owned by the release manager.
- Every query on a collection is paged — no unbounded `ToListAsync()` on tenant data.
- Explicit `Include` for navigations; no lazy-loading surprises.
- A new query is assessed at the design's expected volume; if it needs an index, the index ships in the same migration.

**Logging**
- Structured logging with a correlation id on every service boundary and in every Hangfire job — the id travels request → job → external call.
- Log levels per convention: expected business failures (validation, domain rules) are not `LogError`; reserve error level for things a human should look at.
- No PII in log lines (constitution rule 5): tenant id and entity ids, never names/addresses/license plates.

## Frontend

**Data access**
- All server communication goes through the generated typed API client — no hand-written fetch calls, no hand-typed response shapes.
- Data fetching via the standard query layer (caching, invalidation, retry) — never loose fetches in components.
- Lists are server-side paged and filtered. Never pull a full dataset to filter client-side.

**Mutations and states**
- Optimistic updates on exactly the interactions the design designates.
- Every mutation has a visible failure path — no silent failures, ever.
- Every screen handles all four states: loading, empty, error, permission-denied. They are part of the screen, not an afterthought.

**Components and texts**
- Reuse order: existing component library → shadcn/ui base → only then new. New means adding to the library, not a one-off component in a page.
- Every user-facing string goes through the localization API from line one. No hardcoded texts to "translate later".
