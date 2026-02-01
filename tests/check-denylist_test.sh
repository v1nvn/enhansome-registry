#!/bin/bash
# tests/check-denylist_test.sh
# Tests for check-denylist.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/check-denylist.sh"

# Create a temp denylist file for testing
DENYLIST_FILE=$(mktemp)
trap 'rm -f "$DENYLIST_FILE"' EXIT

function setup_denylist() {
  cat > "$DENYLIST_FILE" << 'EOF'
bad/repo
malicious/org
test/spam
EOF
}

function test_is_repo_in_denylist_found() {
  setup_denylist
  assert_equals "true" "$(is_repo_in_denylist "bad/repo" "$DENYLIST_FILE")"
}

function test_is_repo_in_denylist_not_found() {
  setup_denylist
  assert_equals "false" "$(is_repo_in_denylist "good/repo" "$DENYLIST_FILE")"
}

function test_is_repo_in_denylist_empty_repo() {
  setup_denylist
  assert_equals "false" "$(is_repo_in_denylist "" "$DENYLIST_FILE")"
}

function test_is_repo_in_denylist_nonexistent_file() {
  assert_equals "false" "$(is_repo_in_denylist "any/repo" "/nonexistent/file.txt")"
}

function test_extract_repo_from_entry() {
  assert_equals "owner/repo" "$(extract_repo_from_entry "owner/repo/path/to/file.json")"
}

function test_extract_repo_from_entry_with_subdirs() {
  assert_equals "owner/repo.name" "$(extract_repo_from_entry "owner/repo.name/deeply/nested/file.json")"
}
