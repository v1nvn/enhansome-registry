#!/bin/bash
# scripts/validate-json.sh
# Validate JSON files referenced in PR entries
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/log.sh"
source "$SCRIPT_DIR/lib/entry.sh"
source "$SCRIPT_DIR/lib/validation.sh"
source "$SCRIPT_DIR/lib/diff.sh"

# ============================================================================
# PURE FUNCTION (tested in tests/validate-json_test.sh)
# ============================================================================

# Check if a URL returns valid JSON
# Args:
#   $1 - URL to check
# Output:
#   "true" if valid JSON, "false" otherwise
is_valid_json_at_url() {
  local url="$1"

  if [[ -z "$url" ]]; then
    echo "false"
    return 0
  fi

  local temp_file
  temp_file=$(mktemp)

  # Check if file exists via HTTP status
  local http_status
  http_status=$(curl -s -o "$temp_file" -w "%{http_code}" "$url")

  if [[ "$http_status" != "200" ]]; then
    rm -f "$temp_file"
    echo "false"
    return 0
  fi

  # Validate JSON
  local valid
  valid=$(validate_json_file "$temp_file")
  rm -f "$temp_file"

  echo "$valid"
  return 0
}

# ============================================================================
# MAIN - gh calls (NOT tested)
# ============================================================================

main() {
  local pr_number="${PR_NUMBER:-}"
  local repo="${GITHUB_REPOSITORY:-}"
  local mode="${MODE:-pr}"  # "pr" or "cron"

  if [[ "$mode" == "pr" ]]; then
    main_pr "$pr_number" "$repo"
  elif [[ "$mode" == "cron" ]]; then
    main_cron "$repo"
  else
    log_error "Invalid mode: $mode"
    exit 1
  fi
}

main_pr() {
  local pr_number="$1"
  local repo="$2"

  # Remove json-ok label first
  gh pr edit "$pr_number" \
    --repo "$repo" \
    --remove-label "json-ok" 2>/dev/null || true

  # Extract entry from PR diff
  local diff entry
  diff=$(get_pr_diff_for_file "$pr_number" "$repo")
  entry=$(get_entry_from_diff "$diff")

  if [[ -z "$entry" ]]; then
    log_info "No new entries detected"
    exit 0
  fi

  validate_entry "$entry" "$pr_number" "$repo"
}

main_cron() {
  local repo="$1"

  # Find open PRs that have repo-ok and no-deny but NOT json-ok
  local pr_numbers
  pr_numbers=$(gh pr list \
    --repo "$repo" \
    --state open \
    --label "repo-ok" \
    --label "no-deny" \
    --json number,labels \
    --jq '.[] | select(.labels | map(.name) | index("json-ok") | not) | .number')

  if [[ -z "$pr_numbers" ]]; then
    log_info "No PRs need json-ok retry"
    exit 0
  fi

  while IFS= read -r pr_number; do
    log_info "Retrying PR #$pr_number"

    # Extract entry from PR diff
    local diff entry
    diff=$(get_pr_diff_for_file "$pr_number" "$repo")
    entry=$(get_entry_from_diff "$diff")

    if [[ -z "$entry" ]]; then
      log_debug "  No entry found, skipping"
      continue
    fi

    validate_entry "$entry" "$pr_number" "$repo" "cron"
  done <<< "$pr_numbers"
}

validate_entry() {
  local entry="$1"
  local pr_number="$2"
  local repo="$3"
  local mode="${4:-pr}"

  # Parse entry
  local entry_repo file_path file_url
  entry_repo=$(parse_repo_from_entry "$entry")
  file_path=$(parse_file_path_from_entry "$entry")
  file_url=$(build_raw_url "$entry_repo" "$file_path")

  log_info "Checking: $file_url"

  # Check if valid JSON
  local valid
  valid=$(is_valid_json_at_url "$file_url")

  if [[ "$valid" != "true" ]]; then
    if [[ "$mode" == "cron" ]]; then
      log_info "  Still not available, will retry next hour"
      return 0
    fi

    gh pr comment "$pr_number" \
      --repo "$repo" \
      --body "## JSON Validation Failed

File \`$file_path\` in \`$entry_repo\` is not valid JSON."
    log_info "Invalid JSON: $file_path"
    exit 0
  fi

  # Valid JSON — add label
  gh pr edit "$pr_number" \
    --repo "$repo" \
    --add-label "json-ok"

  if [[ "$mode" == "cron" ]]; then
    gh pr comment "$pr_number" \
      --repo "$repo" \
      --body "## JSON Now Available

File \`$file_path\` in \`$entry_repo\` is now valid. Added \`json-ok\` label."
  fi

  log_info "JSON validation passed — json-ok label added"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
