#!/usr/bin/env bash
# Lints every PrometheusRule under 08-observability and runs the promtool unit tests in
# 08-observability/tests. Needs: promtool, python3 with PyYAML.
set -euo pipefail
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/rules"
for f in 08-observability/slo/prometheusrule-*.yaml 08-observability/alerts/prometheusrule-*.yaml; do
  out="$tmp/rules/$(basename "$f" .yaml).rules.yml"
  python3 - "$f" > "$out" <<'PY'
import sys, yaml
print(yaml.safe_dump(yaml.safe_load(open(sys.argv[1]))["spec"]))
PY
  promtool check rules --lint-fatal "$out"
done
# dashboard expressions must at least parse as PromQL
if [ -f 08-observability/dashboards/platform-dashboard.yaml ]; then
python3 - > "$tmp/rules/dashboard-exprs.rules.yml" <<'PY'
import yaml, json
cm = yaml.safe_load(open("08-observability/dashboards/platform-dashboard.yaml"))
dash = json.loads(cm["data"]["platform-overview.json"])
exprs = [t["expr"] for p in dash["panels"] for t in p.get("targets", [])]
rules = [{"record": f"dash:expr{i}", "expr": e} for i, e in enumerate(exprs)]
print(yaml.safe_dump({"groups": [{"name": "dashboard", "rules": rules}]}))
PY
promtool check rules --lint-fatal "$tmp/rules/dashboard-exprs.rules.yml"
fi
cp 08-observability/tests/*.test.yaml "$tmp/"
( cd "$tmp" && promtool test rules *.test.yaml )
