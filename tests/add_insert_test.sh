#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/tests/test_helper.sh"
source "$ROOT_DIR/lib/add_command.sh"

fixture="$ROOT_DIR/tests/fixtures/nixos_system_example.nix"
tmp_file="$(mktemp /tmp/ixnay-system.XXXXXX)"
tmp_nomarker=""
tmp_env_block=""
tmp_user=""
tmp_sort=""
tmp_comment=""
tmp_conflict=""
tmp_darwin=""
tmp_darwin_system=""
tmp_darwin_base=""
cleanup() {
	rm -f "$tmp_file"
	if [ -n "$tmp_nomarker" ]; then
		rm -f "$tmp_nomarker"
	fi
	if [ -n "$tmp_env_block" ]; then
		rm -f "$tmp_env_block"
	fi
	if [ -n "$tmp_user" ]; then
		rm -f "$tmp_user"
	fi
	if [ -n "$tmp_sort" ]; then
		rm -f "$tmp_sort"
	fi
	if [ -n "$tmp_comment" ]; then
		rm -f "$tmp_comment"
	fi
	if [ -n "$tmp_conflict" ]; then
		rm -f "$tmp_conflict"
	fi
	if [ -n "$tmp_darwin" ]; then
		rm -f "$tmp_darwin"
	fi
	if [ -n "$tmp_darwin_system" ]; then
		rm -f "$tmp_darwin_system"
	fi
	if [ -n "$tmp_darwin_base" ]; then
		rm -f "$tmp_darwin_base"
	fi
}
trap cleanup EXIT
cp "$fixture" "$tmp_file"

set +e
IXNAY_ADD_PLATFORM=nixos ixnay_add_insert_package "$tmp_file" system "unstable.ripgrep" "Fast search" 2>&1
insert_status=$?
set -e

assert_eq 0 "$insert_status" "insert package succeeds"

block_contents=$(awk '/IXNAY SYSTEM PACKAGES START/{flag=1;next}/IXNAY SYSTEM PACKAGES END/{flag=0}flag' "$tmp_file" | tr -d '\n')
trimmed_block="$(echo "$block_contents" | sed 's/^[[:space:]]*//')"

assert_eq "unstable.ripgrep # Fast search" "$trimmed_block" "inserted line stored with description"


nomarker_fixture="$ROOT_DIR/tests/fixtures/nixos_system_nomarker.nix"
tmp_nomarker="$(mktemp /tmp/ixnay-system-nomarker.XXXXXX)"
cp "$nomarker_fixture" "$tmp_nomarker"

set +e
IXNAY_ADD_PLATFORM=nixos ixnay_add_insert_package "$tmp_nomarker" system "stable.fd" "Find alternative" 2>&1
nomarker_status=$?
set -e

assert_eq 0 "$nomarker_status" "insert package adds markers when missing"

marker_block=$(awk '/IXNAY SYSTEM PACKAGES START/{found=1} /IXNAY SYSTEM PACKAGES END/{if(found){print; exit}} { if(found) print }' "$tmp_nomarker")

echo "$marker_block" | grep -q '# IXNAY SYSTEM PACKAGES START - DO NOT REMOVE'
assert_eq 0 "$?" "start marker present after insertion"

echo "$marker_block" | grep -q 'stable.fd # Find alternative'
assert_eq 0 "$?" "marker block contains inserted package"

env_fixture="$ROOT_DIR/tests/fixtures/nixos_system_environment_attr.nix"
tmp_env_block="$(mktemp /tmp/ixnay-system-env.XXXXXX)"
cp "$env_fixture" "$tmp_env_block"

set +e
IXNAY_ADD_PLATFORM=nixos ixnay_add_insert_package "$tmp_env_block" system "unstable.starship" "Prompt helper" 2>&1
env_status=$?
set -e

assert_eq 0 "$env_status" "insert package handles environment attrset"

env_block=$(awk '/IXNAY SYSTEM PACKAGES START/{flag=1;next}/IXNAY SYSTEM PACKAGES END/{if(flag){flag=0; exit}}flag{print}' "$tmp_env_block" | tr -d '\n')
trimmed_env_block="$(echo "$env_block" | sed 's/^[[:space:]]*//')"
assert_eq "unstable.starship # Prompt helper" "$trimmed_env_block" "environment attrset block contains package"

user_fixture="$ROOT_DIR/tests/fixtures/nixos_two_users_example.nix"
tmp_user="$(mktemp /tmp/ixnay-user.XXXXXX)"
cp "$user_fixture" "$tmp_user"

