#!/bin/bash
# scripts/auto-merge.sh
# Auto-merge PRs when all required labels are present
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/log.sh"
source "$SCRIPT_DIR/lib/dry_run.sh"

# ============================================================================
# PURE FUNCTION (tested in tests/auto-merge_test.sh)
# ============================================================================

# Check if all required labels are present
# Args:
#   $1 - Comma-delimited labels string
# Output:
#   "true" if all required labels present, "false" otherwise
check_merge_requirements() {
  local labels="$1"

  if [[ -z "$labels" ]]; then
    echo "false"
    return 0
  fi

  # Helper: check for exact label in comma-delimited list
  has_label() {
    echo ",$1," | grep -q ",$2,"
  }

  # Check required labels
  if ! has_label "$labels" "repo-ok"; then
    echo "false"
    return 0
  fi

  if ! has_label "$labels" "no-deny"; then
    echo "false"
    return 0
  fi

  if ! has_label "$labels" "json-ok"; then
    echo "false"
    return 0
  fi

  # Check trust OR lgtm
  if has_label "$labels" "trusted-author"; then
    echo "true"
    return 0
  fi

  if has_label "$labels" "lgtm"; then
    echo "true"
    return 0
  fi

  echo "false"
  return 0
}

# ============================================================================
# MAIN - gh calls (NOT tested)
# ============================================================================

main() {
  local pr_number="${PR_NUMBER:-}"
  local repo="${GITHUB_REPOSITORY:-}"
  local pr_author="${PR_AUTHOR:-}"

  # Fetch current labels as comma-delimited string
  local labels
  labels=$(gh pr view "$pr_number" \
    --repo "$repo" \
    --json labels \
    --jq '.labels | map(.name) | join(",")')

  log_info "Current labels: $labels"

  # Check if all requirements are met
  local ready
  ready=$(check_merge_requirements "$labels")

  if [[ "$ready" != "true" ]]; then
    log_info "Missing required labels — not ready"
    exit 0
  fi

  # Approve the PR
  if [[ "$(is_dry_run)" == "true" ]]; then
    dry_run_log "approve PR #$pr_number"
  else
    gh api \
      "repos/$repo/pulls/$pr_number/reviews" \
      -f event="APPROVE" \
      -f body="Auto-approved by workflow" \
      2>/dev/null || log_debug "Already approved or approval not needed"
  fi

  # Squash merge
  if [[ "$(is_dry_run)" == "true" ]]; then
    dry_run_log "merge PR #$pr_number"
  else
    gh pr merge "$pr_number" \
      --repo "$repo" \
      --squash \
      --subject "Merge allowlist.txt update" \
      --body "Auto-merged by workflow from $pr_author"
    log_info "PR #$pr_number merged successfully"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
