# Incident 02: OOMKilled from an Undersized Resource Limit

## Symptom
`demo-app` pod(s) restarting repeatedly — [fill in: how you first noticed, e.g. "restart count climbing in `kubectl get pods`" or "flagged by the Grafana pod-restarts panel"].

## Diagnosis
kubectl describe pod <demo-app-pod>

Showed `Last State: Terminated`, `Reason: OOMKilled` — the container's memory usage exceeded its configured limit.

[Fill in: what the memory limit was set to, and what the actual usage looked like — e.g. via `kubectl top pod` or the dashboard's node/pod memory panel]

## Fix
Increased the memory limit/request in the deployment spec to a realistic value based on observed usage:
```yaml
resources:
  requests:
    memory: "<value>"
  limits:
    memory: "<value>"
```
Applied and confirmed the pod stayed stable with no further restarts.

## Contrast with Incident 01
This failure showed up differently from the bad-image-tag case — here, the **restart count panel correctly caught it** (OOMKilled is a real restart, unlike ImagePullBackOff), but the pod-restarts panel alone doesn't tell you *why* — you still need `kubectl describe` or a memory-usage panel to get from "it's restarting" to "it's OOM." That's the practical difference between the two failure modes: one is invisible to restart-count metrics, the other is visible but under-explained by them.