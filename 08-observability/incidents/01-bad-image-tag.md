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

## Follow-up (not yet built)
Add a panel on `kube_pod_container_status_waiting_reason`, filtered to reasons like `ImagePullBackOff` and `ErrImagePull`, so pull failures show up on the dashboard instead of only in `kubectl describe`.