#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATH="$ROOT_DIR/tests/bin:$PATH"
export PATH

source "$ROOT_DIR/tests/test_helper.sh"
source "$ROOT_DIR/lib/add_command.sh"

test_description "ixnay remove CLI integration"

fixture="$ROOT_DIR/tests/fixtures/nixos_two_users_example.nix"
tmp_cli="$(mktemp /tmp/ixnay-remove-cli.XXXXXX)"
cleanup() {
	rm -f "$tmp_cli"
}
trap cleanup EXIT
cp "$fixture" "$tmp_cli"

IXNAY_ADD_PLATFORM=nixos IXNAY_ADD_USER=sample ixnay_add_insert_package "$tmp_cli" user "stable.ripgrep" "Fast search tool"

set +e
IXNAY_ADD_PLATFORM=nixos IXNAY_NIXOS_CONFIG="$tmp_cli" IXNAY_ADD_USER=sample IXNAY_MUTE_CMD_ECHO=1 "$ROOT_DIR/bin/ixnay" remove user stable ripgrep 2>&1
cli_status=$?
set -e

assert_eq 0 "$cli_status" "cli remove exits successfully"

user_block=$(awk '/# IXNAY USER PACKAGES \(sample\) START/{flag=1;next}/# IXNAY USER PACKAGES \(sample\) END/{if(flag){flag=0; exit}}flag{print}' "$tmp_cli")
assert_eq "" "$user_block" "cli remove deletes package line"

exit "$_ixnay_test_failures"
