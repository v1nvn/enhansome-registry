#!/bin/bash
# scripts/lib/log.sh
# Centralized logging library for shell scripts
set -euo pipefail

# Guard against multiple sourcing - readonly variables cannot be redeclared
[[ -n "${_LOG_SH_SOURCED:-}" ]] && return 0
readonly _LOG_SH_SOURCED=true

# Note: log.sh does not set _LOG_LIB_DIR since it doesn't source other libraries
# Other libs use unique directory variables (e.g., _DIFF_LIB_DIR) to avoid
# overwriting the parent script's SCRIPT_DIR when sourcing log.sh

# ============================================================================
# LOG LEVELS
# ============================================================================

readonly LOG_DEBUG=0
readonly LOG_INFO=1
readonly LOG_WARN=2
readonly LOG_ERROR=3

# Current log level from env, default to INFO
readonly LOG_CURRENT_LEVEL="${LOG_LEVEL:-INFO}"

# Get numeric level from string
_get_log_level_num() {
  case "$1" in
    DEBUG) echo 0 ;;
    INFO)  echo 1 ;;
    WARN)  echo 2 ;;
    ERROR) echo 3 ;;
    *) echo 1 ;;
  esac
}

# Check if message should be logged
_should_log() {
  local msg_level="$1"
  local msg_num current_num
  msg_num=$(_get_log_level_num "$msg_level")
  current_num=$(_get_log_level_num "$LOG_CURRENT_LEVEL")
  [[ $msg_num -ge $current_num ]]
}

# Public log functions
log_debug() { _should_log "DEBUG" && echo "[DEBUG] $*" >&2 || true; }
log_info()  { _should_log "INFO"  && echo "[INFO] $*" >&2 || true; }
log_warn()  { _should_log "WARN"  && echo "[WARN] $*" >&2 || true; }
log_error() { _should_log "ERROR" && echo "[ERROR] $*" >&2 || true; }
