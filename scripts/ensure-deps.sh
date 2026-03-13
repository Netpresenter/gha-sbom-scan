#!/usr/bin/env bash
set -euo pipefail

# Ensure jq is available on the runner
if command -v jq &>/dev/null; then
  echo "jq is already installed: $(jq --version)"
  exit 0
fi

echo "jq not found, installing..."

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  sudo apt-get update -qq && sudo apt-get install -y -qq jq
elif [[ "$OSTYPE" == "darwin"* ]]; then
  brew install jq
else
  echo "::error::Unsupported OS for automatic jq installation: $OSTYPE"
  exit 1
fi

echo "jq installed: $(jq --version)"
