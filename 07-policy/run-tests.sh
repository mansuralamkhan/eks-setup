#!/usr/bin/env bash
# Offline test for the Kyverno policies. Needs the kyverno CLI (https://kyverno.io/docs/kyverno-cli/).
# passing-*  must produce 0 failures; violating-* must produce at least 1.
set -u
cd "$(dirname "$0")"
status=0
for f in tests/*.yaml; do
  out=$(kyverno apply policies/ --resource "$f" 2>&1)
  fails=$(echo "$out" | sed -n 's/.*fail: \([0-9]*\).*/\1/p' | head -1)
  fails=${fails:-0}
  case "$(basename "$f")" in
    passing-*)   [ "$fails" -eq 0 ] && echo "ok   $f (0 failures)" || { echo "FAIL $f expected pass"; echo "$out"; status=1; } ;;
    violating-*) [ "$fails" -gt 0 ] && echo "ok   $f ($fails failure(s), as expected)" || { echo "FAIL $f expected violation"; echo "$out"; status=1; } ;;
  esac
done
exit $status
