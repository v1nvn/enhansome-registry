#!/bin/bash
# scripts/auto-merge-retry.sh
# Scheduled retry to auto-merge PRs with all required labels
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/log.sh"
source "$SCRIPT_DIR/lib/dry_run.sh"
source "$SCRIPT_DIR/lib/merge_requirements.sh"

# ============================================================================
# PURE FUNCTION (tested in tests/auto-merge-retry_test.sh)
# ============================================================================

# Convert JSON labels array to comma-delimited string and check requirements
# Args:
#   $1 - JSON array of label objects
# Output:
#   "true" if all required labels present, "false" otherwise
check_merge_requirements_from_json() {
  local labels_json="$1"

  if [[ -z "$labels_json" ]]; then
    echo "false"
    return 0
  fi

  # Convert JSON array to comma-delimited list for check_merge_requirements
  local labels
  labels=$(echo "$labels_json" | jq -r 'map(.name) | join(",")')

  # Reuse logic from merge_requirements.sh library
  check_merge_requirements "$labels"
}

# ============================================================================
# MAIN - gh calls (NOT tested)
# ============================================================================

main() {
  local repo="${GITHUB_REPOSITORY:-}"

  log_info "Starting auto-merge retry scan"

  # Fetch PRs with all 4 required labels: repo-ok, no-deny, json-ok, AND (trusted-author OR lgtm)
  local pr_data
  pr_data=$(gh pr list \
    --repo "$repo" \
    --state open \
    --json number,title,author,labels \
    --limit 1000 \
    --jq '.[] | select(.labels | map(.name) | index("repo-ok")) |
                    select(.labels | map(.name) | index("no-deny")) |
                    select(.labels | map(.name) | index("json-ok")) |
                    select(.labels | map(.name) | index("trusted-author") or index("lgtm")) |
                    {number, title, author: .author.login, labels}')

  if [[ -z "$pr_data" ]]; then
    log_info "No PRs with all required labels found"
    exit 0
  fi

  # Count PRs to process
  local pr_count
  pr_count=$(echo "$pr_data" | jq 'length')
  log_info "Found $pr_count PR(s) with all required labels"

  # Process each PR
  while IFS= read -r pr_line; do
    local pr_number pr_title pr_author labels_json
    pr_number=$(echo "$pr_line" | jq -r '.number')
    pr_title=$(echo "$pr_line" | jq -r '.title')
    pr_author=$(echo "$pr_line" | jq -r '.author')
    labels_json=$(echo "$pr_line" | jq -r '.labels')

    log_info "Processing PR #$pr_number: $pr_title (by $pr_author)"

    # Double-check requirements (should always pass based on query, but safety check)
    local ready
    ready=$(check_merge_requirements_from_json "$labels_json")

    if [[ "$ready" != "true" ]]; then
      log_warn "  PR #$pr_number no longer meets requirements (labels changed during scan)"
      continue
    fi

    # Attempt squash merge
    if [[ "$(is_dry_run)" == "true" ]]; then
      dry_run_log "merge PR #$pr_number"
    else
      if gh pr merge "$pr_number" \
        --repo "$repo" \
        --squash \
        --subject "$pr_title" \
        --body "Auto-merged by retry workflow from $pr_author" 2>/dev/null; then
        log_info "  PR #$pr_number merged successfully"
      else
        local merge_error
        merge_error=$(gh pr view "$pr_number" --repo "$repo" --json mergeable --jq '.mergeable')
        if [[ "$merge_error" == "false" ]]; then
          log_info "  PR #$pr_number not mergeable (base branch modified or conflicts)"
        else
          log_warn "  PR #$pr_number merge failed (will retry next hour)"
        fi
      fi
    fi
  done < <(echo "$pr_data" | jq -c '.[]')

  log_info "Auto-merge retry scan complete"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
