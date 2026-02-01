#!/bin/bash
# scripts/check-trust.sh
# Check if PR author is in trusted users list and manage label
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/log.sh"
source "$SCRIPT_DIR/lib/entry.sh"

# ============================================================================
# PURE FUNCTION (tested in tests/check-trust_test.sh)
# ============================================================================

# Check if author is in trusted users list
# Args:
#   $1 - Author username
#   $2 - Comma-delimited list of trusted users
# Output:
#   "true" if trusted, "false" otherwise
is_author_trusted() {
  local author="$1"
  local trusted_users="$2"

  if [[ -z "$author" ]] || [[ -z "$trusted_users" ]]; then
    echo "false"
    return 0
  fi

  local result
  result=$(is_list_member "$author" "$trusted_users")
  echo "$result"
  return 0
}

# ============================================================================
# MAIN - gh calls (NOT tested)
# ============================================================================

main() {
  local pr_number="${PR_NUMBER:-}"
  local repo="${GITHUB_REPOSITORY:-}"
  local author="${PR_AUTHOR:-}"
  local trusted_users="${TRUSTED_USERS:-}"

  # Remove the label first (idempotent)
  gh pr edit "$pr_number" \
    --repo "$repo" \
    --remove-label "trusted-author" 2>/dev/null || true

  # Check if author is trusted
  local trusted
  trusted=$(is_author_trusted "$author" "$trusted_users")

  if [[ "$trusted" == "true" ]]; then
    gh pr edit "$pr_number" \
      --repo "$repo" \
      --add-label "trusted-author"
    log_info "Trusted author: $author — trusted-author label added"
  else
    log_info "Author $author is not in trusted users list"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
