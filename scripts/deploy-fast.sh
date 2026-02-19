#!/usr/bin/env bash
set -euo pipefail
ORG="${1:-dev}"
echo "Deploy FAST to org: $ORG"
sf project deploy start --target-org "$ORG" --test-level NoTestRun
