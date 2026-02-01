#!/bin/bash
# tests/lib/diff_test.sh
# Tests for lib/diff.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../scripts/lib/diff.sh"

# Test for PR #1 scenario: one line removed and re-added (newline fix) + one new entry
function test_extract_net_new_additions_with_newline_fix() {
  local diff='@@ -1,4 +1,5 @@
 v1nvn/enhansome-selfhosted/README.json
 v1nvn/enhansome-go/README.json
 v1nvn/enhansome-mcp-servers/README.json
-v1nvn/enhansome-ffmpeg/readme.json
\ No newline at end of file
+v1nvn/enhansome-ffmpeg/readme.json
+v1nvn/enhansome-free-for-dev/README.json'

  local result
  result=$(extract_net_new_additions "$diff")
  assert_equals "v1nvn/enhansome-free-for-dev/README.json" "$result"
}

function test_count_net_new_additions_with_newline_fix() {
  local diff='@@ -1,4 +1,5 @@
 v1nvn/enhansome-selfhosted/README.json
 v1nvn/enhansome-go/README.json
 v1nvn/enhansome-mcp-servers/README.json
-v1nvn/enhansome-ffmpeg/readme.json
\ No newline at end of file
+v1nvn/enhansome-ffmpeg/readme.json
+v1nvn/enhansome-free-for-dev/README.json'

  assert_equals "1" "$(count_net_new_additions "$diff")"
}

# Test: Single new entry (no modifications)
function test_extract_net_new_additions_single_new() {
  local diff='@@ -1,3 +1,4 @@
 line1
 line2
+new/entry/file.json'

  local result
  result=$(extract_net_new_additions "$diff")
  assert_equals "new/entry/file.json" "$result"
}

function test_count_net_new_additions_single_new() {
  local diff='@@ -1,3 +1,4 @@
 line1
 line2
+new/entry/file.json'

  assert_equals "1" "$(count_net_new_additions "$diff")"
}

# Test: Multiple new entries
function test_extract_net_new_additions_multiple() {
  local diff='@@ -1,2 +1,4 @@
 line1
+new/entry1/file.json
+new/entry2/file.json
+new/entry3/file.json'

  local result
  result=$(extract_net_new_additions "$diff")
  assert_equals "new/entry1/file.json"$'\n'"new/entry2/file.json"$'\n'"new/entry3/file.json" "$result"
}

function test_count_net_new_additions_multiple() {
  local diff='@@ -1,2 +1,4 @@
 line1
+new/entry1/file.json
+new/entry2/file.json
+new/entry3/file.json'

  assert_equals "3" "$(count_net_new_additions "$diff")"
}

# Test: Only modification (remove and add same line) - should be 0 net new
function test_extract_net_new_additions_only_modification() {
  local diff='@@ -1,2 +1,2 @@
-old/entry/file.json
+old/entry/file.json'

  local result
  result=$(extract_net_new_additions "$diff" || true)
  assert_equals "" "$result"
}

function test_count_net_new_additions_only_modification() {
  local diff='@@ -1,2 +1,2 @@
-old/entry/file.json
+old/entry/file.json'

  assert_equals "0" "$(count_net_new_additions "$diff")"
}

# Test: Empty diff
function test_extract_net_new_additions_empty_diff() {
  local diff=''
  local result
  result=$(extract_net_new_additions "$diff" || true)
  assert_equals "" "$result"
}

function test_count_net_new_additions_empty_diff() {
  local diff=''
  assert_equals "0" "$(count_net_new_additions "$diff")"
}

# Test: Comments are filtered out
function test_count_net_new_additions_filters_comments() {
  local diff='@@ -1,2 +1,4 @@
 line1
+# This is a comment
+new/entry/file.json
+# Another comment'

  assert_equals "1" "$(count_net_new_additions "$diff")"
}

# Test: Empty lines are filtered out
function test_count_net_new_additions_filters_empty() {
  local diff='@@ -1,2 +1,5 @@
 line1
+
+new/entry/file.json
+'

  assert_equals "1" "$(count_net_new_additions "$diff")"
}

# Test: get_entry_from_diff returns first entry
function test_get_entry_from_diff() {
  local diff='@@ -1,2 +1,4 @@
 line1
+first/entry/file.json
+second/entry/file.json'

  assert_equals "first/entry/file.json" "$(get_entry_from_diff "$diff")"
}

# Test: get_entry_from_diff returns empty for no entries
function test_get_entry_from_diff_empty() {
  local diff='@@ -1,2 +1,2 @@
-old/entry/file.json
+old/entry/file.json'

  assert_equals "" "$(get_entry_from_diff "$diff" || true)"
}
