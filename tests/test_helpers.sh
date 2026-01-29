#!/bin/bash
# test_helpers.sh — Shared test infrastructure for macjuice integration tests

# Resolve path to the macjuice CLI relative to this helper file
MACJUICE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/macjuice"

# Timeout in seconds — override with MACJUICE_TEST_TIMEOUT env var
_TIMEOUT="${MACJUICE_TEST_TIMEOUT:-30}"

# Counters
_PASS=0
_FAIL=0
_SKIP=0

# Colors
_GREEN='\033[0;32m'
_RED='\033[0;31m'
_YELLOW='\033[1;33m'
_NC='\033[0m'

# _run_cmd <cmd...>
# Run a command with a timeout. Stdout goes to $_CMD_OUTPUT, exit code is returned.
# Sets _CMD_TIMED_OUT=1 if the command was killed by the watchdog.
# macOS has no GNU timeout, so we use background process + watchdog.
_CMD_OUTPUT=""
_CMD_TIMED_OUT=0

_run_cmd() {
    local tmpfile flagfile
    tmpfile=$(mktemp)
    flagfile=$(mktemp)
    _CMD_TIMED_OUT=0

    # Run command in background, capture stdout to tmpfile
    "$@" >"$tmpfile" 2>/dev/null &
    local cmd_pid=$!

    # Watchdog: kill command after timeout and leave a flag file
    ( sleep "$_TIMEOUT" && kill "$cmd_pid" 2>/dev/null && echo 1 >"$flagfile" ) &
    local dog_pid=$!
    disown "$dog_pid" 2>/dev/null

    # Wait for the command to finish (or be killed).
    # Suppress bash "Terminated" job-control messages.
    wait "$cmd_pid" 2>/dev/null
    local rc=$?

    # Kill the watchdog if it's still running (disowned, so no wait needed)
    kill "$dog_pid" 2>/dev/null

    # Detect timeout via the flag file (avoids kill -0 race)
    if [[ -s "$flagfile" ]]; then
        _CMD_TIMED_OUT=1
        rc=124
    fi

    _CMD_OUTPUT=$(cat "$tmpfile")
    rm -f "$tmpfile" "$flagfile"
    return $rc
}

_timeout_hint="timed out after ${_TIMEOUT}s — grant Automation permission if macOS prompted"

# assert_exit_zero <description> <cmd...>
# Pass if the command exits 0 within the timeout.
assert_exit_zero() {
    local desc="$1"; shift
    if _run_cmd "$@"; then
        echo -e "  ${_GREEN}PASS${_NC}  $desc"
        ((_PASS++))
    elif [[ $_CMD_TIMED_OUT -eq 1 ]]; then
        echo -e "  ${_RED}FAIL${_NC}  $desc"
        echo "        $_timeout_hint"
        ((_FAIL++))
    else
        echo -e "  ${_RED}FAIL${_NC}  $desc"
        echo "        command: $*"
        ((_FAIL++))
    fi
}

# assert_output_matches <description> <grep_pattern> <cmd...>
# Pass if exit 0 AND stdout matches the extended grep pattern.
assert_output_matches() {
    local desc="$1"; shift
    local pattern="$1"; shift
    if _run_cmd "$@" && echo "$_CMD_OUTPUT" | grep -qE "$pattern"; then
        echo -e "  ${_GREEN}PASS${_NC}  $desc"
        ((_PASS++))
    elif [[ $_CMD_TIMED_OUT -eq 1 ]]; then
        echo -e "  ${_RED}FAIL${_NC}  $desc"
        echo "        $_timeout_hint"
        ((_FAIL++))
    else
        echo -e "  ${_RED}FAIL${_NC}  $desc"
        echo "        pattern: $pattern"
        echo "        output:  ${_CMD_OUTPUT:-(empty)}"
        ((_FAIL++))
    fi
}

# assert_output_not_empty <description> <cmd...>
# Pass if exit 0 AND stdout is non-empty.
assert_output_not_empty() {
    local desc="$1"; shift
    if _run_cmd "$@" && [[ -n "$_CMD_OUTPUT" ]]; then
        echo -e "  ${_GREEN}PASS${_NC}  $desc"
        ((_PASS++))
    elif [[ $_CMD_TIMED_OUT -eq 1 ]]; then
        echo -e "  ${_RED}FAIL${_NC}  $desc"
        echo "        $_timeout_hint"
        ((_FAIL++))
    else
        echo -e "  ${_RED}FAIL${_NC}  $desc"
        echo "        output:  ${_CMD_OUTPUT:-(empty)}"
        ((_FAIL++))
    fi
}

# skip_test <description> <reason>
# Record a skipped test.
skip_test() {
    local desc="$1"
    local reason="$2"
    echo -e "  ${_YELLOW}SKIP${_NC}  $desc — $reason"
    ((_SKIP++))
}

# print_summary <suite_name>
# Print results and return non-zero if any failures.
print_summary() {
    local name="$1"
    local total=$((_PASS + _FAIL + _SKIP))
    echo ""
    echo "--- $name: $total tests | ${_PASS} passed | ${_FAIL} failed | ${_SKIP} skipped ---"
    [[ $_FAIL -eq 0 ]]
}
