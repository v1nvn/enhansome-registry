#!/bin/bash
# scripts/validate-repo.sh
# Validate repository entry format and existence
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/log.sh"
source "$SCRIPT_DIR/lib/dry_run.sh"
source "$SCRIPT_DIR/lib/entry.sh"
source "$SCRIPT_DIR/lib/diff.sh"

# ============================================================================
# MAIN - gh calls (NOT tested)
# ============================================================================

main() {
  local pr_number="${PR_NUMBER:-}"
  local repo="${GITHUB_REPOSITORY:-}"

  # Remove repo-ok label first
  if [[ "$(is_dry_run)" == "true" ]]; then
    dry_run_log "remove repo-ok label from PR #$pr_number"
  else
    gh pr edit "$pr_number" \
      --repo "$repo" \
      --remove-label "repo-ok" 2>/dev/null || true
  fi

  # Get entry from PR index.json files
  local entry
  entry=$(get_entry_from_pr "$pr_number" "$repo")

  # Check if there's anything to validate
  if [[ -z "$entry" ]]; then
    log_info "No new entries detected"
    exit 0
  fi

  # Count total entries using the new PR-based function
  local entry_count
  entry_count=$(count_entries_from_pr "$pr_number" "$repo")

  if [[ "$entry_count" -ne 1 ]]; then
    if [[ "$(is_dry_run)" == "true" ]]; then
      dry_run_log "comment on PR #$pr_number about multiple entries"
    else
      gh pr comment "$pr_number" \
        --repo "$repo" \
        --body "## Entry Validation Failed

Only one entry per PR is allowed. Found $entry_count entries. Please split into separate PRs."
    fi
    log_info "Multiple entries detected: $entry_count"
    exit 0
  fi

  log_info "Entry: $entry"

  # Validate format
  local valid_format
  valid_format=$(validate_entry_format "$entry")

  if [[ "$valid_format" != "true" ]]; then
    if [[ "$(is_dry_run)" == "true" ]]; then
      dry_run_log "comment on PR #$pr_number about invalid format"
    else
      gh pr comment "$pr_number" \
        --repo "$repo" \
        --body "## Entry Validation Failed

Invalid format: \`$entry\`

Expected format: \`owner/repo/path/to/file.json\`"
    fi
    log_info "Invalid format: $entry"
    exit 0
  fi

  # Extract owner/repo
  local entry_repo
  entry_repo=$(parse_repo_from_entry "$entry")
  log_info "Repository: $entry_repo"

  # Check if repository exists
  if ! gh repo view "$entry_repo" --json name > /dev/null 2>&1; then
    if [[ "$(is_dry_run)" == "true" ]]; then
      dry_run_log "comment on PR #$pr_number about repo not found"
    else
      gh pr comment "$pr_number" \
        --repo "$repo" \
        --body "## Entry Validation Failed

Repository \`$entry_repo\` not found or inaccessible."
    fi
    log_info "Repository not found: $entry_repo"
    exit 0
  fi

  # All checks passed — add label
  if [[ "$(is_dry_run)" == "true" ]]; then
    dry_run_log "add repo-ok label to PR #$pr_number"
  else
    gh pr edit "$pr_number" \
      --repo "$repo" \
      --add-label "repo-ok"
    log_info "Validation passed — repo-ok label added"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
