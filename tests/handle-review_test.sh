#!/bin/bash
# tests/handle-review_test.sh
# Tests for handle-review.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/handle-review.sh"

function test_is_lgtm_comment_exact() {
  assert_equals "true" "$(is_lgtm_comment "lgtm")"
}

function test_is_lgtm_comment_uppercase() {
  assert_equals "true" "$(is_lgtm_comment "LGTM")"
}

function test_is_lgtm_comment_mixed_case() {
  assert_equals "true" "$(is_lgtm_comment "LgTm")"
}

function test_is_lgtm_comment_with_whitespace() {
  assert_equals "true" "$(is_lgtm_comment "  lgtm  ")"
}

function test_is_lgtm_comment_with_text() {
  assert_equals "false" "$(is_lgtm_comment "lgtm looks good")"
}

function test_is_lgtm_comment_empty() {
  assert_equals "false" "$(is_lgtm_comment "")"
}

function test_is_lgtm_comment_different() {
  assert_equals "false" "$(is_lgtm_comment "looks good to me")"
}

function test_is_maintainer_valid() {
  assert_equals "true" "$(is_maintainer "v1nvn" "v1nvn,other")"
}

function test_is_maintainer_invalid() {
  assert_equals "false" "$(is_maintainer "stranger" "v1nvn,other")"
}

function test_is_maintainer_empty_user() {
  assert_equals "false" "$(is_maintainer "" "v1nvn,other")"
}

function test_is_maintainer_empty_list() {
  assert_equals "false" "$(is_maintainer "v1nvn" "")"
}
