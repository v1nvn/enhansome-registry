#!/bin/bash
# tests/lib/entry_test.sh
# Tests for lib/entry.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../scripts/lib/entry.sh"

function test_parse_repo_from_entry() {
  assert_equals "owner/repo" "$(parse_repo_from_entry "owner/repo/path/to/file.json")"
}

function test_parse_repo_from_entry_with_dots() {
  assert_equals "owner/repo.name" "$(parse_repo_from_entry "owner/repo.name/path/to/file.json")"
}

function test_parse_repo_from_entry_with_underscores() {
  assert_equals "owner_name/repo_name" "$(parse_repo_from_entry "owner_name/repo_name/path/to/file.json")"
}

function test_parse_repo_from_entry_with_hyphens() {
  assert_equals "owner-name/repo-name" "$(parse_repo_from_entry "owner-name/repo-name/path/to/file.json")"
}

function test_parse_repo_from_entry_empty() {
  assert_general_error "$(parse_repo_from_entry "" 2>&1 >/dev/null)"
}

function test_parse_file_path_from_entry() {
  assert_equals "path/to/file.json" "$(parse_file_path_from_entry "owner/repo/path/to/file.json")"
}

function test_parse_file_path_from_entry_nested() {
  assert_equals "deeply/nested/path/file.json" "$(parse_file_path_from_entry "owner/repo/deeply/nested/path/file.json")"
}

function test_parse_file_path_from_entry_single_level() {
  assert_equals "file.json" "$(parse_file_path_from_entry "owner/repo/file.json")"
}

function test_parse_file_path_from_entry_empty() {
  assert_general_error "$(parse_file_path_from_entry "" 2>&1 >/dev/null)"
}

function test_validate_entry_format_valid() {
  assert_equals "true" "$(validate_entry_format "owner/repo/path/to/file.json")"
}

function test_validate_entry_format_with_dots() {
  assert_equals "true" "$(validate_entry_format "owner/repo.name/path/to/file.json")"
}

function test_validate_entry_format_with_underscores() {
  assert_equals "true" "$(validate_entry_format "owner_name/repo_name/path/to/file.json")"
}

function test_validate_entry_format_with_hyphens() {
  assert_equals "true" "$(validate_entry_format "owner-name/repo-name/path/to/file.json")"
}

function test_validate_entry_format_invalid_no_slash() {
  assert_equals "false" "$(validate_entry_format "ownerrepofile.json")"
}

function test_validate_entry_format_invalid_only_one_slash() {
  assert_equals "false" "$(validate_entry_format "owner/repo.json")"
}

function test_validate_entry_format_invalid_not_json() {
  assert_equals "false" "$(validate_entry_format "owner/repo/path/to/file.txt")"
}

function test_validate_entry_format_invalid_empty() {
  assert_equals "false" "$(validate_entry_format "")"
}

function test_validate_entry_format_invalid_special_chars() {
  assert_equals "false" "$(validate_entry_format "owner@/repo/path/file.json")"
}

function test_is_list_member_found() {
  assert_equals "true" "$(is_list_member "v1nvn" "v1nvn,other,another")"
}

function test_is_list_member_not_found() {
  assert_equals "false" "$(is_list_member "stranger" "v1nvn,other,another")"
}

function test_is_list_member_empty_value() {
  assert_equals "false" "$(is_list_member "" "v1nvn,other")"
}

function test_is_list_member_empty_list() {
  assert_equals "false" "$(is_list_member "v1nvn" "")"
}

function test_is_list_member_partial_match() {
  assert_equals "false" "$(is_list_member "v1n" "v1nvn,other")"
}

function test_is_list_member_first_in_list() {
  assert_equals "true" "$(is_list_member "v1nvn" "v1nvn,other")"
}

function test_is_list_member_last_in_list() {
  assert_equals "true" "$(is_list_member "another" "v1nvn,other,another")"
}

function test_is_file_in_list_found() {
  local temp_file
  temp_file=$(mktemp)
  echo "owner/repo" > "$temp_file"
  echo "other/repo" >> "$temp_file"
  assert_equals "true" "$(is_file_in_list "owner/repo" "$temp_file")"
  rm -f "$temp_file"
}

