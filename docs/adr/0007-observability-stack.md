ADR-007: Observability Stack — Prometheus/Grafana + CloudWatch Container Insights

Context: The platform needs visibility into pod health, node resource usage, and ALB-level errors, but no single tool covers both deep Kubernetes-native metrics and AWS-managed infrastructure metrics (like ALB 5xx counts) equally well. Running two disconnected tools risks fragmented dashboards and slower incident diagnosis.

Decision: Run kube-prometheus-stack (Prometheus, Grafana, Alertmanager) as the primary Kubernetes-native metrics source, and enable CloudWatch Container Insights via the EKS add-on for AWS-managed infrastructure signals — unified into shared Grafana dashboards using both data sources side by side.

Alternatives considered:

CloudWatch only — rejected; lacks the granularity and native Kubernetes label/service discovery that Prometheus provides out of the box, making pod-level debugging harder.
Prometheus only (self-scraped ALB metrics via exporter) — rejected as the sole source; AWS-managed metrics like ALB 5xx counts are more reliably sourced directly from CloudWatch than through a custom exporter with its own failure modes.
Managed Prometheus (AWS AMP) — considered to offload operational overhead of running Prometheus; not chosen for this build to keep full visibility into the self-managed stack's configuration and retention behavior (Thanos) for the purposes of demonstrating hands-on ownership.

Consequences:

Gain: one dashboard surface covering both Kubernetes-native and AWS-managed signals, without forcing every metric through a single tool's limitations.
Cost: two systems to operate and reconcile; dashboards mixing data sources are more fragile to maintain if either source's labels or metric names change.
Follow-up: evaluate migrating self-managed Prometheus to AWS Managed Prometheus once operational overhead becomes the bigger cost than configuration flexibility.