set +e
IXNAY_ADD_PLATFORM=nixos IXNAY_ADD_USER=sample ixnay_add_insert_package "$tmp_user" user "unstable.direnv" "Direnv hooks" 2>&1
user_status=$?
set -e

assert_eq 0 "$user_status" "insert package targets user block"

user_block=$(awk '/# IXNAY USER PACKAGES \(sample\) START/{flag=1;next}/# IXNAY USER PACKAGES \(sample\) END/{if(flag){flag=0; exit}}flag{print}' "$tmp_user" | tr -d '\n')
trimmed_user_block="$(echo "$user_block" | sed 's/^[[:space:]]*//')"
assert_eq "unstable.direnv # Direnv hooks" "$trimmed_user_block" "user block contains package"

alpha_block=$(awk '/# IXNAY USER PACKAGES \(alpha\) START/{flag=1;next}/# IXNAY USER PACKAGES \(alpha\) END/{if(flag){flag=0; exit}}flag{print}' "$tmp_user" | tr -d '\n')
assert_eq "" "$alpha_block" "other user block untouched"

darwin_fixture="$ROOT_DIR/tests/fixtures/darwin_home_manager_user.nix"
tmp_darwin="$(mktemp /tmp/ixnay-darwin-user.XXXXXX)"
cp "$darwin_fixture" "$tmp_darwin"

set +e
IXNAY_ADD_PLATFORM=macos IXNAY_ADD_USER=sample ixnay_add_insert_package "$tmp_darwin" user "unstable.fzf" "Fuzzy finder" 2>&1
darwin_status=$?
set -e

assert_eq 0 "$darwin_status" "insert package handles nix-darwin home-manager user packages"

darwin_block=$(awk '/# IXNAY USER PACKAGES \(sample\) START/{flag=1;next}/# IXNAY USER PACKAGES \(sample\) END/{if(flag){flag=0; exit}}flag{print}' "$tmp_darwin" | tr -d '\n')
trimmed_darwin_block="$(echo "$darwin_block" | sed 's/^[[:space:]]*//')"
assert_eq "unstable.fzf # Fuzzy finder" "$trimmed_darwin_block" "darwin home-manager block contains package"

darwin_system_fixture="$ROOT_DIR/tests/fixtures/darwin_system_packages.nix"
tmp_darwin_system="$(mktemp /tmp/ixnay-darwin-system.XXXXXX)"
cp "$darwin_system_fixture" "$tmp_darwin_system"

set +e
IXNAY_ADD_PLATFORM=macos IXNAY_ADD_USER=sample ixnay_add_insert_package "$tmp_darwin_system" user "unstable.fzf" "Fuzzy finder" 2>&1
darwin_system_status=$?
set -e

assert_eq 0 "$darwin_system_status" "darwin user scope falls back to system packages list"

darwin_system_block=$(awk '/# IXNAY USER PACKAGES \(sample\) START/{flag=1;next}/# IXNAY USER PACKAGES \(sample\) END/{if(flag){flag=0; exit}}flag{print}' "$tmp_darwin_system" | tr -d '\n')
trimmed_darwin_system_block="$(echo "$darwin_system_block" | sed 's/^[[:space:]]*//')"
assert_eq "unstable.fzf # Fuzzy finder" "$trimmed_darwin_system_block" "darwin system list contains user marker block entry"

darwin_base_fixture="$ROOT_DIR/tests/fixtures/darwin_system_base_list.nix"
tmp_darwin_base="$(mktemp /tmp/ixnay-darwin-base.XXXXXX)"
cp "$darwin_base_fixture" "$tmp_darwin_base"

set +e
IXNAY_ADD_PLATFORM=macos ixnay_add_insert_package "$tmp_darwin_base" system "pkgs.fzf" "Fuzzy finder" 2>&1
darwin_base_status=$?
set -e

assert_eq 0 "$darwin_base_status" "darwin system list resolves through base list binding"

darwin_base_block=$(awk '/# IXNAY SYSTEM PACKAGES START/{flag=1;next}/# IXNAY SYSTEM PACKAGES END/{if(flag){flag=0; exit}}flag{print}' "$tmp_darwin_base" | tr -d '\n')
trimmed_darwin_base_block="$(echo "$darwin_base_block" | sed 's/^[[:space:]]*//')"
assert_eq "pkgs.fzf # Fuzzy finder" "$trimmed_darwin_base_block" "darwin base list contains package"

tmp_sort="$(mktemp /tmp/ixnay-system-sort.XXXXXX)"
cp "$fixture" "$tmp_sort"

