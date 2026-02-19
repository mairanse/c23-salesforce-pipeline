#!/usr/bin/env bash
set -euo pipefail
ORG="${1:-dev}"
echo "Deploy SAFE to org: $ORG"
sf project deploy start --target-org "$ORG" --test-level RunLocalTests
