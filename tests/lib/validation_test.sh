#!/bin/bash
# tests/lib/validation_test.sh
# Tests for lib/validation.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../scripts/lib/validation.sh"

function test_validate_json_string_valid_object() {
  assert_equals "true" "$(validate_json_string '{"key":"value"}')"
}

function test_validate_json_string_valid_array() {
  assert_equals "true" "$(validate_json_string '["item1", "item2"]')"
}

function test_validate_json_string_valid_nested() {
  assert_equals "true" "$(validate_json_string '{"key":{"nested":"value"}}')"
}

function test_validate_json_string_invalid() {
  assert_equals "false" "$(validate_json_string '{not valid json}')"
}

function test_validate_json_string_empty() {
  assert_equals "false" "$(validate_json_string "")"
}

function test_validate_json_string_just_braces() {
  assert_equals "true" "$(validate_json_string '{}')"
}

function test_validate_json_file_valid() {
  local temp_file
  temp_file=$(mktemp)
  echo '{"key":"value"}' > "$temp_file"
  assert_equals "true" "$(validate_json_file "$temp_file")"
  rm -f "$temp_file"
}

function test_validate_json_file_invalid() {
  local temp_file
  temp_file=$(mktemp)
  echo '{not valid json}' > "$temp_file"
  assert_equals "false" "$(validate_json_file "$temp_file")"
  rm -f "$temp_file"
}

function test_validate_json_file_nonexistent() {
  assert_equals "false" "$(validate_json_file "/nonexistent/file.json")"
}

function test_validate_json_file_empty() {
  local temp_file
  temp_file=$(mktemp)
  echo "" > "$temp_file"
  # An empty file is valid JSON (empty document per jq)
  assert_equals "true" "$(validate_json_file "$temp_file")"
  rm -f "$temp_file"
}

function test_http_url_from_entry() {
  local result
  result=$(http_url_from_entry "owner/repo/path/to/file.json")
  assert_equals "https://raw.githubusercontent.com/owner/repo/main/path/to/file.json" "$result"
}

function test_http_url_from_entry_with_custom_branch() {
  local result
  result=$(http_url_from_entry "owner/repo/path/to/file.json" "develop")
  assert_equals "https://raw.githubusercontent.com/owner/repo/develop/path/to/file.json" "$result"
}

function test_http_url_from_entry_with_dots_in_repo() {
  local result
  result=$(http_url_from_entry "owner/repo.name/path/to/file.json")
  assert_equals "https://raw.githubusercontent.com/owner/repo.name/main/path/to/file.json" "$result"
}

function test_http_url_from_entry_empty() {
  local result
  result=$(http_url_from_entry "" 2>&1 >/dev/null || true)
  assert_matches "Error:" "$result"
}

function test_sanitize_filename() {
  assert_equals "owner_repo" "$(sanitize_filename "owner/repo")"
}

function test_sanitize_filename_nested_path() {
  assert_equals "owner_repo_data_file" "$(sanitize_filename "owner/repo/data/file")"
}

function test_sanitize_filename_with_multiple_slashes() {
  assert_equals "a_b_c_d" "$(sanitize_filename "a/b/c/d")"
}

function test_sanitize_filename_empty() {
  local result
  result=$(sanitize_filename "" 2>&1 >/dev/null || true)
  assert_matches "Error:" "$result"
}

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

function test_build_raw_url_with_dots_in_repo() {
  local result
  result=$(build_raw_url "owner/repo.name" "path/to/file.json")
  assert_equals "https://raw.githubusercontent.com/owner/repo.name/main/path/to/file.json" "$result"
}

function test_build_raw_url_empty_repo() {
  local result
  result=$(build_raw_url "" "path/to/file.json" 2>&1 >/dev/null || true)
  assert_matches "Error:" "$result"
}

function test_build_raw_url_empty_path() {
  local result
  result=$(build_raw_url "owner/repo" "" 2>&1 >/dev/null || true)
  assert_matches "Error:" "$result"
}
