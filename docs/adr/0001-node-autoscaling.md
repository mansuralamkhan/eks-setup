**ADR-001: Node Autoscaling — Karpenter vs Cluster Autoscaler**

**Context:** The platform runs workloads with changing traffic on EKS. Previously, Cluster Autoscaler could scale only within the fixed instance types configured in each ASG. This made scaling slower and sometimes resulted in poor use of node capacity during traffic spikes. The platform needs an autoscaler that can choose from different instance types and sizes based on demand and remove underused nodes to reduce compute costs.

**Decision:** Use Karpenter with custom NodePool and EC2NodeClass definitions.Karpenter will provision and consolidate nodes based on unschedulable pod requirements and NodePool scheduling constraints, instead of relying on pre-configured Auto Scaling Groups.
**Alternatives considered:**

* *Cluster Autoscaler with managed node groups* — rejected as the main approach; simpler to operate, but limited to the instance types configured in each node group and generally slower to respond to scaling needs.
* *Static over-provisioning* — rejected; provides guaranteed capacity but keeps extra compute running even when it is not needed, increasing costs.

**Consequences:**

* Gain: faster node provisioning, better use of available capacity, lower idle compute costs, and fewer ASGs to manage.
* Cost: an additional controller to operate and monitor. Karpenter also needs broader EC2 and IAM permissions than Cluster Autoscaler, which increases the potential impact of a misconfiguration.
* Follow-up: review consolidation settings after 60 days of real usage and adjust them to balance cost savings and workload disruption.
