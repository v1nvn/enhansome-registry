#!/bin/bash
# tests/validate-repo_test.sh
# Tests for validate-repo.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/lib/diff.sh"
source "$SCRIPT_DIR/../scripts/lib/entry.sh"
source "$SCRIPT_DIR/../scripts/validate-repo.sh"

# Note: The diff parsing functions are now tested in tests/lib/diff_test.sh
# This file tests the integration with validate-repo.sh

# Test: validate-repo.sh uses the diff library correctly
function test_validate_repo_sources_diff_library() {
  # This test ensures the library is loaded and functions are available
  command -v extract_net_new_additions >/dev/null || fail "extract_net_new_additions not found"
  command -v count_net_new_additions >/dev/null || fail "count_net_new_additions not found"
  command -v get_entry_from_diff >/dev/null || fail "get_entry_from_diff not found"
  command -v get_pr_diff_for_file >/dev/null || fail "get_pr_diff_for_file not found"
  command -v validate_entry_format >/dev/null || fail "validate_entry_format not found"
  command -v parse_repo_from_entry >/dev/null || fail "parse_repo_from_entry not found"
}