set +e
IXNAY_ADD_PLATFORM=nixos ixnay_add_insert_package "$tmp_sort" system "stable.bat" "Editor" 2>&1
first_sort_status=$?
set -e
assert_eq 0 "$first_sort_status" "sort baseline insert succeeds"

set +e
IXNAY_ADD_PLATFORM=nixos ixnay_add_insert_package "$tmp_sort" system "unstable.alacritty" "Terminal" 2>&1
second_sort_status=$?
set -e
assert_eq 0 "$second_sort_status" "sort second insert succeeds"

mapfile -t sort_lines < <(awk '/IXNAY SYSTEM PACKAGES START/{flag=1;next}/IXNAY SYSTEM PACKAGES END/{if(flag){flag=0; exit}}flag{print}' "$tmp_sort")

sorted_first="$(echo "${sort_lines[0]}" | sed 's/^[[:space:]]*//')"
sorted_second="$(echo "${sort_lines[1]}" | sed 's/^[[:space:]]*//')"

assert_eq "unstable.alacritty # Terminal" "$sorted_first" "sorts by package name not branch (first)"
assert_eq "stable.bat # Editor" "$sorted_second" "sorts by package name not branch (second)"

comment_fixture="$ROOT_DIR/tests/fixtures/nixos_user_comment_brackets.nix"
tmp_comment="$(mktemp /tmp/ixnay-user-comment.XXXXXX)"
cp "$comment_fixture" "$tmp_comment"

set +e
IXNAY_ADD_PLATFORM=nixos IXNAY_ADD_USER=sample ixnay_add_insert_package "$tmp_comment" user "master.opencode" "OpenCode agent" 2>&1
comment_status=$?
set -e

assert_eq 0 "$comment_status" "insert succeeds when comments contain brackets"

comment_block=$(awk '/# IXNAY USER PACKAGES \(sample\) START/{flag=1;next}/# IXNAY USER PACKAGES \(sample\) END/{if(flag){flag=0; exit}}flag{print}' "$tmp_comment" | tr -d '\n')
trimmed_comment_block="$(echo "$comment_block" | sed 's/^[[:space:]]*//')"
assert_eq "master.opencode # OpenCode agent" "$trimmed_comment_block" "comment fixture contains package"

broken_fixture="$ROOT_DIR/tests/fixtures/nixos_user_broken_end.nix"
tmp_broken="$(mktemp /tmp/ixnay-user-broken.XXXXXX)"
cp "$broken_fixture" "$tmp_broken"

set +e
IXNAY_ADD_PLATFORM=nixos IXNAY_ADD_USER=sample ixnay_add_insert_package "$tmp_broken" user "stable.bat" "Editor" 2>&1
broken_status=$?
set -e

assert_eq 0 "$broken_status" "insert repairs closing bracket"

marker_line=$(sed -n '/# IXNAY USER PACKAGES (sample) END - DO NOT REMOVE/p' "$tmp_broken" | head -n1 | sed 's/^[[:space:]]*//')
closing_line=$(sed -n '/# IXNAY USER PACKAGES (sample) END - DO NOT REMOVE/{n;p;}' "$tmp_broken" | sed 's/^[[:space:]]*//')
assert_eq "# IXNAY USER PACKAGES (sample) END - DO NOT REMOVE" "$marker_line" "marker line restored without trailing bracket"
assert_eq "];" "$closing_line" "closing line follows marker"

set +e
duplicate_output="$(IXNAY_ADD_PLATFORM=nixos ixnay_add_insert_package "$tmp_sort" system "unstable.alacritty" "Terminal" 2>&1)"
duplicate_status=$?
set -e
assert_eq 0 "$duplicate_status" "duplicate insert exits successfully"
assert_eq "unstable.alacritty already present; skipping" "$duplicate_output" "duplicate insert reports skip"

tmp_conflict="$(mktemp /tmp/ixnay-conflict.XXXXXX)"
cp "$ROOT_DIR/tests/fixtures/nixos_system_with_entries.nix" "$tmp_conflict"

set +e
conflict_output="$(IXNAY_ADD_PLATFORM=nixos ixnay_add_insert_package "$tmp_conflict" system "master.ripgrep" "Fast search alt" 2>&1)"
conflict_status=$?
set -e
assert_eq 1 "$conflict_status" "conflicting channel insert errors"
assert_eq "ripgrep already present via unstable.ripgrep; run 'ixnay remove' first to switch to master.ripgrep" "$conflict_output" "conflicting channel message advises removal"

exit "$_ixnay_test_failures"
