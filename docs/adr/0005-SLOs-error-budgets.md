**ADR-005: Reliability Targets — SLOs and Error Budgets**

**Context:** The platform has dashboards for pod health, node resource usage, and ALB errors, but there are no clear limits for what is considered "acceptable." This makes it difficult to decide when a change is too risky or when on-call should be alerted. The platform needs clear and measurable reliability targets based on user impact, not just infrastructure metrics.

**Decision:** Define SLOs for each critical service, starting with the demo-app's availability and latency. SLOs will be measured as a percentage over a rolling 30-day period. Each SLO will have an error budget that controls how quickly changes can be released. If the error budget is being used too quickly, risky changes will be paused.

**Alternatives considered:**

* *Threshold-based alerting only (no SLOs)* — rejected as the current approach; alerts are based on individual metric thresholds without showing whether users are actually affected or whether the service is meeting its reliability target. This can lead to too many alerts or missed problems.
* *Vendor-default SLOs (e.g., generic 99.9% for everything)* — rejected; using the same target for every service does not account for different business importance and traffic patterns.

**Consequences:**

* Gain: creates a clear and shared definition of "healthy enough to release" and provides a consistent way to classify incidents.
* Cost: SLOs need regular review. Targets that are too loose are not useful, while targets that are too strict can cause unnecessary release freezes. Real production data will be needed to tune them.
* Follow-up: add error-budget burn-rate alerts for both fast and slow budget consumption instead of relying on one fixed threshold.
