#!/bin/bash
# tests/lib/merge_requirements_test.sh
# Tests for lib/merge_requirements.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$SCRIPT_DIR/scripts/lib/merge_requirements.sh"

# Test: Check merge requirements with all labels including trusted-author
test_check_merge_requirements_trusted_author() {
  local labels="repo-ok,no-deny,json-ok,trusted-author"
  local result
  result=$(check_merge_requirements "$labels")
  assert_equals "true" "$result"
}

# Test: Check merge requirements with all labels including lgtm
test_check_merge_requirements_lgtm() {
  local labels="repo-ok,no-deny,json-ok,lgtm"
  local result
  result=$(check_merge_requirements "$labels")
  assert_equals "true" "$result"
}

# Test: Check merge requirements missing repo-ok
test_check_merge_requirements_missing_repo_ok() {
  local labels="no-deny,json-ok,trusted-author"
  local result
  result=$(check_merge_requirements "$labels")
  assert_equals "false" "$result"
}

# Test: Check merge requirements missing no-deny
test_check_merge_requirements_missing_no_deny() {
  local labels="repo-ok,json-ok,trusted-author"
  local result
  result=$(check_merge_requirements "$labels")
  assert_equals "false" "$result"
}

# Test: Check merge requirements missing json-ok
test_check_merge_requirements_missing_json_ok() {
  local labels="repo-ok,no-deny,trusted-author"
  local result
  result=$(check_merge_requirements "$labels")
  assert_equals "false" "$result"
}

# Test: Check merge requirements missing both trust labels
test_check_merge_requirements_missing_trust() {
  local labels="repo-ok,no-deny,json-ok"
  local result
  result=$(check_merge_requirements "$labels")
  assert_equals "false" "$result"
}

# Test: Check merge requirements with empty labels
test_check_merge_requirements_empty_labels() {
  local labels=""
  local result
  result=$(check_merge_requirements "$labels")
  assert_equals "false" "$result"
}

# Test: Check merge requirements with extra labels
test_check_merge_requirements_extra_labels() {
  local labels="repo-ok,no-deny,json-ok,trusted-author,enhancement,priority-high"
  local result
  result=$(check_merge_requirements "$labels")
  assert_equals "true" "$result"
}

# Test: Check merge requirements partial label match fails
test_check_merge_requirements_partial_match() {
  local labels="repo-ok-ish,no-deny,json-ok,trusted-author"
  local result
  result=$(check_merge_requirements "$labels")
  assert_equals "false" "$result"
}
