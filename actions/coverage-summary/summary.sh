#!/usr/bin/env bash
# Writes SUMMARY_FILE (istanbul coverage-summary.json) as a markdown table to GITHUB_STEP_SUMMARY.
set -euo pipefail

{
  echo "## 🧪 Coverage"
  echo ""

  if [ ! -f "$SUMMARY_FILE" ]; then
    echo "⚠️ \`$SUMMARY_FILE\` was not found — check the test step's logs above."
    exit 0
  fi

  echo "| Metric | Covered | Total | Percent |"
  echo "|---|---|---|---|"
  jq -r '
    .total
    | to_entries[]
    | select(.key != "branchesTrue")
    | "| \(.key) | \(.value.covered) | \(.value.total) | \(.value.pct)% |"
  ' "$SUMMARY_FILE"
} >>"$GITHUB_STEP_SUMMARY"
