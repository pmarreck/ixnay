#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/tests/test_helper.sh"
source "$ROOT_DIR/lib/add_command.sh"

test_description "ixnay add target file detection"

set +e
target_output="$(IXNAY_ADD_PLATFORM=nixos IXNAY_NIXOS_CONFIG=/tmp/test-config ixnay_add_target_file system 2>&1)"
target_status=$?
set -e

assert_eq 0 "$target_status" "target file resolves for nixos system scope"
assert_eq "/tmp/test-config" "$target_output" "target file uses nixos override path"

exit "$_ixnay_test_failures"
