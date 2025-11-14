#!/usr/bin/env bash

set -euo pipefail

_ixnay_test_failures=0
_ixnay_test_total=0

test_description() {
	printf '%s\n' "$1"
}

fail_test() {
	local message="$1"
	echo "not ok - $message"
	_ixnay_test_failures=$((_ixnay_test_failures + 1))
}

pass_test() {
	local message="$1"
	echo "ok - $message"
}

assert_eq() {
	local expected="$1"
	local actual="$2"
	local description="$3"
	_ixnay_test_total=$((_ixnay_test_total + 1))
	if [ "$expected" != "$actual" ]; then
		fail_test "$description (expected '$expected', got '$actual')"
	else
		pass_test "$description"
	fi
}

assert_status() {
	local expected="$1"
	local fn="$2"
	shift 2
	_ixnay_test_total=$((_ixnay_test_total + 1))
	if "$fn" "$@"; then
		status=0
	else
		status=$?
	fi
	if [ "$status" -ne "$expected" ]; then
		fail_test "$fn returned $status (expected $expected)"
	else
		pass_test "$fn returned expected status $expected"
	fi
}
