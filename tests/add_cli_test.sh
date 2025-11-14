#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATH="$ROOT_DIR/tests/bin:$PATH"
export PATH

source "$ROOT_DIR/tests/test_helper.sh"

test_description "ixnay add CLI integration"

config_fixture="$ROOT_DIR/tests/fixtures/nixos_two_users_example.nix"
tmp_cli="$(mktemp /tmp/ixnay-cli.XXXXXX)"
cleanup() {
	rm -f "$tmp_cli"
}
trap cleanup EXIT
cp "$config_fixture" "$tmp_cli"

export IXNAY_EXPECT_NIX_ARGS="eval --raw nixpkgs#ripgrep.meta.description"
export IXNAY_TEST_NIX_OUTPUT="Fast search tool"

set +e
add_output="$(IXNAY_NO_COLOR=1 IXNAY_ADD_PLATFORM=nixos IXNAY_NIXOS_CONFIG="$tmp_cli" IXNAY_ADD_USER=sample IXNAY_MUTE_CMD_ECHO=1 "$ROOT_DIR/ixnay" add user stable ripgrep 2>&1)"
cli_status=$?
set -e

assert_eq 0 "$cli_status" "cli add exits successfully"
assert_eq "Added stable.ripgrep to sample's packages in $tmp_cli" "$add_output" "cli add prints success message"

set +e
duplicate_output="$(IXNAY_NO_COLOR=1 IXNAY_ADD_PLATFORM=nixos IXNAY_NIXOS_CONFIG="$tmp_cli" IXNAY_ADD_USER=sample IXNAY_MUTE_CMD_ECHO=1 "$ROOT_DIR/ixnay" add user stable ripgrep 2>&1)"
duplicate_status=$?
set -e

assert_eq 0 "$duplicate_status" "duplicate cli add exits successfully"
assert_eq "stable.ripgrep already present; skipping" "$duplicate_output" "duplicate cli add reports skip"

set +e
conflict_output="$(IXNAY_NO_COLOR=1 IXNAY_ADD_PLATFORM=nixos IXNAY_NIXOS_CONFIG="$tmp_cli" IXNAY_ADD_USER=sample IXNAY_MUTE_CMD_ECHO=1 "$ROOT_DIR/ixnay" add user master ripgrep 2>&1)"
conflict_status=$?
set -e

assert_eq 1 "$conflict_status" "conflicting channel cli add errors"
assert_eq "ripgrep already present via stable.ripgrep; run 'ixnay remove' first to switch to master.ripgrep" "$conflict_output" "conflicting cli add advises removal"

user_block=$(awk '/# IXNAY USER PACKAGES \(sample\) START/{flag=1;next}/# IXNAY USER PACKAGES \(sample\) END/{if(flag){flag=0; exit}}flag{print}' "$tmp_cli" | sed 's/^[[:space:]]*//')
assert_eq "stable.ripgrep # Fast search tool" "$user_block" "cli add inserts package in user block"

exit "$_ixnay_test_failures"
