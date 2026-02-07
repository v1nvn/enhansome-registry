#!/bin/bash
# tests/lib/matrix_test.sh
# Tests for lib/matrix.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../scripts/lib/matrix.sh"

function test_parse_safe_filename() {
  assert_equals "owner_repo.json" "$(parse_safe_filename "owner/repo")"
}

function test_parse_safe_filename_with_dots() {
  assert_equals "owner_repo.name.json" "$(parse_safe_filename "owner/repo.name")"
}

function test_parse_safe_filename_with_underscores() {
  assert_equals "owner_name_repo_name.json" "$(parse_safe_filename "owner_name/repo_name")"
}

function test_parse_safe_filename_with_hyphens() {
  assert_equals "owner-name_repo-name.json" "$(parse_safe_filename "owner-name/repo-name")"
}

function test_parse_safe_filename_empty() {
  local result
  result=$(parse_safe_filename "" 2>&1)
  assert_matches "Error:" "$result"
}

# ============================================================================
# Tests for generate_matrix_from_repos (new repos/ directory structure)
# ============================================================================

function test_generate_matrix_from_repos() {
  local temp_dir
  temp_dir=$(mktemp -d)

  # Create test repos structure
  mkdir -p "$temp_dir/owner1/repo1"
  echo '{"filename": "README.json"}' > "$temp_dir/owner1/repo1/index.json"

  mkdir -p "$temp_dir/owner2/repo2"
  echo '{"filename": "docs/file.json"}' > "$temp_dir/owner2/repo2/index.json"

  local result
  result=$(generate_matrix_from_repos "$temp_dir")
  local count
  count=$(echo "$result" | jq 'length')
  assert_equals "2" "$count"

  # Verify entries are correct
  local entry1
  entry1=$(echo "$result" | jq -r '.[0]')
  local entry2
  entry2=$(echo "$result" | jq -r '.[1]')

  # Order may vary, so check both
  if [[ "$entry1" == "owner1/repo1/README.json" ]]; then
    assert_equals "owner2/repo2/docs/file.json" "$entry2"
  else
    assert_equals "owner1/repo1/README.json" "$entry2"
    assert_equals "owner2/repo2/docs/file.json" "$entry1"
  fi

  rm -rf "$temp_dir"
}

function test_generate_matrix_from_repos_empty_directory() {
  local temp_dir
  temp_dir=$(mktemp -d)
  # No repos created

  local result
  result=$(generate_matrix_from_repos "$temp_dir")
  local count
  count=$(echo "$result" | jq 'length')
  assert_equals "0" "$count"

  rm -rf "$temp_dir"
}

function test_generate_matrix_from_repos_nonexistent_directory() {
  local result
  result=$(generate_matrix_from_repos "/nonexistent/dir" 2>&1 >/dev/null)
  assert_general_error "$result"
}

function test_generate_matrix_from_repos_invalid_json() {
  local temp_dir
  temp_dir=$(mktemp -d)

  # Create test repos structure with invalid JSON
  mkdir -p "$temp_dir/owner1/repo1"
  echo 'invalid json' > "$temp_dir/owner1/repo1/index.json"

  # Should skip invalid entries but not fail
  local result
  result=$(generate_matrix_from_repos "$temp_dir" 2>&1)
  # The function should still return valid JSON (possibly empty)
  echo "$result" | jq '.' > /dev/null
  assert_equals "0" "$?"

  rm -rf "$temp_dir"
}
