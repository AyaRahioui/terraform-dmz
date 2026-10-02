#!/usr/bin/env bash
# Usage : ./check.sh [dossier]     (ex: ./check.sh modules/firewall)
# STRICT=1 ./check.sh ...          -> Checkov fait échouer le script
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-$ROOT}"

echo "===== FORMAT ====="
terraform fmt -check -recursive "$TARGET"

mapfile -t DIRS < <(find "$TARGET" -name '*.tf' -not -path '*/.terraform/*' -exec dirname {} \; | sort -u)

for d in "${DIRS[@]}"; do
  echo "===== INIT + VALIDATE : $d ====="
  (cd "$d" && terraform init -backend=false -input=false >/dev/null && terraform validate)
done

if command -v tflint >/dev/null; then
  for d in "${DIRS[@]}"; do
    echo "===== TFLINT : $d ====="
    (cd "$d" && tflint --init --config="$ROOT/.tflint.hcl" >/dev/null && tflint --config="$ROOT/.tflint.hcl")
  done
else
  echo "!! tflint non installé, étape ignorée"
fi

for d in "${DIRS[@]}"; do
  if [ -d "$d/tests" ]; then
    echo "===== TERRAFORM TEST : $d ====="
    (cd "$d" && terraform test)
  fi
done

if command -v checkov >/dev/null; then
  echo "===== CHECKOV ====="
  if [ "${STRICT:-0}" = "1" ]; then
    checkov -d "$TARGET" --quiet --compact
  else
    checkov -d "$TARGET" --quiet --compact --soft-fail
  fi
else
  echo "!! checkov non installé, étape ignorée"
fi
echo "===== OK ====="
