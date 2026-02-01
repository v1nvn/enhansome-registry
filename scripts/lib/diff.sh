#!/bin/bash
# scripts/lib/diff.sh
# Library functions for parsing git diffs
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/log.sh"

# ============================================================================
# PURE FUNCTIONS (tested in tests/lib/diff_test.sh)
# ============================================================================

# Extract net new additions from a diff patch
# Args:
#   $1 - Diff patch content (with + and - lines)
# Output:
#   Net new lines (additions not also removed), one per line
extract_net_new_additions() {
  local diff="$1"
  log_debug "extract_net_new_additions: processing diff"

  # Extract deletions and additions separately
  local deletions additions
  deletions=$(echo "$diff" | grep '^-' | grep -v '^---' | sed 's/^-//' | grep -v '^#' | grep -v '^$' || true)
  additions=$(echo "$diff" | grep '^+' | grep -v '^+++' | sed 's/^+//' | grep -v '^#' | grep -v '^$' || true)

  # Handle empty additions early
  [[ -z "$additions" ]] && return 0

  # Filter additions - only keep lines not in deletions
  local IFS=$'\n'
  for line in $additions; do
    [[ -z "$line" ]] && continue
    if ! echo "$deletions" | grep -qx "$line"; then
      echo "$line"
    fi
  done
}

# Count net new additions from a diff patch
# Args:
#   $1 - Diff patch content (with + and - lines)
# Output:
#   Number of net new lines (additions not also removed)
count_net_new_additions() {
  local diff="$1"
  local count=0
  local IFS=$'\n'
  local result
  result=$(extract_net_new_additions "$diff")
  for line in $result; do
    [[ -n "$line" ]] && ((count++))
  done
  echo "$count"
}

# Get the first net new entry from a diff patch
# Args:
#   $1 - Diff patch content (with + and - lines)
# Output:
#   First net new line, or empty string if none
get_entry_from_diff() {
  local diff="$1"
  extract_net_new_additions "$diff" | head -n1 || true
}

# ============================================================================
# MAIN - gh calls (NOT tested)
# ============================================================================

# Get diff for a specific file from a PR
# Args:
#   $1 - PR number
#   $2 - Repository (e.g., "owner/repo")
#   $3 - Filename to get diff for (default: "allowlist.txt")
#   $4 - Extra diff options (default: "--ignore-all-space")
# Output:
#   Diff patch content for the specified file
get_pr_diff_for_file() {
  local pr_number="$1"
  local repo="$2"
  local filename="${3:-allowlist.txt}"
  local diff_opts="${4:---ignore-all-space}"

  gh pr diff "$pr_number" --repo "$repo" -- $diff_opts -- "$filename" || true
}

# Get diff for a specific file from a PR using GitHub API
# This is an alternative to get_pr_diff_for_file that uses the API instead
# Args:
#   $1 - PR number
#   $2 - Repository (e.g., "owner/repo")
#   $3 - Filename to get diff for (default: "allowlist.txt")
# Output:
#   Diff patch content for the specified file
get_pr_diff_for_file_api() {
  local pr_number="$1"
  local repo="$2"
  local filename="${3:-allowlist.txt}"

  gh api "repos/$repo/pulls/$pr_number/files" \
    --jq ".[] | select(.filename == \"$filename\") | .patch" || true
}
