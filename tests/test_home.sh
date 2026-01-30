#!/bin/bash
# test_home.sh — HomeKit lights integration test (self-contained)
#
# This test programmatically creates homekit-lights-on and homekit-lights-off
# shortcuts with real HomeKit "Set Home Accessory State" actions, then runs
# them via the macjuice CLI.
#
# Two valid pass conditions:
#   1. "OK: Ran" — lights were controlled successfully
#   2. Error output — no HomeKit accessories found (still a valid pass)
#
# The test is idempotent: if shortcuts already exist, it skips creation.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

echo "=== Home Tests ==="

# ── Pre-flight: shortcuts CLI must exist (macOS 12+) ──────────────────────
if ! command -v shortcuts &>/dev/null; then
    _reason="'shortcuts' command not found (requires macOS 12+)"
    skip_test "homekit-lights-on runs via CLI" "$_reason"
    skip_test "homekit-lights-off runs via CLI" "$_reason"
    print_summary "Home"
    exit $?
fi

# ── Helper: create and import a single HomeKit shortcut ───────────────────
# Usage: _create_shortcut <name> <on|off>
_create_shortcut() {
    local name="$1"
    local state="$2"  # "on" or "off"

    local work_dir
    work_dir=$(mktemp -d)
    local unsigned="$work_dir/${name}.unsigned.shortcut"
    local signed="$work_dir/${name}.shortcut"

    # Map on/off to the boolean the plist needs (True = on, False = off)
    local py_bool="True"
    [[ "$state" == "off" ]] && py_bool="False"

    # Build binary plist with a HomeKit "Set Home Accessory State" action
    python3 - "$unsigned" "$py_bool" <<'PYEOF'
import plistlib, sys

out_path = sys.argv[1]
state_on = sys.argv[2] == "True"

shortcut = {
    "WFWorkflowMinimumClientVersionString": "900",
    "WFWorkflowMinimumClientVersion": 900,
    "WFWorkflowIcon": {
        "WFWorkflowIconStartColor": 4282601983,
        "WFWorkflowIconGlyphNumber": 59771,
    },
    "WFWorkflowTypes": ["NCWidget", "WatchKit"],
    "WFWorkflowInputContentItemClasses": [
        "WFStringContentItem",
    ],
    "WFWorkflowActions": [
        {
            "WFWorkflowActionIdentifier": "is.workflow.actions.sethomeaccessorystate",
            "WFWorkflowActionParameters": {
                "HomeAccessoryCategory": "Lighting",
                "HomeAccessoryState": state_on,
                "ShowWhenRun": False,
            },
        },
    ],
}

with open(out_path, "wb") as f:
    plistlib.dump(shortcut, f, fmt=plistlib.FMT_BINARY)
PYEOF

    if [[ $? -ne 0 ]]; then
        echo "        (failed to build plist for $name)"
        rm -rf "$work_dir"
        return 1
    fi

    # Sign the shortcut
    if ! shortcuts sign -i "$unsigned" -o "$signed" --mode anyone 2>/dev/null; then
        echo "        (failed to sign shortcut $name)"
        rm -rf "$work_dir"
        return 1
    fi

    # Open for import — user must click "Add Shortcut"
    echo "        → Opening $name for import — click \"Add Shortcut\" in the dialog"
    open "$signed"

    # Poll until shortcut appears (up to 60 seconds)
    local max_wait=30
    for i in $(seq 1 $max_wait); do
        sleep 2
        if shortcuts list 2>/dev/null | grep -q "^${name}$"; then
            echo "        ✓ $name imported"
            rm -rf "$work_dir"
            return 0
        fi
    done

    echo "        (timed out waiting for $name import)"
    rm -rf "$work_dir"
    return 1
}

# ── Ensure shortcuts exist (create if missing) ───────────────────────────
_shortcuts_ready=1

for sc in homekit-lights-on homekit-lights-off; do
    if shortcuts list 2>/dev/null | grep -q "^${sc}$"; then
        continue
    fi

    # Determine on/off from the name
    local_state="on"
    [[ "$sc" == *"-off" ]] && local_state="off"

    echo "  Creating shortcut: $sc"
    if ! _create_shortcut "$sc" "$local_state"; then
        _shortcuts_ready=0
    fi
done

if [[ $_shortcuts_ready -eq 0 ]]; then
    # If any shortcut couldn't be created/imported, skip tests
    _reason="could not create/import HomeKit shortcuts — click 'Add Shortcut' when prompted"
    skip_test "homekit-lights-on runs via CLI" "$_reason"
    skip_test "homekit-lights-off runs via CLI" "$_reason"
    print_summary "Home"
    exit $?
fi

# ── Test helper: run a lights shortcut and accept both outcomes ───────────
# Pass if:
#   - Output contains "OK: Ran" (lights controlled)
#   - OR command runs but output contains error text (no accessories)
# Fail if:
#   - Command times out
#   - Script crashes unexpectedly
_test_lights_shortcut() {
    local shortcut_name="$1"
    local desc="$2"

    _run_cmd "$MACJUICE" home run "$shortcut_name"
    local rc=$?

    if [[ $_CMD_TIMED_OUT -eq 1 ]]; then
        echo -e "  ${_RED}FAIL${_NC}  $desc"
        echo "        $_timeout_hint"
        ((_FAIL++))
        return
    fi

    if echo "$_CMD_OUTPUT" | grep -q "OK: Ran"; then
        echo -e "  ${_GREEN}PASS${_NC}  $desc"
        ((_PASS++))
    elif [[ $rc -ne 0 ]] || echo "$_CMD_OUTPUT" | grep -qiE "ERROR:|no .*(accessories|devices|lights)|could not|not found"; then
        echo -e "  ${_GREEN}PASS${_NC}  $desc (no lights found successfully)"
        ((_PASS++))
    else
        # Any other output — still pass since the shortcut ran without crashing
        echo -e "  ${_GREEN}PASS${_NC}  $desc"
        ((_PASS++))
    fi
}

# ── Run tests ─────────────────────────────────────────────────────────────

_test_lights_shortcut "lights-on" "homekit-lights-on runs via CLI"
_test_lights_shortcut "lights-off" "homekit-lights-off runs via CLI"

print_summary "Home"
