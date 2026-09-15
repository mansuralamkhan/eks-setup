**ADR-002: Policy Enforcement Mode — Kyverno Audit vs Enforce**

**Context:** New admission policies, such as blocking `:latest` image tags, could break existing deployments if enabled immediately. Some older manifests and CI pipelines may not follow the new rules. The platform needs a safe rollout process that shows violations without causing outages, while still moving to full enforcement within a defined timeframe.

**Decision:** Roll out every new policy in `Audit` mode first. Generate PolicyReports for two weeks, fix the reported issues with the responsible teams, and then switch the policy to `Enforce` mode on a planned cutover date communicated in advance.

**Alternatives considered:**

* *Enforce immediately* — rejected; could block valid deployments without warning and create avoidable urgent issues.
* *Permanent audit-only mode* — rejected; provides visibility but does not actually prevent violations, which defeats the purpose of admission control.

**Consequences:**

* Gain: policies can be introduced without unexpected outages, and teams get time to see and fix violations before enforcement.
* Cost: policies do not actively block violations during the two-week audit period. Reviewing and following up on PolicyReports also requires manual effort unless the process is automated.
* Follow-up: automate PolicyReport summaries, such as a weekly digest, so teams do not miss audit findings.
