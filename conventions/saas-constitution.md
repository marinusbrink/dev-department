# SaaS constitution

These seven rules are part of **every** agent prompt in this department (design §4.0). They are not negotiable per feature.

**The escape hatch — the only legitimate way to deviate:** if a task genuinely requires breaking a rule, you MUST mark the deviation explicitly in your output — in the PR description and as an issue comment — using this exact format, so it is visible at a gate:

```
DEVIATION(constitution-<rule-number>): <one-line reason>, approved in <design doc reference>
```

A deviation that is not marked, or marked but absent from the approved design doc, is a reviewer **blocker**. Deviating silently is worse than the deviation itself.

---

## 1. Tenant isolation is sacred

Every query, background job, export, and log line MUST be tenant-scoped through the ABP data filter. You MUST NOT disable it (`IgnoreMultiTenancy`, `IDataFilter.Disable<IMultiTenant>()`) unless the reason is documented in a code comment at the call site **and** in the approved design doc. Cross-tenant data leaks are the cardinal sin of SaaS — one incident costs more trust than a hundred features build.

- **Violation:** a lookup in `OrderAppService` wraps `_dataFilter.Disable<IMultiTenant>()` around the query "to make a support case easier", with no comment and no mention in any design doc.
- **Correct:** a host-level usage report runs cross-tenant inside `HostReportingService`, wrapped in `_dataFilter.Disable<IMultiTenant>()` with the comment `// Cross-tenant by design: host usage report — docs/designs/2026-09-usage-report.md, §Domain impact`, and that design section says the same.

## 2. Zero downtime is the default

Schema migrations MUST follow expand/contract: in this release you may only add (columns, tables, endpoints); renames and removals happen in a **later** release, once nothing demonstrably depends on the old shape. API changes MUST be backwards-compatible; breaking changes only through a new API version.

- **Violation:** one migration renames `Orders.DeliveryDate` to `PlannedDeliveryDate` (drop + add) in the same PR as the code change — during Cloud Run traffic splitting, the still-running old revision crashes on the missing column.
- **Correct:** release N adds `PlannedDeliveryDate`, the code dual-writes and a Hangfire job backfills; the contract migration dropping `DeliveryDate` is a separate PR that the release manager schedules at least one release later.

## 3. Everything idempotent and restartable

Hangfire jobs, webhook handlers, and integration consumers MUST tolerate double execution without double effects — no duplicate invoices, mails, or orders. External calls MUST use retry-with-backoff; where ordering matters, use an outbox.

- **Violation:** `GenerateInvoiceBatchJob` loops over orders and inserts an invoice per order with no natural key; when the job is retried after a crash mid-batch, the first half of the orders is invoiced twice.
- **Correct:** `Invoice` carries a unique index on `(TenantId, OrderId, BillingPeriod)` and the job checks-then-inserts; the webhook consumer records processed event ids in an inbox table and silently skips an id it has already seen.

## 4. Feature flags decouple deploy from release

New user-visible behavior MUST go behind a feature flag (ABP feature management), default **off**, activatable per tenant. The flag is the canary mechanism: first the health tenant, then friendly customers, then everyone — in the activation order the design's rollout plan specifies.

- **Violation:** the implementer wires the new planning-board auto-assignment straight into the page component — it is live for every tenant the moment the PR merges and deploys.
- **Correct:** the behavior sits behind `Planning.AutoAssignment` checked via `IFeatureChecker`, default false; the design names the flag and activation order, and the release manager flips it for the health tenant first.

## 5. Privacy by design

You MUST NOT write PII to logs: tenant ids and entity ids yes; names, addresses, license plates, email addresses no. Every new entity holding personal data MUST answer, at design time, whether it falls under GDPR art. 15 (export) and art. 17 (erasure) requests, and how.

- **Violation:** `_logger.LogInformation("POD signed by {DriverName} at {Address}", pod.DriverName, pod.DeliveryAddress)` — driver name and delivery address now sit in Cloud Logging retention.
- **Correct:** `_logger.LogInformation("POD {PodId} captured for order {OrderId}", pod.Id, pod.OrderId)` — and the design introducing the `POD` entity states that signature images are included in art. 15 exports and erased on art. 17 requests, with the mechanism named.

## 6. Cost is a design criterion

GCP resource impact MUST be estimated at design time: extra Cloud SQL capacity, egress, Cloud Run min instances, external API calls per order. A feature that noticeably affects per-tenant margin MUST say so explicitly at gate 1.

- **Violation:** a design routes every order status update through a paid geocoding API, and no section states the expected call volume or cost per tenant.
- **Correct:** the design's Cost & SLO impact section reads: "route optimization calls VROOM once per plan action, ≈40 calls/day at expected volume; no change to Cloud Run min instances; egress negligible; per-tenant margin unaffected."

## 7. Least privilege everywhere

New service-to-service access MUST use Workload Identity and a specific IAM role on the specific resource. You MUST NOT widen an existing role or reuse a broad service account "because it's faster".

- **Violation:** to let the app store POD images, the shared runtime service account is granted `roles/storage.admin` on the whole project.
- **Correct:** a dedicated service account, bound via Workload Identity Federation, gets `roles/storage.objectCreator` scoped to the `ryd-pod-media` bucket only.
