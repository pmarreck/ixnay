#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/tests/test_helper.sh"
source "$ROOT_DIR/lib/add_command.sh"

test_description "ixnay remove helper"

fixture="$ROOT_DIR/tests/fixtures/nixos_system_with_entries.nix"
tmp_remove="$(mktemp /tmp/ixnay-remove.XXXXXX)"
cleanup() {
	rm -f "$tmp_remove"
}
trap cleanup EXIT
cp "$fixture" "$tmp_remove"

set +e
IXNAY_ADD_PLATFORM=nixos ixnay_add_remove_package "$tmp_remove" system "stable.bat" 2>&1
remove_status=$?
set -e

assert_eq 0 "$remove_status" "remove helper succeeds"

remaining_line=$(awk '/IXNAY SYSTEM PACKAGES START/{flag=1;next}/IXNAY SYSTEM PACKAGES END/{if(flag){flag=0; exit}}flag{print}' "$tmp_remove" | sed 's/^[[:space:]]*//')
assert_eq "unstable.ripgrep # Fast search" "$remaining_line" "remove helper leaves other entries"

set +e
IXNAY_ADD_PLATFORM=nixos ixnay_add_remove_package "$tmp_remove" system "stable.bat" 2>&1
second_remove_status=$?
set -e

assert_eq 1 "$second_remove_status" "remove helper errors when package missing"

exit "$_ixnay_test_failures"
