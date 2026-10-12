# Incident 01: Bad Image Tag on demo-app

## Symptom
`demo-app` rollout got stuck — new pods weren't reaching Running state.

## Diagnosis
kubectl describe pod <demo-app-pod>

Events showed `ImagePullBackOff` / `ErrImagePull` — the image reference in the deployment pointed to a tag that didn't exist in the registry.

## Fix
Reset the image tag in the deployment to a valid, existing tag and rolled out again:

kubectl set image deployment/demo-app demo-app=correct-image:tag
kubectl rollout status deployment/demo-app
Confirmed a clean rollout — all replicas Running.

## Gap found
The Grafana dashboard's pod-restarts panel did **not** catch this failure. `ImagePullBackOff` isn't a container restart — the container never started in the first place — so a restart-count panel is blind to this entire failure class.

## Follow-up (built)
- Dashboard: the *Containers stuck waiting, by reason* panel in `08-observability/dashboards/platform-dashboard.yaml` plots `kube_pod_container_status_waiting_reason`.
- Alert: `PodImagePullFailure` in `08-observability/alerts/prometheusrule-workload.yaml` fires after three minutes of `ErrImagePull` / `ImagePullBackOff`.
- Both are covered by promtool unit tests (`08-observability/tests/workload.test.yaml`), including a test showing the restart-based alert stays silent for this failure. Re-running this incident on a live cluster to see the alert fire is still to do.
