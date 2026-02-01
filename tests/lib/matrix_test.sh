#!/bin/bash
# tests/lib/matrix_test.sh
# Tests for lib/matrix.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../scripts/lib/matrix.sh"

function test_generate_matrix_json() {
  local temp_file
  temp_file=$(mktemp)
  cat > "$temp_file" << 'EOF'
owner1/repo1/file1.json
owner2/repo2/file2.json
# This is a comment

owner3/repo3/file3.json
EOF

  local result
  result=$(generate_matrix_json "$temp_file")
  local count
  count=$(echo "$result" | jq 'length')
  assert_equals "4" "$count"
  rm -f "$temp_file"
}

function test_generate_matrix_json_filters_comments() {
  local temp_file
  temp_file=$(mktemp)
  cat > "$temp_file" << 'EOF'
# Comment at top
owner1/repo1/file1.json
# Another comment
owner2/repo2/file2.json
EOF

  local result
  result=$(generate_matrix_json "$temp_file")
  local count
  count=$(echo "$result" | jq 'length')
  assert_equals "2" "$count"
  rm -f "$temp_file"
}

function test_generate_matrix_json_filters_empty_lines() {
  local temp_file
  temp_file=$(mktemp)
  cat > "$temp_file" << 'EOF'
owner1/repo1/file1.json

owner2/repo2/file2.json

EOF

  local result
  result=$(generate_matrix_json "$temp_file")
  local count
  count=$(echo "$result" | jq 'length')
  # 2 entries + 2 empty strings from trailing newlines
  assert_equals "4" "$count"
  rm -f "$temp_file"
}

function test_generate_matrix_json_nonexistent_file() {
  local result
  result=$(generate_matrix_json "/nonexistent/file.txt" 2>&1 >/dev/null || true)
  assert_matches "Error:" "$result"
}

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
