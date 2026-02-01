#!/bin/bash
# tests/auto-merge_test.sh
# Tests for auto-merge.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/auto-merge.sh"

function test_check_merge_requirements_trusted_author_path() {
  local result
  result=$(check_merge_requirements "repo-ok,no-deny,json-ok,trusted-author")
  assert_equals "true" "$result"
}

function test_check_merge_requirements_lgtm_path() {
  local result
  result=$(check_merge_requirements "repo-ok,no-deny,json-ok,lgtm")
  assert_equals "true" "$result"
}

function test_check_merge_requirements_missing_repo_ok() {
  local result
  result=$(check_merge_requirements "no-deny,json-ok,lgtm")
  assert_equals "false" "$result"
}

function test_check_merge_requirements_missing_no_deny() {
  local result
  result=$(check_merge_requirements "repo-ok,json-ok,lgtm")
  assert_equals "false" "$result"
}

function test_check_merge_requirements_missing_json_ok() {
  local result
  result=$(check_merge_requirements "repo-ok,no-deny,lgtm")
  assert_equals "false" "$result"
}

function test_check_merge_requirements_missing_trust_and_lgtm() {
  local result
  result=$(check_merge_requirements "repo-ok,no-deny,json-ok")
  assert_equals "false" "$result"
}

function test_check_merge_requirements_empty_labels() {
  local result
  result=$(check_merge_requirements "")
  assert_equals "false" "$result"
}

function test_check_merge_requirements_partial_label_match_fails() {
  # Should not match "repo-ok-something" when looking for "repo-ok"
  local result
  result=$(check_merge_requirements "repo-ok-something,no-deny,json-ok,lgtm")
  assert_equals "false" "$result"
}

function test_check_merge_requirements_with_extra_labels() {
  local result
  result=$(check_merge_requirements "repo-ok,no-deny,json-ok,trusted-author,extra-label")
  assert_equals "true" "$result"
}
