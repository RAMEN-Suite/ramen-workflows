#!/usr/bin/env bash
# Writes SARIF_FILE as a markdown table to GITHUB_STEP_SUMMARY.
set -euo pipefail

{
  echo "## $TITLE"
  echo ""

  if [ ! -f "$SARIF_FILE" ]; then
    echo "⚠️ \`$SARIF_FILE\` was not found — the scan step may have failed before producing output. Check its logs above."
    exit 0
  fi

  if ! jq empty "$SARIF_FILE" 2>/dev/null; then
    echo "⚠️ \`$SARIF_FILE\` is not valid JSON — the scan step may have been interrupted. Check its logs above."
    exit 0
  fi

  total=$(jq '[.runs[]?.results[]?] | length' "$SARIF_FILE")
  if [ "$total" -eq 0 ]; then
    echo "✅ No findings."
    exit 0
  fi

  rows=$(jq -r '
    .runs[]? | (.tool.driver.rules // []) as $rules | .results[]? | . as $r
    | ([$rules[] | select(.id == $r.ruleId) | .properties.tags[]?
        | select(IN("CRITICAL", "HIGH", "MEDIUM", "LOW", "UNKNOWN"))][0] // $r.level // "-") as $sev
    | [
        $sev,
        $r.ruleId,
        (($r.locations[0].physicalLocation.artifactLocation.uri // "-")
          + ":" + (($r.locations[0].physicalLocation.region.startLine // "-") | tostring)),
        ($r.message.text // "" | .[0:90])
      ] | map(tostring | gsub("[\n|]"; " ")) | @tsv
  ' "$SARIF_FILE")

  echo "**Total findings: $total**"
  echo ""
  echo "| Severity | Count |"
  echo "|---|---|"
  cut -f1 <<<"$rows" | sort | uniq -c | sort -rn | while read -r count sev; do
    echo "| $sev | $count |"
  done
  echo ""
  echo "<details>"
  echo "<summary>Show all findings</summary>"
  echo ""
  echo "| Severity | Rule | Location | Detail |"
  echo "|---|---|---|---|"
  while IFS=$'\t' read -r sev rule location detail; do
    echo "| $sev | $rule | $location | $detail |"
  done <<<"$rows"
  echo ""
  echo "</details>"
} >>"$GITHUB_STEP_SUMMARY"
