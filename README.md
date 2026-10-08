# EKS Production-Style Platform

A hands-on platform engineering project on Amazon EKS: provisioning, node autoscaling, GitOps delivery, secrets management, admission policy, and observability. Each module was built and run on a live cluster, and the trade-offs behind each choice are written down as ADRs.

> **Honest status:** this repo is a working lab, not a one-command production platform. The table below says what is implemented, what is partial, and what is only proposed. Known gaps are listed explicitly.

## Modules

| Folder | What it contains | Status |
|---|---|---|
| `01-foundation/` | Terraform: 3-AZ VPC (single NAT gateway), EKS cluster (KMS secret encryption, control-plane logs, restricted public API endpoint), managed node group, VPC CNI, OIDC provider, Karpenter and ALB-controller IAM, Pod Identity | Implemented |
| `02-autoscaling/` | Karpenter `EC2NodeClass` + `NodePool` | Implemented |
| `04-service-mesh/` | Istio gateway, `VirtualService` (90/10 canary between v1 and v2), `DestinationRule`, two demo deployments | Lab (see known gaps) |
| `05-gitops/` | Argo CD app-of-apps: root app plus three children (AWS Load Balancer Controller, Karpenter, demo-app) | Implemented, partial coverage |
| `06-secrets/` | External Secrets Operator: `ClusterSecretStore`, `ExternalSecret`, IRSA trust-policy template | Implemented (IAM role created by hand) |
| `07-policy/` | Kyverno `disallow-latest-tag` policy in Audit mode, with passing and violating test pods | Implemented (Audit only) |
| `08-observability/` | kube-prometheus-stack Helm values, CloudWatch Container Insights reference, demo-app, two incident write-ups | Implemented (no dashboard JSON yet) |
| `docs/adr/` | Ten Architecture Decision Records, each with a `Status:` line | See below |

There is no `03-` folder. The AWS Load Balancer Controller's IAM role lives in `01-foundation/modules/eks`, and its Helm release is an Argo CD app in `05-gitops/apps`.

## Decisions and trade-offs

Every non-obvious choice is an ADR in `docs/adr/`, including the alternatives I rejected. Implementation status per ADR:

| ADR | Decision | Status |
|---|---|---|
| 0001 | Karpenter over Cluster Autoscaler | Implemented |
| 0002 | Kyverno rollout: Audit first, then Enforce | Implemented in Audit |
| 0003 | Argo CD app-of-apps | Implemented, partial coverage |
| 0004 | External Secrets Operator with IRSA | Implemented |
| 0005 | SLOs and error budgets | **Proposed** |
| 0006 | Terraform as the only IaC tool | Partial (no remote state or CI yet) |
| 0007 | Prometheus/Grafana plus CloudWatch Container Insights | Implemented |
| 0008 | Cosign + SLSA image signing, verified by Kyverno | **Proposed** |
| 0009 | Multi-AZ plus Velero backups | Partial (multi-AZ networking only) |
| 0010 | Node access through SSM Session Manager | Implemented |

## Real incidents

`08-observability/incidents/` documents two failures triggered on this cluster. The bad-image-tag incident exposed a real dashboard gap: a restart-count panel can't see `ImagePullBackOff`, because the container never started. The follow-up panel is described in the write-up and is not built yet.

## Known gaps

These are tracked and will be closed or reflected in the ADR statuses:

- **Karpenter discovery tags** (`karpenter.sh/discovery`) are not set by Terraform. The `EC2NodeClass` depends on them, so they are applied by hand today.
- **Karpenter Argo app** has no Helm values (for example `settings.clusterName`).
- **Karpenter controller IAM policy** should be compared with the official Karpenter v1 policy.
- **`04-service-mesh/`** has no `Service` manifest for `demo-app`.
- **Only part of the platform is managed by Argo CD.** External Secrets, Kyverno, kube-prometheus-stack and Istio are installed outside GitOps, and their install steps are not captured in this repo yet.
- **No CI and no remote Terraform state.**
- **Single NAT gateway** and a one-node managed baseline: the network is multi-AZ, egress and baseline capacity are not (see ADR-0009).
- **Cluster API endpoint CIDR** is hard-coded in `01-foundation/modules/eks/main.tf`. Change `public_access_cidrs` to your own address before applying.

## Setup

Prerequisites: AWS account and credentials, Terraform, `kubectl`, Helm.

1. **Foundation:** in `01-foundation/`, set `public_access_cidrs` for your IP, then `terraform init && terraform apply`.
2. **Kubeconfig:** `aws eks update-kubeconfig --name my-eks-cluster --region ap-south-1`.
3. **Argo CD:** install it, then `kubectl apply -f 05-gitops/apps/root-app.yaml`. Edit `repoURL` in the app manifests if you fork this repo.
4. **Autoscaling:** once Karpenter is running, tag the private subnets and the cluster security group with `karpenter.sh/discovery: my-eks-cluster`, then apply `02-autoscaling/`.
5. **Other modules:** `06-secrets/`, `07-policy/`, `08-observability/` and `04-service-mesh/` assume the cluster exists. Replace the `<ACCOUNT_ID>` and `<OIDC_PROVIDER>` placeholders first.

**Cost warning:** the EKS control plane and the NAT gateway bill continuously. Run `terraform destroy` when you finish a session.
