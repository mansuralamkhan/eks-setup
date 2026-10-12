#!/usr/bin/env bash
# Writes the Terraform-created Velero bucket name into the Velero Helm values.
set -euo pipefail
cd "$(dirname "$0")/.."
bucket=$(terraform -chdir=01-foundation output -raw velero_bucket)
f=05-gitops/values/velero-values.yaml
grep -q REPLACE_VELERO_BUCKET "$f" || { echo "bucket already set in $f"; exit 0; }
sed -i.bak "s/REPLACE_VELERO_BUCKET/${bucket}/" "$f" && rm -f "$f.bak"
echo "set bucket to ${bucket} in $f"
