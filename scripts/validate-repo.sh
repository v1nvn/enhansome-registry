#!/bin/bash
# scripts/validate-repo.sh
# Validate repository entry format and existence
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/entry.sh"

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

  # Extract new entries from PR diff
  local diff entry
  diff=$(gh api "repos/$repo/pulls/$pr_number/files" \
    --jq '.[] | select(.filename == "allowlist.txt") | .patch')

  entry=$(echo "$diff" | grep '^+' | grep -v '^+++' | sed 's/^+//' | grep -v '^#' | grep -v '^$')

  # Count entries
  local entry_count
  entry_count=$(echo "$entry" | grep -c '.' || true)

  if [[ "$entry_count" -eq 0 ]]; then
    echo "No new entries detected"
    exit 0
  fi

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
