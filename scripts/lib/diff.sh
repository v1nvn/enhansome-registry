#!/bin/bash
# scripts/lib/diff.sh
# Library functions for parsing git diffs
set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_DIFF_SH_SOURCED:-}" ]] && return 0
readonly _DIFF_SH_SOURCED=true

# Use local variable name to avoid conflicts with parent scripts
_DIFF_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_DIFF_LIB_DIR/log.sh"

# ============================================================================
# FUNCTIONS
# ============================================================================

# Get added/modified index.json files from a PR
# Args:
#   $1 - PR number
#   $2 - Repository (e.g., "owner/repo")
# Output:
#   List of index.json file paths (one per line), e.g., "repos/v1nvn/enhansome-go/index.json"
# Returns:
#   0 on success
get_pr_index_files() {
  local pr_number="$1"
  local repo="$2"

  gh api "repos/$repo/pulls/$pr_number/files" \
    --jq '.[] | select(.filename | endswith("/index.json")) | .filename' || true
}

# Get entry string from a PR
# Fetches PR files, finds the first index.json, reads content, returns entry like "v1nvn/repo/README.json"
# Args:
#   $1 - PR number
#   $2 - Repository (e.g., "owner/repo")
# Output:
#   Entry string (e.g., "v1nvn/enhansome-go/README.json") - returns the first entry found only
# Returns:
#   0 on success
get_entry_from_pr() {
  local pr_number="$1"
  local repo="$2"

  # Get all index.json files from the PR
  local index_files
  index_files=$(get_pr_index_files "$pr_number" "$repo")

  if [[ -z "$index_files" ]]; then
    return 0
  fi

  # Get PR head SHA once to avoid N+1 API calls
  local head_sha
  head_sha=$(gh api "repos/$repo/pulls/$pr_number" --jq '.head.sha' 2>/dev/null || true)
  if [[ -z "$head_sha" ]]; then
    return 0
  fi

  # Get the first index.json file and extract the entry
  local index_file filename
  while IFS= read -r index_file; do
    [[ -z "$index_file" ]] && continue

    # Get the file content via Contents API with PR head SHA
    local content
    content=$(gh api "repos/$repo/contents/$index_file" \
      -f ref="$head_sha" --jq '.content' 2>/dev/null | base64 --decode 2>/dev/null || true)

    if [[ -n "$content" ]]; then
      # Extract filename from JSON content
      filename=$(echo "$content" | jq -r '.filename // empty' || true)
      if [[ -n "$filename" ]]; then
        # Parse owner/repo from index_file path
        # "repos/v1nvn/enhansome-go/index.json" -> "v1nvn/enhansome-go"
        local owner_repo
        owner_repo=$(echo "$index_file" | sed 's|^repos/||' | sed 's|/index.json$||')
        echo "${owner_repo}/${filename}"
        return 0
      fi
    fi
  done <<< "$index_files"

  return 0
}

# Count new index.json files in a PR
# Args:
#   $1 - PR number
#   $2 - Repository (e.g., "owner/repo")
# Output:
#   Number of index.json files in the PR
# Returns:
#   0 on success
count_entries_from_pr() {
  local pr_number="$1"
  local repo="$2"

  local index_files
  index_files=$(get_pr_index_files "$pr_number" "$repo")

  if [[ -z "$index_files" ]]; then
    echo "0"
    return 0
  fi

  local count=0
  while IFS= read -r line; do
    [[ -n "$line" ]] && ((count++))
  done <<< "$index_files"

  echo "$count"
  return 0
}
