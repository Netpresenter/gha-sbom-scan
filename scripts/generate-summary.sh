#!/usr/bin/env bash
set -euo pipefail

# Arguments
SBOM_FILE="$1"
GRYPE_FILE="$2"
SUMMARY_TITLE="$3"
GRYPE_FAIL_ON="$4"

COMPONENT_COUNT=$(jq '.components | length' "$SBOM_FILE" 2>/dev/null || echo "0")
TOTAL_VULNS=$(jq '.matches | length' "$GRYPE_FILE" 2>/dev/null || echo "0")

CRITICAL=$(jq '[.matches[] | select(.vulnerability.severity == "Critical")] | length' "$GRYPE_FILE")
HIGH=$(jq '[.matches[] | select(.vulnerability.severity == "High")] | length' "$GRYPE_FILE")
MEDIUM=$(jq '[.matches[] | select(.vulnerability.severity == "Medium")] | length' "$GRYPE_FILE")
LOW=$(jq '[.matches[] | select(.vulnerability.severity == "Low")] | length' "$GRYPE_FILE")
NEGLIGIBLE=$(jq '[.matches[] | select(.vulnerability.severity == "Negligible")] | length' "$GRYPE_FILE")

# Write step summary
{
  echo "### ${SUMMARY_TITLE}"
  echo ""
  echo "**Components:** ${COMPONENT_COUNT} | **Vulnerabilities:** ${TOTAL_VULNS}"
  echo ""
  echo "| Severity | Count |"
  echo "|----------|-------|"
  if [ "$CRITICAL" -gt 0 ]; then echo "| :red_circle: Critical | ${CRITICAL} |"; fi
  if [ "$HIGH" -gt 0 ]; then echo "| :orange_circle: High | ${HIGH} |"; fi
  if [ "$MEDIUM" -gt 0 ]; then echo "| :yellow_circle: Medium | ${MEDIUM} |"; fi
  if [ "$LOW" -gt 0 ]; then echo "| :large_blue_circle: Low | ${LOW} |"; fi
  if [ "$NEGLIGIBLE" -gt 0 ]; then echo "| :white_circle: Negligible | ${NEGLIGIBLE} |"; fi
  echo ""

  if [ "$TOTAL_VULNS" -gt 0 ]; then
    echo "<details>"
    echo "<summary>Vulnerability Details (${TOTAL_VULNS})</summary>"
    echo ""
    echo "| CVE ID | Package | Version | Fixed In | Severity | Description |"
    echo "|--------|---------|---------|----------|----------|-------------|"
    jq -r '
      def severity_order:
        if . == "Critical" then 0
        elif . == "High" then 1
        elif . == "Medium" then 2
        elif . == "Low" then 3
        elif . == "Negligible" then 4
        else 5
        end;
      [.matches[] | {
        id: .vulnerability.id,
        pkg: .artifact.name,
        version: .artifact.version,
        fixed: ((.vulnerability.fix.versions // []) | join(", ") | if . == "" then "-" else . end),
        severity: .vulnerability.severity,
        desc: ((.vulnerability.description // "-") | .[0:80] | gsub("[\\n\\r]"; " ") | gsub("\\|"; "/"))
      }] | sort_by(.severity | severity_order) | .[] |
      "| \(.id) | \(.pkg) | \(.version) | \(.fixed) | \(.severity) | \(.desc) |"
    ' "$GRYPE_FILE"
    echo ""
    echo "</details>"
  fi
} >> "$GITHUB_STEP_SUMMARY"

# Set outputs via GITHUB_OUTPUT
echo "vuln-count=${TOTAL_VULNS}" >> "$GITHUB_OUTPUT"
echo "critical-count=${CRITICAL}" >> "$GITHUB_OUTPUT"

# Fail gate
if [ -n "$GRYPE_FAIL_ON" ]; then
  FAIL=0
  case "$GRYPE_FAIL_ON" in
    critical)
      [ "$CRITICAL" -gt 0 ] && FAIL=1
      ;;
    high)
      [ "$CRITICAL" -gt 0 ] || [ "$HIGH" -gt 0 ] && FAIL=1
      ;;
    medium)
      [ "$CRITICAL" -gt 0 ] || [ "$HIGH" -gt 0 ] || [ "$MEDIUM" -gt 0 ] && FAIL=1
      ;;
    low)
      [ "$CRITICAL" -gt 0 ] || [ "$HIGH" -gt 0 ] || [ "$MEDIUM" -gt 0 ] || [ "$LOW" -gt 0 ] && FAIL=1
      ;;
    *)
      echo "::error::Invalid grype-fail-on value '${GRYPE_FAIL_ON}'. Must be: critical, high, medium, or low."
      exit 1
      ;;
  esac

  if [ "$FAIL" -eq 1 ]; then
    echo "::error::Vulnerabilities found at or above '${GRYPE_FAIL_ON}' severity threshold"
    exit 1
  fi
fi
