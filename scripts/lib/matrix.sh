#!/bin/bash
# scripts/lib/matrix.sh
# Library functions for generating GitHub Actions matrix JSON
set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_MATRIX_SH_SOURCED:-}" ]] && return 0
readonly _MATRIX_SH_SOURCED=true

# Use local variable name to avoid conflicts with parent scripts
_MATRIX_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_MATRIX_LIB_DIR/log.sh"

# ============================================================================
# PURE FUNCTIONS (tested in tests/lib/matrix_test.sh)
# ============================================================================

# Generate JSON array for GitHub Actions matrix from allowlist
# Args:
#   $1 - Path to allowlist.txt file
# Output:
#   JSON array of entries (e.g., '["owner/repo/file.json","..."]')
# Returns:
#   0 on success, 1 on error
generate_matrix_json() {
  local allowlist_file="$1"
  log_debug "generate_matrix_json: reading from $allowlist_file"

  if [[ ! -f "$allowlist_file" ]]; then
    echo "Error: allowlist file not found: $allowlist_file" >&2
    return 1
  fi

  # Read the allowlist, filter out comments and empty lines, format as JSON array
  jq -R . "$allowlist_file" | jq -s -c 'map(select(length > 0 and startswith("#") | not))'
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