function test_is_file_in_list_not_found() {
  local temp_file
  temp_file=$(mktemp)
  echo "owner/repo" > "$temp_file"
  echo "other/repo" >> "$temp_file"
  assert_equals "false" "$(is_file_in_list "stranger/repo" "$temp_file")"
  rm -f "$temp_file"
}

function test_is_file_in_list_empty_value() {
  local temp_file
  temp_file=$(mktemp)
  echo "owner/repo" > "$temp_file"
  assert_equals "false" "$(is_file_in_list "" "$temp_file")"
  rm -f "$temp_file"
}

function test_is_file_in_list_nonexistent_file() {
  assert_equals "false" "$(is_file_in_list "owner/repo" "/nonexistent/file.txt")"
}

function test_is_file_in_list_with_comments() {
  local temp_file
  temp_file=$(mktemp)
  echo "# This is a comment" > "$temp_file"
  echo "" >> "$temp_file"
  echo "owner/repo" >> "$temp_file"
  assert_equals "true" "$(is_file_in_list "owner/repo" "$temp_file")"
  # is_file_in_list does exact matching, it doesn't filter comments
  # If "# This is a comment" is in the file, it will be found
  assert_equals "true" "$(is_file_in_list "# This is a comment" "$temp_file")"
  rm -f "$temp_file"
}

# ============================================================================
# Tests for repos/ directory structure functions
# ============================================================================

function test_parse_repo_from_index_path() {
  assert_equals "v1nvn/enhansome-go" "$(parse_repo_from_index_path "repos/v1nvn/enhansome-go/index.json")"
}

function test_parse_repo_from_index_path_with_underscores() {
  assert_equals "owner_name/repo_name" "$(parse_repo_from_index_path "repos/owner_name/repo_name/index.json")"
}

function test_parse_repo_from_index_path_with_hyphens() {
  assert_equals "owner-name/repo-name" "$(parse_repo_from_index_path "repos/owner-name/repo-name/index.json")"
}

function test_parse_repo_from_index_path_with_dots() {
  assert_equals "owner/repo.name" "$(parse_repo_from_index_path "repos/owner/repo.name/index.json")"
}

function test_parse_repo_from_index_path_empty() {
  assert_general_error "$(parse_repo_from_index_path "" 2>&1 >/dev/null)"
}

function test_parse_repo_from_index_path_invalid_format() {
  assert_general_error "$(parse_repo_from_index_path "invalid/path.json" 2>&1 >/dev/null)"
}

function test_build_entry_from_index() {
  assert_equals "v1nvn/enhansome-go/README.json" "$(build_entry_from_index "repos/v1nvn/enhansome-go/index.json" "README.json")"
}

function test_build_entry_from_index_nested_path() {
  assert_equals "owner/repo/path/to/file.json" "$(build_entry_from_index "repos/owner/repo/index.json" "path/to/file.json")"
}

function test_build_entry_from_index_empty_filename() {
  assert_general_error "$(build_entry_from_index "repos/owner/repo/index.json" "" 2>&1 >/dev/null)"
}

function test_build_entry_from_index_empty_path() {
  assert_general_error "$(build_entry_from_index "" "README.json" 2>&1 >/dev/null)"
}

function test_validate_index_path_format_valid() {
  assert_equals "true" "$(validate_index_path_format "repos/v1nvn/enhansome-go/index.json")"
}

function test_validate_index_path_format_with_special_chars() {
  assert_equals "true" "$(validate_index_path_format "repos/owner-name/repo.name/index.json")"
}

function test_validate_index_path_format_invalid_no_repos_dir() {
  assert_equals "false" "$(validate_index_path_format "data/owner/repo/index.json")"
}

function test_validate_index_path_format_invalid_not_index_json() {
  assert_equals "false" "$(validate_index_path_format "repos/owner/repo/data.json")"
}

function test_validate_index_path_format_invalid_missing_parts() {
  assert_equals "false" "$(validate_index_path_format "repos/owner/index.json")"
}

function test_validate_index_path_format_invalid_empty() {
  assert_equals "false" "$(validate_index_path_format "")"
}
