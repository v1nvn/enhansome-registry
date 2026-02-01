#!/bin/bash
# scripts/lib/entry.sh
# Library functions for parsing and validating registry entries
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/log.sh"

# ============================================================================
# PURE FUNCTIONS (tested in tests/lib/entry_test.sh)
# ============================================================================

# Parse owner/repo from an entry string
# Args:
#   $1 - Entry string (e.g., "owner/repo/path/to/file.json")
# Output:
#   owner/repo string
# Returns:
#   0 on success, 1 on error
parse_repo_from_entry() {
  local entry="$1"
  log_debug "parse_repo_from_entry: entry=$entry"

  if [[ -z "$entry" ]]; then
    echo "Error: entry is required" >&2
    return 1
  fi

  # Extract owner/repo (first two slash-separated parts)
  echo "$entry" | cut -d/ -f1,2
  return 0
}

# Parse file path from an entry string
# Args:
#   $1 - Entry string (e.g., "owner/repo/path/to/file.json")
# Output:
#   path/to/file.json string
# Returns:
#   0 on success, 1 on error
parse_file_path_from_entry() {
  local entry="$1"

  if [[ -z "$entry" ]]; then
    echo "Error: entry is required" >&2
    return 1
  fi

  # Extract file path (everything after the second slash)
  echo "$entry" | cut -d/ -f3-
  return 0
}

# Validate entry format
# Args:
#   $1 - Entry string to validate
# Output:
#   "true" if valid, "false" otherwise
# Returns:
#   0 on success, 1 on error
validate_entry_format() {
  local entry="$1"
  log_debug "validate_entry_format: validating entry=$entry"

  if [[ -z "$entry" ]]; then
    echo "false"
    return 0
  fi

  # Format: owner/repo/path/to/file.json
  # - owner: alphanumeric, underscore, hyphen
  # - repo: alphanumeric, underscore, dot, hyphen
  # - path: at least one character, ending in .json
  if [[ ! "$entry" =~ ^[a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+/.+\.json$ ]]; then
    echo "false"
    return 0
  fi

  echo "true"
  return 0
}

# Check if a value is a member of a comma-delimited list
# Args:
#   $1 - Value to search for
#   $2 - Comma-delimited list (e.g., "user1,user2,user3")
# Output:
#   "true" if found, "false" otherwise
# Returns:
#   0 on success
is_list_member() {
  local value="$1"
  local list="$2"

  if [[ -z "$value" ]] || [[ -z "$list" ]]; then
    echo "false"
    return 0
  fi

  # Convert comma-delimited list to newline-delimited and check
  if echo "$list" | tr ',' '\n' | grep -qFx "$value"; then
    echo "true"
  else
    echo "false"
  fi

  return 0
}

# Check if a file path is in a newline-delimited list
# Args:
#   $1 - File path to search for (e.g., "owner/repo")
#   $2 - Path to file containing newline-delimited list
# Output:
#   "true" if found, "false" otherwise
# Returns:
#   0 on success, 1 on error
is_file_in_list() {
  local value="$1"
  local list_file="$2"

  if [[ -z "$value" ]]; then
    echo "false"
    return 0
  fi

  if [[ ! -f "$list_file" ]]; then
    echo "false"
    return 0
  fi

  # Use grep -qFx for exact match in file
  if grep -qFx "$value" "$list_file"; then
    echo "true"
  else
    echo "false"
  fi

  return 0
}
