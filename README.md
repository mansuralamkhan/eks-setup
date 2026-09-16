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


aws eks update-kubeconfig --region ap-south-1 --name my-eks-cluster
kubectl get nodes
kubectl get pods -A

aws eks describe-nodegroup --cluster-name my-eks-cluster --nodegroup-name my-eks-cluster-managed-ng --query "nodegroup.{status:status,scalingConfig:scalingConfig,health:health}"

aws eks describe-cluster --name my-eks-cluster --query "cluster.version"

curl -4 ifconfig.me

aws configure list
echo $AWS_PROFILE
echo $AWS_DEFAULT_REGION
aws eks list-clusters --region ap-south-1

aws configure set region ap-south-1

aws eks describe-cluster --name my-eks-cluster --query "cluster.version"
aws eks describe-nodegroup --cluster-name my-eks-cluster --nodegroup-name my-eks-cluster-managed-ng --query "nodegroup.{status:status,scalingConfig:scalingConfig,health:health}"

kubectl get pods -o wide | grep nginx | grep Running | wc -l


kubectl get pods -n kube-system -o custom-columns=NAME:.metadata.name,HOSTNETWORK:.spec.hostNetwork,POD_IP:.status.podIP,NODE_IP:.status.hostIP

aws ec2 describe-instances \
  --filters "Name=tag:eks:nodegroup-name,Values=my-eks-cluster-managed-ng" "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].InstanceId" --output text
kubectl set env daemonset aws-node -n kube-system ENABLE_PREFIX_DELEGATION=true
kubectl set env daemonset aws-node -n kube-system --list | grep PREFIX

kubectl describe node ip-10-0-4-59.ap-south-1.compute.internal | grep -A 15 "Capacity:"