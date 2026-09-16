ADR-009: Disaster Recovery — Multi-AZ EKS with Velero Backups

Context: The platform's initial single-AZ design left it exposed to a full outage from a single AZ failure, and there was no tested mechanism to recover cluster state (workloads, PVs, config) if the cluster itself were lost or corrupted.

Decision: Run EKS across multiple AZs for node-level resilience, and use Velero for scheduled backups of Kubernetes resources and persistent volume snapshots, with periodic restore drills into a separate cluster to validate the backups are actually usable.

Alternatives considered:

Single-AZ with manual backup scripts — rejected as the prior state; cheaper but leaves both availability and recoverability exposed to a single point of failure.
Cross-region active-active — considered for maximum resilience; rejected for this build as disproportionate to actual requirements and cost, given the platform doesn't yet have a business requirement for region-level failover.

Consequences:

Gain: survives an AZ failure without downtime, and has a tested path to recover cluster state rather than an untested backup that might fail silently when actually needed.
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