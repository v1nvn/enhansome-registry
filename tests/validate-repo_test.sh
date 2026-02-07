#!/bin/bash
# tests/validate-repo_test.sh
# Tests for validate-repo.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/lib/diff.sh"
source "$SCRIPT_DIR/../scripts/lib/entry.sh"
source "$SCRIPT_DIR/../scripts/validate-repo.sh"

# Note: diff.sh functions are API-dependent and tested via integration
# This file tests the integration with validate-repo.sh

# Test: validate-repo.sh uses the diff library correctly
function test_validate_repo_sources_diff_library() {
  # This test ensures the library is loaded and functions are available
  command -v get_pr_index_files >/dev/null || fail "get_pr_index_files not found"
  command -v get_entry_from_pr >/dev/null || fail "get_entry_from_pr not found"
  command -v count_entries_from_pr >/dev/null || fail "count_entries_from_pr not found"
  command -v validate_entry_format >/dev/null || fail "validate_entry_format not found"
  command -v parse_repo_from_entry >/dev/null || fail "parse_repo_from_entry not found"
}
