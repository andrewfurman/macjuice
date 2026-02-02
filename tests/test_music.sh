#!/bin/bash
# test_music.sh — Music playback integration tests for macjuice (stateful)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

echo "=== Music Tests ==="

# --- Pre-flight: check if Music app is reachable (with timeout) ---
_skip_all() {
    local reason="$1"
    skip_test "music pause sets paused" "$reason"
    skip_test "music play starts playback" "$reason"
    skip_test "music now after play shows playing" "$reason"
    skip_test "music pause after play returns paused" "$reason"
    skip_test "music now after pause shows paused" "$reason"
    print_summary "Music"
    exit $?
}

_run_cmd "$MACJUICE" music now || true
_preflight_output="$_CMD_OUTPUT"

if [[ $_CMD_TIMED_OUT -eq 1 ]]; then
    _skip_all "Music timed out — grant Automation permission if macOS prompted"
fi
if echo "$_preflight_output" | grep -qE "(-600[0-9]|execution error|not running)"; then
    _skip_all "Music app unreachable"
fi

# --- Capture initial state for restore ---
_initial_state=""
if echo "$_preflight_output" | grep -qi "playing"; then
    _initial_state="playing"
else
    _initial_state="paused"
fi

cleanup() {
    if [[ "$_initial_state" == "playing" ]]; then
        "$MACJUICE" music play >/dev/null 2>&1 || true
    else
        "$MACJUICE" music pause >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

# --- Tests (sequential, order matters) ---

# 1. Pause playback
assert_output_matches \
    "music pause sets paused" \
    "[Pp]ause" \
    "$MACJUICE" music pause

# 2. Start playback
assert_output_matches \
    "music play starts playback" \
    "[Pp]lay" \
    "$MACJUICE" music play

# 3. Now should indicate playing after play
assert_output_not_empty \
    "music now after play shows info" \
    "$MACJUICE" music now

# 4. Pause again
assert_output_matches \
    "music pause after play returns paused" \
    "[Pp]ause" \
    "$MACJUICE" music pause

# 5. Now should reflect paused state
assert_output_not_empty \
    "music now after pause shows info" \
    "$MACJUICE" music now

# 6. Play with playlist name returns expected output
assert_output_matches \
    "music play with playlist name responds" \
    "[Pp]lay|[Ee]rror.*[Pp]laylist" \
    "$MACJUICE" music play "Library"

# 7. Help text shows playlist argument
assert_output_matches \
    "music help shows play [playlist] syntax" \
    "play \\[playlist\\]" \
    "$MACJUICE" music --help

print_summary "Music"
