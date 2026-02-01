#!/bin/bash
# scripts/validate-repo.sh
# Validate repository entry format and existence
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/entry.sh"
source "$SCRIPT_DIR/lib/diff.sh"

# ============================================================================
# MAIN - gh calls (NOT tested)
# ============================================================================

main() {
  local pr_number="${PR_NUMBER:-}"
  local repo="${GITHUB_REPOSITORY:-}"

  # Remove repo-ok label first
  gh pr edit "$pr_number" \
    --repo "$repo" \
    --remove-label "repo-ok" 2>/dev/null || true

  # Get PR diff ignoring whitespace changes
  # This handles the case where a line is only modified by adding a newline
  local diff entry
  diff=$(get_pr_diff_for_file "$pr_number" "$repo")

  # Extract net new entries (additions not also removed)
  entry=$(get_entry_from_diff "$diff")

  # Check if there's anything to validate
  if [[ -z "$entry" ]]; then
    echo "No new entries detected"
    exit 0
  fi

  # Count total additions using the pure function
  local entry_count
  entry_count=$(count_net_new_additions "$diff")

  if [[ "$entry_count" -ne 1 ]]; then
    gh pr comment "$pr_number" \
      --repo "$repo" \
      --body "## Entry Validation Failed

Only one entry per PR is allowed. Found $entry_count entries. Please split into separate PRs."
    echo "Multiple entries detected: $entry_count"
    exit 0
  fi

  echo "Entry: $entry"

  # Validate format
  local valid_format
  valid_format=$(validate_entry_format "$entry")

  if [[ "$valid_format" != "true" ]]; then
    gh pr comment "$pr_number" \
      --repo "$repo" \
      --body "## Entry Validation Failed

Invalid format: \`$entry\`

Expected format: \`owner/repo/path/to/file.json\`"
    echo "Invalid format: $entry"
    exit 0
  fi

  # Extract owner/repo
  local entry_repo
  entry_repo=$(parse_repo_from_entry "$entry")
  echo "Repository: $entry_repo"

  # Check if repository exists
  if ! gh repo view "$entry_repo" --json name > /dev/null 2>&1; then
    gh pr comment "$pr_number" \
      --repo "$repo" \
      --body "## Entry Validation Failed

Repository \`$entry_repo\` not found or inaccessible."
    echo "Repository not found: $entry_repo"
    exit 0
  fi

  # All checks passed — add label
  gh pr edit "$pr_number" \
    --repo "$repo" \
    --add-label "repo-ok"

  echo "Validation passed — repo-ok label added"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
