# Runbook: Velero restore drill (ADR-009)

An untested backup is not a real backup. Run this once now and then quarterly.
Prerequisites: `brew install velero`, cluster running, Argo CD has synced the `velero` app.

## 1. Namespace-level drill (about 10 minutes)

```bash
# create something to lose
kubectl create namespace drill
kubectl -n drill create configmap marker --from-literal=created=$(date -u +%FT%TZ)
kubectl -n drill create deployment web --image=nginx:1.27-alpine

# back it up
velero backup create drill-$(date +%Y%m%d%H%M) --include-namespaces drill --snapshot-volumes=false --wait
velero backup get          # Phase should be Completed

# lose it
kubectl delete namespace drill

# restore it
velero restore create --from-backup <backup-name-from-above> --wait
kubectl -n drill get configmap marker deployment web    # both must be back
```

## 2. Cluster-loss drill (about 45 minutes, quarterly)

1. Let the scheduled backup run (`velero schedule get`), or take an on-demand one.
2. `terraform destroy` the cluster **without** emptying the bucket (remove `force_destroy` first
   if you do this for real, so backups survive the destroy).
3. `terraform apply` a new cluster, let Argo CD sync, and make sure Velero sees the existing bucket
   (`velero backup get`).
4. `velero restore create --from-backup <latest> --exclude-namespaces kube-system,velero,argocd --wait`
5. Check the demo workloads came back.

## What is and is not covered

Covered: Kubernetes objects (Deployments, Services, ConfigMaps, CRDs and their instances).
Not covered: persistent volume data (snapshots are disabled), Secrets' external sources
(those live in AWS Secrets Manager), and AWS resources created by Terraform (rebuild with `terraform apply`).

## Drill log (fill in after each run)

| Date | Type | Backup size / duration | Restore duration | Result | Notes |
|---|---|---|---|---|---|
| _not run yet_ | | | | | |
