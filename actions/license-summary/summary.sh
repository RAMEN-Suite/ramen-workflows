#!/usr/bin/env bash
# Writes REPORT_FILE (trivy license report, JSON) as markdown tables to GITHUB_STEP_SUMMARY.
set -euo pipefail

{
  echo "## 📜 License Report"
  echo ""

  if [ ! -f "$REPORT_FILE" ]; then
    echo "⚠️ \`$REPORT_FILE\` was not found — check the scan step's logs above."
    exit 0
  fi

  total=$(jq '[.Results[]?.Licenses[]?] | length' "$REPORT_FILE")
  if [ "$total" -eq 0 ]; then
    echo "⚠️ No licenses were detected. Either the scan found no packages or the report format changed — do not read this as a pass."
    exit 0
  fi

  echo "**Licenses found: $total**"
  echo ""
  echo "| Severity | Category | License | Count |"
  echo "|---|---|---|---|"
  jq -r '
    [.Results[]?.Licenses[]?]
    | group_by([.Severity, .Category, .Name])
    | map({severity: .[0].Severity, category: .[0].Category, license: .[0].Name, count: length})
    | sort_by(-.count)
    | .[]
    | "| \(.severity) | \(.category) | \(.license) | \(.count) |"
  ' "$REPORT_FILE"
  echo ""

  echo "<details>"
  echo "<summary>Show all packages</summary>"
  echo ""
  echo "| Severity | License | Package |"
  echo "|---|---|---|"
  jq -r '
    [.Results[]?.Licenses[]?]
    | sort_by(.Severity, .Name, .PkgName)
    | .[]
    | "| \(.Severity) | \(.Name) | \(.PkgName // .FilePath // "unknown") |"
  ' "$REPORT_FILE"
  echo ""
  echo "</details>"
} >>"$GITHUB_STEP_SUMMARY"
