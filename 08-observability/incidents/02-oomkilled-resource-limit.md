# Incident 02: OOMKilled from an Undersized Resource Limit

## Symptom
`demo-app` pod(s) restarting repeatedly — flagged by the restart-count panel on the Grafana observability dashboard.

## Diagnosis
kubectl describe pod <demo-app-pod>
Showed `Last State: Terminated`, `Reason: OOMKilled` — the container's memory usage exceeded its configured limit.

The dashboard's restart-count panel is what surfaced this — unlike Incident 01, this failure mode *is* visible as a restart, so the panel did its job of flagging that something was wrong. `kubectl describe` was then needed to get from "it's restarting" to the actual reason.

Memory limit at the time: `<fill in your actual value, e.g. 64Mi>`. Observed usage via `kubectl top pod` / the dashboard's memory panel: `<fill in>`.

## Fix
Increased the memory limit/request in the deployment spec to a realistic value based on observed usage:
```yaml
resources:
  requests:
    memory: "<your new value>"
  limits:
    memory: "<your new value>"
```
Applied and confirmed the pod stayed stable with no further restarts.

## Contrast with Incident 01
Both failures were on the same demo-app, but the dashboard behaved differently for each: OOMKilled showed up correctly as a restart-count spike, while the bad-image-tag failure in Incident 01 never registered on that same panel at all, since a container that never started isn't a "restart." Together, these two incidents mapped out a real blind spot in restart-count-only monitoring — it catches crash loops but misses pull failures entirely.