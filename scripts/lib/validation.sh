#!/bin/bash
# scripts/lib/validation.sh
# Library functions for JSON validation and URL building
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/log.sh"

# ============================================================================
# PURE FUNCTIONS (tested in tests/lib/validation_test.sh)
# ============================================================================

# Validate a JSON string
# Args:
#   $1 - JSON string to validate
# Output:
#   "true" if valid JSON, "false" otherwise
# Returns:
#   0 on success
validate_json_string() {
  local json="$1"

  if [[ -z "$json" ]]; then
    echo "false"
    return 0
  fi

  # Use jq to validate JSON
  if echo "$json" | jq '.' > /dev/null 2>&1; then
    echo "true"
  else
    echo "false"
  fi

  return 0
}

# Validate a JSON file
# Args:
#   $1 - Path to JSON file
# Output:
#   "true" if valid JSON, "false" otherwise
# Returns:
#   0 on success, 1 on error
validate_json_file() {
  local file="$1"
  log_debug "validate_json_file: validating $file"

  if [[ -z "$file" ]]; then
    echo "false"
    return 0
  fi

  if [[ ! -f "$file" ]]; then
    echo "false"
    return 0
  fi

  # Use jq to validate JSON file
  if jq '.' "$file" > /dev/null 2>&1; then
    echo "true"
  else
    echo "false"
  fi

  return 0
}

# Build raw.githubusercontent.com URL from entry
# Args:
#   $1 - Entry string (e.g., "owner/repo/path/to/file.json")
#   $2 - Branch name (default: "main")
# Output:
#   Full raw.githubusercontent.com URL
# Returns:
#   0 on success, 1 on error
http_url_from_entry() {
  local entry="$1"
  local branch="${2:-main}"

  if [[ -z "$entry" ]]; then
    echo "Error: entry is required" >&2
    return 1
  fi

  local repo file_path
  repo=$(echo "$entry" | cut -d/ -f1,2)
  file_path=$(echo "$entry" | cut -d/ -f3-)

  echo "https://raw.githubusercontent.com/$repo/$branch/$file_path"
  return 0
}

# Build raw.githubusercontent.com URL from repo and file path
# Args:
#   $1 - Repository (e.g., "owner/repo")
#   $2 - File path (e.g., "path/to/file.json")
#   $3 - Branch name (default: "main")
# Output:
#   Full raw.githubusercontent.com URL
# Returns:
#   0 on success, 1 on error
build_raw_url() {
  local repo="$1"
  local file_path="$2"
  local branch="${3:-main}"

  if [[ -z "$repo" ]] || [[ -z "$file_path" ]]; then
    echo "Error: repo and file_path are required" >&2
    return 1
  fi

  echo "https://raw.githubusercontent.com/$repo/$branch/$file_path"
  return 0
}

# Sanitize a filename for safe filesystem use
# Args:
#   $1 - String to sanitize
# Output:
#   Sanitized filename safe for filesystem use
# Returns:
#   0 on success, 1 on error
sanitize_filename() {
  local input="$1"

  if [[ -z "$input" ]]; then
    echo "Error: input is required" >&2
    return 1
  fi

  # Replace slashes with underscores
  echo "$input" | tr '/' '_'
  return 0
}
