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

  # Fetch PR data (labels and title) in one call
  local pr_data
  pr_data=$(gh pr view "$pr_number" \
    --repo "$repo" \
    --json labels,title)

  local labels
  labels=$(echo "$pr_data" | jq -r '.labels | map(.name) | join(",")')

  local pr_title
  pr_title=$(echo "$pr_data" | jq -r '.title')

  log_info "Current labels: $labels"
  log_info "PR title: $pr_title"

  # Check if all requirements are met
  local ready
  ready=$(check_merge_requirements "$labels")

  if [[ "$ready" != "true" ]]; then
    log_info "Missing required labels — not ready"
    exit 0
  fi

  # Squash merge
  if [[ "$(is_dry_run)" == "true" ]]; then
    dry_run_log "merge PR #$pr_number"
  else
    gh pr merge "$pr_number" \
      --repo "$repo" \
      --squash \
      --subject "$pr_title" \
      --body "Auto-merged by workflow from $pr_author"
    log_info "PR #$pr_number merged successfully"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
