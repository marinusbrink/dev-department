# Design: <feature name>

**PBI:** <link to issue>
**Status:** draft | in review | approved
**Date:** <YYYY-MM-DD>

<!-- All nine sections below are mandatory (design §4.2). "Not applicable" is an
     acceptable answer only with a one-line reason; a missing section is not.
     Gate 1 approves this document by merging the PR — after that, implementers
     build exactly this, so vagueness here becomes iteration later. -->

## Domain impact

<!-- Which modules, which new/changed entities, which events between domains. -->

## API contract

<!-- Endpoints with request/response types — after approval this becomes the source for the typed client, so frontend and backend build against the same contract. -->

## Migration strategy

<!-- Expand/contract steps written out explicitly, including the contract step that may only happen releases later. -->

## UI design

<!-- Screens, components (reuse from the existing library first), states (loading/empty/error/permission-denied), and which interactions get optimistic updates. -->

## Test risk analysis

<!-- A risk class (critical/high/medium/low, per the test matrix in §4.5) per part — the architect determines the risk, the test engineer the execution. -->

## Flag & rollout plan

<!-- Flag name, default, activation order (health tenant → friendly tenants → all), and the migration path for existing tenant data. -->

## Cost & SLO impact

<!-- Estimated infra impact (Cloud SQL, egress, Cloud Run min instances, external calls per order); which performance budgets and SLOs does this touch? -->

## Assumptions

<!-- Everything assumed while designing, listed explicitly — this is what gets verified at gate 1. -->

## Security quickscan

<!-- New permissions (ABP permission definitions), input validation boundaries, attack surface changes; for new personal data: the GDPR art. 15/17 answer. -->
