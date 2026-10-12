ADR-009: Disaster Recovery — Multi-AZ EKS with Velero Backups

**Status:** Accepted · Partially implemented. Multi-AZ subnets and node placement exist in `01-foundation` (single NAT gateway, one-node baseline). Velero resource backups are defined (`01-foundation/velero.tf`, `05-gitops/apps/velero.yaml`); the first restore drill has not been run.

Context: The platform's initial single-AZ design left it exposed to a full outage from a single AZ failure, and there was no tested mechanism to recover cluster state (workloads, PVs, config) if the cluster itself were lost or corrupted.

Decision: Run EKS across multiple AZs for node-level resilience, and use Velero for scheduled backups of Kubernetes resources and persistent volume snapshots, with periodic restore drills into a separate cluster to validate the backups are actually usable.

Alternatives considered:

Single-AZ with manual backup scripts — rejected as the prior state; cheaper but leaves both availability and recoverability exposed to a single point of failure.
Cross-region active-active — considered for maximum resilience; rejected for this build as disproportionate to actual requirements and cost, given the platform doesn't yet have a business requirement for region-level failover.

Consequences:

Gain (target state): survives an AZ failure without downtime once the node baseline spans AZs (today: one managed node, one NAT gateway), and has a tested path to recover cluster state rather than an untested backup that might fail silently when actually needed.
Cost: multi-AZ increases baseline infrastructure cost (cross-AZ data transfer, redundant capacity); Velero backups add storage cost and require periodic restore drills to stay trustworthy.
Follow-up: schedule quarterly restore drills as a standing task — an untested backup is not a real backup.

### NAT Gateway trade-off

The foundation currently uses a single NAT Gateway for outbound internet
access from private subnets. This reduces baseline infrastructure cost but
creates a single-AZ dependency for private-subnet egress.

The EKS network remains multi-AZ, but outbound connectivity is not fully
AZ-independent.

A production deployment with a requirement for AZ-independent egress should
use one NAT Gateway per AZ or another highly available egress architecture.
\

### Scope today

Velero backs up Kubernetes **resources** (manifests, CRDs, config) on a daily schedule with a 72-hour TTL. Persistent volume snapshots are disabled because the cluster has no stateful workloads yet. The restore procedure and a table for drill timings are in `docs/runbooks/restore-drill.md`.
