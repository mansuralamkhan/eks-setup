# SLO: demo-app availability (ADR-005)

| | |
|---|---|
| SLI | Fraction of successful synthetic probes (`probe_success{service="demo-app"}`, every 30s, blackbox exporter, HTTP 2xx) |
| SLO | 99.5% over a rolling 30 days |
| Error budget | 0.5%, which is 216 minutes of full outage per 30 days |

## Alerts (`08-observability/slo/prometheusrule-slo.yaml`)

| Alert | Fires when | Meaning | Severity |
|---|---|---|---|
| `DemoAppErrorBudgetFastBurn` | error rate over 1h **and** 5m above 7.2% | 14.4x burn: 2% of the 30-day budget is spent in an hour | page |
| `DemoAppErrorBudgetSlowBurn` | error rate over 6h **and** 30m above 3% | 6x burn: 5% of the budget is spent in six hours | ticket |

The short window in each pair makes the alert reset quickly once the problem is fixed.

## Tests

`scripts/test-prometheus-rules.sh` runs `promtool check rules` and the unit tests in `08-observability/tests/`:
a 15-minute outage pages, a healthy service stays silent, and a steady 4% failure rate raises the slow-burn ticket without paging.

## Live fire drill (record the result here)

```bash
kubectl scale deploy demo-app --replicas=0      # total outage
# Prometheus: probe_success drops to 0; DemoAppErrorBudgetFastBurn should fire in about 7 minutes
kubectl scale deploy demo-app --replicas=2      # restore
```

| Date | Outage started | Alert fired | Time to fire |
|---|---|---|---|
| _not run yet_ | | | |
