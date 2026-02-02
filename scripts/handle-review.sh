#!/bin/bash
# scripts/handle-review.sh
# Handle maintainer LGTM comments and manage label
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/log.sh"
source "$SCRIPT_DIR/lib/dry_run.sh"
source "$SCRIPT_DIR/lib/entry.sh"

# ============================================================================
# PURE FUNCTIONS (tested in tests/handle-review_test.sh)
# ============================================================================

# Check if comment is an LGTM comment
# Args:
#   $1 - Comment body
# Output:
#   "true" if LGTM, "false" otherwise
is_lgtm_comment() {
  local comment="$1"

  if [[ -z "$comment" ]]; then
    echo "false"
    return 0
  fi

  # Trim whitespace and convert to lowercase
  local trimmed
  trimmed=$(echo "$comment" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]')

  if [[ "$trimmed" == "lgtm" ]]; then
    echo "true"
  else
    echo "false"
  fi

  return 0
}

# Check if user is a maintainer
# Args:
#   $1 - Username to check
#   $2 - Comma-delimited list of maintainers
# Output:
#   "true" if maintainer, "false" otherwise
is_maintainer() {
  local user="$1"
  local maintainers="$2"

  if [[ -z "$user" ]] || [[ -z "$maintainers" ]]; then
    echo "false"
    return 0
  fi

  local result
  result=$(is_list_member "$user" "$maintainers")
  echo "$result"
  return 0
}

# ============================================================================
# MAIN - gh calls (NOT tested)
# ============================================================================

main() {
  local pr_number="${PR_NUMBER:-}"
  local repo="${GITHUB_REPOSITORY:-}"
  local comment_body="${COMMENT_BODY:-}"
  local comment_author="${COMMENT_AUTHOR:-}"
  local maintainers="${MAINTAINERS:-}"

  # Check if comment is "lgtm"
  local lgtm
  lgtm=$(is_lgtm_comment "$comment_body")

  if [[ "$lgtm" != "true" ]]; then
    log_info "Comment is not 'lgtm', ignoring"
    exit 0
  fi

  # Check if author is a maintainer
  local maintainer
  maintainer=$(is_maintainer "$comment_author" "$maintainers")

  if [[ "$maintainer" != "true" ]]; then
    log_info "Comment author $comment_author is not a maintainer"
    exit 0
  fi

  # Add lgtm label
  if [[ "$(is_dry_run)" == "true" ]]; then
    dry_run_log "add lgtm label to PR #$pr_number"
  else
    gh pr edit "$pr_number" \
      --repo "$repo" \
      --add-label "lgtm"
    log_info "Maintainer $comment_author approved — lgtm label added"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
