#!/bin/bash
# scripts/check-denylist.sh
# Check if repository is in denylist
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/log.sh"
source "$SCRIPT_DIR/lib/dry_run.sh"
source "$SCRIPT_DIR/lib/entry.sh"
source "$SCRIPT_DIR/lib/diff.sh"

# ============================================================================
# PURE FUNCTION (tested in tests/check-denylist_test.sh)
# ============================================================================

# Check if repository is in denylist
# Args:
#   $1 - Repository string (e.g., "owner/repo")
#   $2 - Path to denylist file
# Output:
#   "true" if in denylist, "false" otherwise
is_repo_in_denylist() {
  local repo="$1"
  local denylist_file="$2"

  if [[ -z "$repo" ]]; then
    echo "false"
    return 0
  fi

  local result
  result=$(is_file_in_list "$repo" "$denylist_file")
  echo "$result"
  return 0
}

# Extract repository from entry
# Args:
#   $1 - Entry string (e.g., "owner/repo/path/to/file.json")
# Output:
#   Repository string (e.g., "owner/repo")
extract_repo_from_entry() {
  local entry="$1"
  parse_repo_from_entry "$entry"
}

# ============================================================================
# MAIN - gh calls (NOT tested)
# ============================================================================

main() {
  local pr_number="${PR_NUMBER:-}"
  local repo="${GITHUB_REPOSITORY:-}"

  # Remove the label first (idempotent)
  if [[ "$(is_dry_run)" == "true" ]]; then
    dry_run_log "remove no-deny label from PR #$pr_number"
  else
    gh pr edit "$pr_number" \
      --repo "$repo" \
      --remove-label "no-deny" 2>/dev/null || true
  fi

  # Extract entry from PR index.json files
  local entry
  entry=$(get_entry_from_pr "$pr_number" "$repo")

  if [[ -z "$entry" ]]; then
    log_info "No new entries detected"
    exit 0
  fi

  # Extract owner/repo
  local check_repo
  check_repo=$(extract_repo_from_entry "$entry")
  log_info "Checking repository: $check_repo"

  # Check against denylist
  local denied
  denied=$(is_repo_in_denylist "$check_repo" "denylist.txt")

  if [[ "$denied" == "true" ]]; then
    if [[ "$(is_dry_run)" == "true" ]]; then
      dry_run_log "comment on PR #$pr_number about denylist failure"
    else
      gh pr comment "$pr_number" \
        --repo "$repo" \
        --body "## Denylist Check Failed

Repository \`$check_repo\` is in the denylist. Open an issue to discuss."
    fi
    log_info "Repository is in denylist: $check_repo"
    exit 0
  fi

  # Not in denylist — add label
  if [[ "$(is_dry_run)" == "true" ]]; then
    dry_run_log "add no-deny label to PR #$pr_number"
  else
    gh pr edit "$pr_number" \
      --repo "$repo" \
      --add-label "no-deny"
    log_info "Denylist check passed — no-deny label added"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
