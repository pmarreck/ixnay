#!/usr/bin/env bash
# Verifies `ixnay reify` emits FLAKE-based rebuild commands when the NixOS config
# dir is flake-controlled (flake.nix present), and the legacy channel commands
# otherwise. Uses DRY_RUN so the command is *rendered* (via caution) but not run.
#
# Peter's rule: no `set -e`/`-o pipefail` in test scripts (errexit masks the
# expected non-zero exits of commands-under-test). test_helper.sh turns them on,
# so neutralize right after sourcing and keep `set -u` only.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/tests/test_helper.sh"
set +e +o pipefail
set -u

test_description "ixnay reify: flake vs channel rebuild commands"

IXNAY="$ROOT_DIR/bin/ixnay"

# Render (not run) the reify command; DRY_RUN makes reify echo the command via
# caution and return before executing. IXNAY_DISTRO pins the distro (determinism
# on non-NixOS/CI hosts); IXNAY_NIXOS_DIR points detection at a throwaway dir.
render_reify() { # $1 = nixos_dir ; $2 = flake host ; $3.. = reify args
	local dir="$1"
	local host="$2"
	shift 2
	IXNAY_NO_COLOR=1 IXNAY_DISTRO=nixos DRY_RUN=1 IXNAY_NIXOS_DIR="$dir" IXNAY_NIXOS_FLAKE_HOST="$host" \
		"$IXNAY" reify "$@" 2>&1
}

assert_contains() { # needle haystack desc
	_ixnay_test_total=$((_ixnay_test_total + 1))
	case "$2" in
		*"$1"*) pass_test "$3" ;;
		*) fail_test "$3 (missing '$1' in: $2)" ;;
	esac
}
assert_not_contains() { # needle haystack desc
	_ixnay_test_total=$((_ixnay_test_total + 1))
	case "$2" in
		*"$1"*) fail_test "$3 (unexpected '$1' in: $2)" ;;
		*) pass_test "$3" ;;
	esac
}

# ---- Flake mode: dir contains flake.nix ----
flake_dir="$(mktemp -d "${TMPDIR:-/tmp}/ixnay-flake.XXXXXX")"
: > "$flake_dir/flake.nix"

# NB: the flake ref is quoted in the emitted command (space-safe paths), so
# assertions include the surrounding double quotes deliberately.
out="$(render_reify "$flake_dir" nixos no-upgrade)"
assert_contains   "nixos-rebuild boot --flake \"$flake_dir#nixos\"" "$out" "flake no-upgrade uses quoted --flake ref"
assert_not_contains "--upgrade" "$out" "flake no-upgrade has no --upgrade"

out_up="$(render_reify "$flake_dir" nixos)" # no sub-arg => upgrade path
assert_contains     "nix flake update --flake \"$flake_dir\"" "$out_up" "flake upgrade runs nix flake update on the flake dir"
assert_contains     "--flake \"$flake_dir#nixos\""            "$out_up" "flake upgrade rebuilds via quoted --flake ref"
assert_not_contains "nixos-rebuild boot --upgrade"           "$out_up" "flake upgrade avoids channel --upgrade"

# A host directory may be symlinked from /etc/nixos while flake.nix lives at
# the shared repository root. Resolve the link and search its parent directories.
host_dir="$flake_dir/hosts/framework-nixos"
link_dir="$(mktemp -d "${TMPDIR:-/tmp}/ixnay-link.XXXXXX")"
mkdir -p "$host_dir"
ln -s "$host_dir" "$link_dir/nixos"
out_nested="$(render_reify "$link_dir/nixos" framework-nixos no-upgrade)"
assert_contains "nixos-rebuild boot --flake \"$flake_dir#framework-nixos\"" "$out_nested" "nested symlink config finds parent flake and host output"

# ---- Channel mode: dir lacks flake.nix (legacy behavior unchanged) ----
chan_dir="$(mktemp -d "${TMPDIR:-/tmp}/ixnay-chan.XXXXXX")"

out_c="$(render_reify "$chan_dir" nixos no-upgrade)"
assert_contains     "nixos-rebuild boot" "$out_c" "channel no-upgrade uses plain nixos-rebuild"
assert_not_contains "--flake"            "$out_c" "channel no-upgrade has no --flake"

out_cu="$(render_reify "$chan_dir" nixos)"
assert_contains "nixos-rebuild boot --upgrade" "$out_cu" "channel upgrade uses --upgrade"

rm -rf "$flake_dir" "$link_dir" "$chan_dir"
exit "$_ixnay_test_failures"
