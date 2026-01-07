#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/tests/test_helper.sh"
source "$ROOT_DIR/lib/add_command.sh"

test_description "ixnay add argument parsing"

set +e
parse_output="$(ixnay_add_parse_args user stable ripgrep 2>&1)"
parse_status=$?
set -e

assert_eq 0 "$parse_status" "parse args succeeds for ordered inputs"
assert_eq "user stable ripgrep" "$parse_output" "parse args returns normalized tokens"

set +e
unordered_output="$(ixnay_add_parse_args ripgrep unstable user 2>&1)"
unordered_status=$?
set -e

assert_eq 0 "$unordered_status" "parse args succeeds for unordered inputs"
assert_eq "user unstable ripgrep" "$unordered_output" "parse args normalizes unordered tokens"

set +e
mac_output="$(IXNAY_ADD_PLATFORM=macos ixnay_add_parse_args system stable ripgrep 2>&1)"
mac_status=$?
set -e

assert_eq 0 "$mac_status" "parse args accepts system scope on macos"
assert_eq "system stable ripgrep" "$mac_output" "parse args returns tokens for macos system scope"

exit "$_ixnay_test_failures"
