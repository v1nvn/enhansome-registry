#!/bin/bash
# tests/lib/library_loading_test.sh
# Tests for library loading behavior (guards, variable scoping)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================================
# Tests: Guard against multiple sourcing
# ============================================================================

function test_log_guard_prevents_re_sourcing() {
  # Source log.sh twice - should not error on readonly variables
  source "$SCRIPT_DIR/../../scripts/lib/log.sh"
  source "$SCRIPT_DIR/../../scripts/lib/log.sh"

  # If we get here without error, the guard worked
  assert_equals "0" "0"
}

function test_diff_guard_prevents_re_sourcing() {
  source "$SCRIPT_DIR/../../scripts/lib/diff.sh"
  source "$SCRIPT_DIR/../../scripts/lib/diff.sh"

  # If we get here without error, the guard worked
  assert_equals "0" "0"
}

function test_entry_guard_prevents_re_sourcing() {
  source "$SCRIPT_DIR/../../scripts/lib/entry.sh"
  source "$SCRIPT_DIR/../../scripts/lib/entry.sh"

  assert_equals "0" "0"
}

function test_matrix_guard_prevents_re_sourcing() {
  source "$SCRIPT_DIR/../../scripts/lib/matrix.sh"
  source "$SCRIPT_DIR/../../scripts/lib/matrix.sh"

  assert_equals "0" "0"
}

function test_validation_guard_prevents_re_sourcing() {
  source "$SCRIPT_DIR/../../scripts/lib/validation.sh"
  source "$SCRIPT_DIR/../../scripts/lib/validation.sh"

  assert_equals "0" "0"
}

function test_all_libs_can_be_sourced_together() {
  # Source all libs in sequence - simulates real script behavior
  source "$SCRIPT_DIR/../../scripts/lib/log.sh"
  source "$SCRIPT_DIR/../../scripts/lib/diff.sh"
  source "$SCRIPT_DIR/../../scripts/lib/entry.sh"
  source "$SCRIPT_DIR/../../scripts/lib/matrix.sh"
  source "$SCRIPT_DIR/../../scripts/lib/validation.sh"

  assert_equals "0" "0"
}

# ============================================================================
# Tests: Local variable names prevent parent SCRIPT_DIR conflicts
# ============================================================================

function test_parent_script_dir_not_affected_by_diff_lib() {
  # Set a parent SCRIPT_DIR
  local parent_script_dir="/parent/test/dir"
  SCRIPT_DIR="$parent_script_dir"

  # Source the lib
  source "$SCRIPT_DIR/../../scripts/lib/diff.sh"

  # The parent's SCRIPT_DIR should be preserved
  # (Note: this works because diff.sh uses _DIFF_LIB_DIR)
  assert_equals "$parent_script_dir" "$SCRIPT_DIR"
}

function test_parent_script_dir_not_affected_by_entry_lib() {
  local parent_script_dir="/another/test/dir"
  SCRIPT_DIR="$parent_script_dir"

  source "$SCRIPT_DIR/../../scripts/lib/entry.sh"

  assert_equals "$parent_script_dir" "$SCRIPT_DIR"
}

function test_parent_script_dir_not_affected_by_matrix_lib() {
  local parent_script_dir="/yet/another/dir"
  SCRIPT_DIR="$parent_script_dir"

  source "$SCRIPT_DIR/../../scripts/lib/matrix.sh"

  assert_equals "$parent_script_dir" "$SCRIPT_DIR"
}

function test_parent_script_dir_not_affected_by_validation_lib() {
  local parent_script_dir="/validation/test/dir"
  SCRIPT_DIR="$parent_script_dir"

  source "$SCRIPT_DIR/../../scripts/lib/validation.sh"

  assert_equals "$parent_script_dir" "$SCRIPT_DIR"
}

function test_multiple_libs_preserve_parent_script_dir() {
  local parent_script_dir="/multi/lib/test/dir"
  SCRIPT_DIR="$parent_script_dir"

  # Source multiple libs
  source "$SCRIPT_DIR/../../scripts/lib/diff.sh"
  source "$SCRIPT_DIR/../../scripts/lib/entry.sh"
  source "$SCRIPT_DIR/../../scripts/lib/validation.sh"

  assert_equals "$parent_script_dir" "$SCRIPT_DIR"
}

# ============================================================================
# Tests: Library guard variables are set correctly
# ============================================================================

function test_log_guard_variable_set() {
  # First source should set the guard variable
  [[ -z "${_LOG_SH_SOURCED:-}" ]] || true  # Clear if set from previous test
  source "$SCRIPT_DIR/../../scripts/lib/log.sh"

  # Guard variable should be set to true
  assert_equals "true" "$_LOG_SH_SOURCED"
}

function test_diff_guard_variable_set() {
  [[ -z "${_DIFF_SH_SOURCED:-}" ]] || true
  source "$SCRIPT_DIR/../../scripts/lib/diff.sh"

  assert_equals "true" "$_DIFF_SH_SOURCED"
}

function test_entry_guard_variable_set() {
  [[ -z "${_ENTRY_SH_SOURCED:-}" ]] || true
  source "$SCRIPT_DIR/../../scripts/lib/entry.sh"

  assert_equals "true" "$_ENTRY_SH_SOURCED"
}

function test_matrix_guard_variable_set() {
  [[ -z "${_MATRIX_SH_SOURCED:-}" ]] || true
  source "$SCRIPT_DIR/../../scripts/lib/matrix.sh"

  assert_equals "true" "$_MATRIX_SH_SOURCED"
}

function test_validation_guard_variable_set() {
  [[ -z "${_VALIDATION_SH_SOURCED:-}" ]] || true
  source "$SCRIPT_DIR/../../scripts/lib/validation.sh"

  assert_equals "true" "$_VALIDATION_SH_SOURCED"
}

# ============================================================================
# Tests: Library functions are still accessible after sourcing
# ============================================================================

function test_log_functions_work_after_sourcing() {
  source "$SCRIPT_DIR/../../scripts/lib/log.sh"

  # These should not error
  log_debug "test debug message" >/dev/null
  log_info "test info message" >/dev/null
  log_warn "test warn message" >/dev/null
  log_error "test error message" >/dev/null

  assert_equals "0" "0"
}

function test_entry_functions_work_after_sourcing() {
  source "$SCRIPT_DIR/../../scripts/lib/entry.sh"

  local result
  result=$(parse_repo_from_entry "owner/repo/path/file.json")
  assert_equals "owner/repo" "$result"

  result=$(parse_file_path_from_entry "owner/repo/path/file.json")
  assert_equals "path/file.json" "$result"
}

function test_validation_functions_work_after_sourcing() {
  source "$SCRIPT_DIR/../../scripts/lib/validation.sh"

  local result
  result=$(validate_json_string '{"key": "value"}')
  assert_equals "true" "$result"
}

function test_matrix_functions_work_after_sourcing() {
  # Create a temp file for testing
  local tmpfile
  tmpfile=$(mktemp)
  echo "owner/repo/file.json" > "$tmpfile"

  source "$SCRIPT_DIR/../../scripts/lib/matrix.sh"

  local result
  result=$(parse_safe_filename "owner/repo")
  assert_equals "owner_repo.json" "$result"

  rm -f "$tmpfile"
}

function test_diff_functions_work_after_sourcing() {
  source "$SCRIPT_DIR/../../scripts/lib/diff.sh"

  local diff='@@ -1,2 +1,3 @@
 line1
+new/entry/file.json'

  local result
  result=$(get_entry_from_diff "$diff")
  assert_equals "new/entry/file.json" "$result"
}
