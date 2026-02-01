#!/bin/bash
# scripts/check-denylist.sh
# Check if repository is in denylist
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/entry.sh"

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
  gh pr edit "$pr_number" \
    --repo "$repo" \
    --remove-label "no-deny" 2>/dev/null || true

  # Extract entry from PR diff
  local diff entry
  diff=$(gh api "repos/$repo/pulls/$pr_number/files" \
    --jq '.[] | select(.filename == "allowlist.txt") | .patch')

  entry=$(echo "$diff" | grep '^+' | grep -v '^+++' | sed 's/^+//' | grep -v '^#' | grep -v '^$')

  if [[ -z "$entry" ]]; then
    echo "No new entries detected"
    exit 0
  fi

  # Extract owner/repo
  local check_repo
  check_repo=$(extract_repo_from_entry "$entry")
  echo "Checking repository: $check_repo"

  # Check against denylist
  local denied
  denied=$(is_repo_in_denylist "$check_repo" "denylist.txt")

  if [[ "$denied" == "true" ]]; then
    gh pr comment "$pr_number" \
      --repo "$repo" \
      --body "## Denylist Check Failed

Repository \`$check_repo\` is in the denylist. Open an issue to discuss."
    echo "Repository is in denylist: $check_repo"
    exit 0
  fi

  # Not in denylist — add label
  gh pr edit "$pr_number" \
    --repo "$repo" \
    --add-label "no-deny"

  echo "Denylist check passed — no-deny label added"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
