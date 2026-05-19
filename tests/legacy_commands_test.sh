#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/tests/test_helper.sh"

strip_output() {
	printf '%s' "$1" | sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g'
}

test_description "legacy command dry-run emission"

set +e
install_out="$(IXNAY_NO_COLOR=1 DRY_RUN=1 "$ROOT_DIR/bin/ixnay" install ripgrep 2>&1)"
install_status=$?
set -e

assert_eq 0 "$install_status" "install exits successfully in dry run"
assert_eq 0 "$(printf '%s' "$install_out" | grep -q $'\033' && echo 1 || echo 0)" "install output omits ANSI when IXNAY_NO_COLOR set"
assert_eq "nix profile install nixpkgs#ripgrep" "$(strip_output "$install_out" | tr -s ' ')" "install command is echoed"

set +e
uninstall_out="$(IXNAY_NO_COLOR=1 DRY_RUN=1 "$ROOT_DIR/bin/ixnay" uninstall ripgrep 2>&1)"
uninstall_status=$?
set -e

assert_eq 0 "$uninstall_status" "uninstall exits successfully in dry run"
assert_eq "nix profile remove ripgrep" "$(strip_output "$uninstall_out" | tr -s ' ')" "uninstall command is echoed"

set +e
add_channel_out="$(IXNAY_NO_COLOR=1 DRY_RUN=1 "$ROOT_DIR/bin/ixnay" add-channel mychan https://example.com/nix 2>&1)"
add_channel_status=$?
set -e

assert_eq 0 "$add_channel_status" "add-channel exits successfully in dry run"
add_channel_cmd="$(strip_output "$add_channel_out" | tail -n1 | tr -s ' ')"
assert_eq "nix-channel --add \"https://example.com/nix\" \"mychan\"" "$add_channel_cmd" "add-channel command is echoed"

set +e
remove_channel_out="$(IXNAY_NO_COLOR=1 DRY_RUN=1 "$ROOT_DIR/bin/ixnay" remove-channel mychan 2>&1)"
remove_channel_status=$?
set -e

assert_eq 0 "$remove_channel_status" "remove-channel exits successfully in dry run"
remove_channel_cmd="$(strip_output "$remove_channel_out" | tail -n1 | tr -s ' ')"
assert_eq "nix-channel --remove \"mychan\"" "$remove_channel_cmd" "remove-channel command is echoed"

set +e
sync_out="$(IXNAY_NO_COLOR=1 DRY_RUN=1 "$ROOT_DIR/bin/ixnay" sync 2>&1)"
sync_status=$?
set -e

assert_eq 0 "$sync_status" "sync exits successfully in dry run"
sync_cmd="$(strip_output "$sync_out" | tail -n1 | tr -s ' ' | sed 's/[[:space:]]*$//')"
assert_eq "nix-channel --update" "$sync_cmd" "sync command is echoed"

exit "$_ixnay_test_failures"
