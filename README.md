# EKS Production-Style Platform

A hands-on, end-to-end platform engineering project on Amazon EKS — provisioning, autoscaling, GitOps delivery, secrets management, policy enforcement, and observability, each built as a working module with the real trade-offs documented as ADRs.

## What this is

Every folder here is a real exercise I built and ran on a live EKS cluster, not a tutorial copy-paste. Where something broke, I kept the failure and the fix — see `08-observability/incidents/` for two real debugging sessions.

## Architecture
01-foundation/ Terraform: VPC + EKS cluster (base infrastructure)
02-autoscaling/ Karpenter: EC2NodeClass + NodePool for node autoscaling
03-load-balancer/ AWS Load Balancer Controller (IRSA, IAM policies)
04-service-mesh/ Istio: gateway, virtual services, canary/ambient routing
05-gitops/ ArgoCD: app-of-apps pattern, auto-sync + self-heal
06-secrets/ External Secrets Operator: AWS Secrets Manager via IRSA
07-policy/ Kyverno: admission policy + audit/enforce test cases
08-observability/ Prometheus/Grafana + CloudWatch Container Insights,
unified dashboard, and real incident write-ups
docs/adr/ Architecture Decision Records for every major choice


## Decisions and trade-offs

Every non-obvious choice is documented as an ADR in `docs/adr/` — including where I chose Audit mode over Enforce for policy rollout, why IRSA instead of static credentials for secrets access, and the reasoning behind the autoscaling and service mesh setup.

## Real incidents, not just green dashboards

`08-observability/incidents/` documents two actual failures I triggered and debugged on this cluster — a bad image tag and an OOMKilled pod — including a real gap I found in my own dashboard (the pod-restarts panel doesn't catch `ImagePullBackOff`, since that's not a restart).

## Setup

Each module folder has its own manifests/Terraform. Foundation first (`01-foundation`), then apply modules roughly in numeric order since later modules assume the cluster and load balancer controller exist.
