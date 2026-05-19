#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/tests/test_helper.sh"

test_description "ixnay meta commands"

stub_runner="$(mktemp /tmp/ixnay-test-runner.XXXXXX)"
cleanup() {
	[ -f "$stub_runner" ] && rm -f "$stub_runner"
}
trap cleanup EXIT

cat <<'RUNNER' > "$stub_runner"
#!/usr/bin/env bash
printf 'stub test runner invoked %s\n' "$*"
exit 3
RUNNER
chmod +x "$stub_runner"

set +e
loud_output="$(IXNAY_NO_COLOR=1 IXNAY_MUTE_CMD_ECHO=1 IXNAY_TEST_RUNNER="$stub_runner" "$ROOT_DIR/bin/ixnay" test foo 2>&1)"
loud_status=$?
set -e
assert_eq 3 "$loud_status" "ixnay test propagates runner exit status"
assert_eq "stub test runner invoked foo" "$loud_output" "ixnay test streams runner output"

set +e
muted_output="$(IXNAY_NO_COLOR=1 IXNAY_MUTE_CMD_ECHO=1 IXNAY_TEST_RUNNER="$stub_runner" "$ROOT_DIR/bin/ixnay" --test bar 2>&1)"
muted_status=$?
set -e
assert_eq 3 "$muted_status" "ixnay --test propagates runner exit status"
assert_eq "" "$muted_output" "ixnay --test mutes runner output"

ABOUT_LINE="IXNAY: A sane, beginner-friendly wrapper for nix-shell, nix and friends."

set +e
about_short="$(IXNAY_NO_COLOR=1 "$ROOT_DIR/bin/ixnay" -a 2>&1)"
about_short_status=$?
set -e
assert_eq 0 "$about_short_status" "ixnay -a exits successfully"
assert_eq "$ABOUT_LINE" "$about_short" "ixnay -a prints about line"

set +e
about_long="$(IXNAY_NO_COLOR=1 "$ROOT_DIR/bin/ixnay" --about 2>&1)"
about_long_status=$?
set -e
assert_eq 0 "$about_long_status" "ixnay --about exits successfully"
assert_eq "$ABOUT_LINE" "$about_long" "ixnay --about prints about line"

exit "$_ixnay_test_failures"
