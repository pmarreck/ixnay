#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATH="$ROOT_DIR/tests/bin:$PATH"
export PATH

source "$ROOT_DIR/tests/test_helper.sh"
source "$ROOT_DIR/lib/add_command.sh"

test_description "ixnay add fetches package descriptions"

export IXNAY_EXPECT_NIX_ARGS="eval --raw nixpkgs#ripgrep.meta.description"
export IXNAY_TEST_NIX_OUTPUT="Fast search tool"

set +e
desc_output="$(ixnay_add_fetch_description unstable ripgrep 2>&1)"
desc_status=$?
set -e

assert_eq 0 "$desc_status" "description fetch succeeds"
assert_eq "Fast search tool" "$desc_output" "description fetch returns nix output"

exit "$_ixnay_test_failures"
