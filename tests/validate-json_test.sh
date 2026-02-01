#!/bin/bash
# tests/validate-json_test.sh
# Tests for validate-json.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/validate-json.sh"

function test_build_raw_url() {
  local result
  result=$(build_raw_url "owner/repo" "path/to/file.json")
  assert_equals "https://raw.githubusercontent.com/owner/repo/main/path/to/file.json" "$result"
}

function test_build_raw_url_with_custom_branch() {
  local result
  result=$(build_raw_url "owner/repo" "path/to/file.json" "develop")
  assert_equals "https://raw.githubusercontent.com/owner/repo/develop/path/to/file.json" "$result"
}

function test_build_raw_url_empty_repo() {
  local result
  result=$(build_raw_url "" "path/to/file.json" 2>&1)
  assert_matches "Error:" "$result"
}

function test_build_raw_url_empty_path() {
  local result
  result=$(build_raw_url "owner/repo" "" 2>&1)
  assert_matches "Error:" "$result"
}

function test_is_valid_json_at_url_with_invalid_json() {
  # Use a URL that returns invalid JSON or 404
  local result
  result=$(is_valid_json_at_url "https://raw.githubusercontent.com/owner/repo/main/nonexistent.json")
  assert_equals "false" "$result"
}

function test_is_valid_json_at_url_empty_url() {
  local result
  result=$(is_valid_json_at_url "")
  assert_equals "false" "$result"
}
