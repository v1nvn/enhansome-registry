#!/bin/bash
# tests/lib/dry_run_test.sh
# Tests for dry_run.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../scripts/lib/dry_run.sh"

function test_is_dry_run_returns_true_when_env_set() {
  DRY_RUN=true
  assert_equals "true" "$(is_dry_run)"
}

function test_is_dry_run_returns_true_when_env_set_to_1() {
  DRY_RUN=1
  assert_equals "true" "$(is_dry_run)"
}

function test_is_dry_run_returns_false_when_env_set_to_false() {
  DRY_RUN=false
  assert_equals "false" "$(is_dry_run)"
}

function test_is_dry_run_returns_false_when_env_set_to_0() {
  DRY_RUN=0
  assert_equals "false" "$(is_dry_run)"
}

function test_dry_run_guard_variable_is_set() {
  assert_equals "true" "$_DRY_RUN_SH_SOURCED"
}
