#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATH="$ROOT_DIR/tests/bin:$PATH"
export PATH

source "$ROOT_DIR/tests/test_helper.sh"

test_description "ixnay describe CLI integration"

export IXNAY_EXPECT_NIX_ARGS="eval --raw nixpkgs#starship.meta.description"
export IXNAY_TEST_NIX_OUTPUT="Prompt helper"

set +e
describe_output="$(IXNAY_NO_COLOR=1 IXNAY_MUTE_CMD_ECHO=1 "$ROOT_DIR/ixnay" describe starship 2>&1)"
describe_status=$?
set -e

assert_eq 0 "$describe_status" "describe exits successfully"
assert_eq "Prompt helper" "$describe_output" "describe prints nix output"

set +e
usage_output="$(IXNAY_NO_COLOR=1 IXNAY_MUTE_CMD_ECHO=1 "$ROOT_DIR/ixnay" describe 2>&1)"
usage_status=$?
set -e

assert_eq 1 "$usage_status" "describe without package errors"
assert_eq "Usage: ixnay describe <package>" "$usage_output" "describe usage message"

exit "$_ixnay_test_failures"
