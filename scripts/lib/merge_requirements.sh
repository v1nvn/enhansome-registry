#!/bin/bash
# scripts/lib/merge_requirements.sh
# Merge requirements checking library
set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_MERGE_REQUIREMENTS_SH_SOURCED:-}" ]] && return 0
readonly _MERGE_REQUIREMENTS_SH_SOURCED=true

# ============================================================================
# PURE FUNCTION (tested in tests/auto-merge_test.sh)
# ============================================================================

# Check if all required labels are present
# Args:
#   $1 - Comma-delimited labels string
# Output:
#   "true" if all required labels present, "false" otherwise
check_merge_requirements() {
  local labels="$1"

  if [[ -z "$labels" ]]; then
    echo "false"
    return 0
  fi

  # Helper: check for exact label in comma-delimited list
  has_label() {
    echo ",$1," | grep -q ",$2,"
  }

  # Check required labels
  if ! has_label "$labels" "repo-ok"; then
    echo "false"
    return 0
  fi

  if ! has_label "$labels" "no-deny"; then
    echo "false"
    return 0
  fi

  if ! has_label "$labels" "json-ok"; then
    echo "false"
    return 0
  fi

  # Check trust OR lgtm
  if has_label "$labels" "trusted-author"; then
    echo "true"
    return 0
  fi

  if has_label "$labels" "lgtm"; then
    echo "true"
    return 0
  fi

  echo "false"
  return 0
}
