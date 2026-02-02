#!/bin/bash
# scripts/lib/dry_run.sh
# Dry run mode support for shell scripts
set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_DRY_RUN_SH_SOURCED:-}" ]] && return 0
readonly _DRY_RUN_SH_SOURCED=true

# Check if dry run mode is enabled
# Output: "true" if dry run, "false" otherwise
is_dry_run() {
  if [[ "${DRY_RUN:-false}" == "true" || "${DRY_RUN:-false}" == "1" ]]; then
    echo "true"
  else
    echo "false"
  fi
}

# Log a message indicating an action is being skipped due to dry run
# Args:
#   $1 - Action description (e.g., "merging PR", "adding label")
dry_run_log() {
  log_warn "[DRY RUN] Would $1"
}
