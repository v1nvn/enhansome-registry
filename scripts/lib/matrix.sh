#!/bin/bash
# scripts/lib/matrix.sh
# Library functions for generating GitHub Actions matrix JSON from repos/ directory
set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_MATRIX_SH_SOURCED:-}" ]] && return 0
readonly _MATRIX_SH_SOURCED=true

# Use local variable name to avoid conflicts with parent scripts
_MATRIX_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_MATRIX_LIB_DIR/log.sh"
source "$_MATRIX_LIB_DIR/entry.sh"

# ============================================================================
# PURE FUNCTIONS (tested in tests/lib/matrix_test.sh)
# ============================================================================

# Generate JSON array for GitHub Actions matrix from repos/ directory
# Scans repos/*/*/index.json, reads filename from each, builds entry strings
# Args:
#   $1 - Path to repos directory (e.g., "./repos")
# Output:
#   JSON array of entries (e.g., '["owner/repo/file.json","..."]')
# Returns:
#   0 on success, 1 on error
generate_matrix_from_repos() {
  local repos_dir="$1"
  # Normalize trailing slash to avoid path stripping issues
  repos_dir="${repos_dir%/}"
  log_debug "generate_matrix_from_repos: scanning $repos_dir"

  if [[ ! -d "$repos_dir" ]]; then
    echo "Error: repos directory not found: $repos_dir" >&2
    return 1
  fi

  # Find all index.json files and build entries
  local entries=()
  local index_file filename entry
  local relative_path part_count owner repo

  # Use find to get all index.json files, sorted for consistency
  while IFS= read -r -d '' index_file; do
    # Build the relative path from repos_dir
    relative_path="${index_file#$repos_dir/}"

    # The relative path should be "owner/repo/index.json"
    # We need to validate it has the right structure (3 parts minimum)
    part_count=$(echo "$relative_path" | tr '/' '\n' | wc -l)
    if [[ $part_count -lt 3 ]]; then
      log_debug "Skipping invalid index path (not deep enough): $relative_path"
      continue
    fi

    # Extract owner/repo from path (first two parts)
    owner=$(echo "$relative_path" | cut -d/ -f1)
    repo=$(echo "$relative_path" | cut -d/ -f2)

    # Validate owner and repo are not empty
    if [[ -z "$owner" ]] || [[ -z "$repo" ]]; then
      log_debug "Skipping invalid index path (missing owner/repo): $relative_path"
      continue
    fi

    # Read filename from index.json
    filename=$(jq -r '.filename // empty' "$index_file" 2>/dev/null || true)
    if [[ -z "$filename" ]]; then
      log_debug "Skipping index with no filename: $relative_path"
      continue
    fi

    # Build entry string directly: owner/repo/filename
    entry="${owner}/${repo}/${filename}"
    entries+=("$entry")
  done < <(find "$repos_dir" -type f -name "index.json" -print0 | sort -z)

  # Output as JSON array
  if [[ ${#entries[@]} -eq 0 ]]; then
    echo "[]"
    return 0
  fi

  # Use jq to properly escape special characters
  printf '%s\n' "${entries[@]}" | jq -R . | jq -s -c .
  return 0
}

# Parse a safe filename from a repo
# Args:
#   $1 - Repo string (e.g., "owner/repo")
# Output:
#   Safe filename (e.g., "owner_repo.json")
# Returns:
#   0 on success, 1 on error
parse_safe_filename() {
  local repo="$1"

  if [[ -z "$repo" ]]; then
    echo "Error: repo is required" >&2
    return 1
  fi

  # Replace slashes with underscores and append .json
  echo "${repo//\//_}.json"
  return 0
}
