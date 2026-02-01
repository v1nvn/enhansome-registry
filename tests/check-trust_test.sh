#!/bin/bash
# tests/check-trust_test.sh
# Tests for check-trust.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/check-trust.sh"

function test_is_author_trusted_valid() {
  assert_equals "true" "$(is_author_trusted "v1nvn" "v1nvn,other")"
}

function test_is_author_trusted_multiple_users() {
  assert_equals "true" "$(is_author_trusted "other" "v1nvn,other,another")"
}

function test_is_author_trusted_invalid() {
  assert_equals "false" "$(is_author_trusted "stranger" "v1nvn,other")"
}

function test_is_author_trusted_empty_author() {
  assert_equals "false" "$(is_author_trusted "" "v1nvn,other")"
}

function test_is_author_trusted_empty_list() {
  assert_equals "false" "$(is_author_trusted "v1nvn" "")"
}

function test_is_author_trusted_partial_match_fails() {
  assert_equals "false" "$(is_author_trusted "v1n" "v1nvn,other")"
}
