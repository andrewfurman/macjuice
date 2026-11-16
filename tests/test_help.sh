#!/bin/bash
# test_help.sh — Help quality tests for macjuice (no AppleScript, runs instantly, works on Linux)
#
# Walks every registered command and fails if:
#   - its help has no Examples section
#   - an <argument> or --flag in its Usage line has no description
# Also checks top-level help, -h/--help parity, error messages and placeholder-only data.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

echo "=== Help Tests ==="

REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

_ok()   { echo -e "  ${_GREEN}PASS${_NC}  $1"; ((_PASS++)); }
_bad()  { echo -e "  ${_RED}FAIL${_NC}  $1"; [[ -n "$2" ]] && echo "        $2"; ((_FAIL++)); }
check() { # check <description> <true|false> [detail]
    if [[ "$2" == "true" ]]; then _ok "$1"; else _bad "$1" "$3"; fi
}

# Fake osascript: help must never reach it. Any call leaves a marker file.
FAKE_BIN="$(mktemp -d)"
MARKER="$FAKE_BIN/osascript-called"
cat >"$FAKE_BIN/osascript" <<EOS
#!/bin/bash
touch "$MARKER"
exit 1
EOS
chmod +x "$FAKE_BIN/osascript"
trap 'rm -rf "$FAKE_BIN"' EXIT
mj() { PATH="$FAKE_BIN:$PATH" "$MACJUICE" "$@"; }

# --- Top-level help ---------------------------------------------------------
top="$(mj --help)"
check "top-level help has Examples" "$([[ "$top" == *"Examples:"* ]] && echo true || echo false)"
check "top-level help has Usage" "$([[ "$top" == *"Usage: macjuice <app> <command>"* ]] && echo true || echo false)"
check "top-level help explains per-command help" "$([[ "$top" == *"<command> --help"* ]] && echo true || echo false)"
check "top-level help states safety rules" "$([[ "$top" == *"Safety:"* ]] && echo true || echo false)"
check "top-level help fits about one screen (<= 50 lines)" "$([[ $(echo "$top" | wc -l) -le 50 ]] && echo true || echo false)" "$(echo "$top" | wc -l) lines"
n_examples=$(echo "$top" | awk '/^Examples:/ {f=1; next} /^$/ {f=0} f' | wc -l)
check "top-level help has 4-8 examples" "$([[ $n_examples -ge 4 && $n_examples -le 8 ]] && echo true || echo false)" "$n_examples examples"
check "no-argument run prints the same help" "$([[ "$(mj)" == "$top" ]] && echo true || echo false)"
check "-h matches --help" "$([[ "$(mj -h)" == "$top" ]] && echo true || echo false)"
check "'help' matches --help" "$([[ "$(mj help)" == "$top" ]] && echo true || echo false)"
for app in mail messages facetime calendar reminders notes contacts music photos shortcuts home; do
    check "top-level help mentions app '$app'" "$([[ "$top" == *"  $app "* ]] && echo true || echo false)"
done

# --- Every app -----------------------------------------------------------------
apps="$(mj --list-commands | cut -d' ' -f1 | sort -u)"
for app in $apps; do
    a="$(mj "$app" --help)"
    check "$app: --help lists commands" "$([[ "$a" == *"Commands:"* && "$a" == *"Examples:"* ]] && echo true || echo false)"
    check "$app: -h, 'help' and no-arg are identical to --help" \
        "$([[ "$(mj "$app" -h)" == "$a" && "$(mj help "$app")" == "$a" && "$(mj "$app")" == "$a" ]] && echo true || echo false)"
done

# --- Every command -----------------------------------------------------------
total=0
while read -r app cmd; do
    [[ -z "$app" ]] && continue
    ((total++))
    out="$(mj "$app" "$cmd" --help 2>&1)"
    rc=$?
    label="$app $cmd"

    check "$label: --help exits 0" "$([[ $rc -eq 0 ]] && echo true || echo false)"
    check "$label: -h and 'help' give identical output" \
        "$([[ "$(mj "$app" "$cmd" -h 2>&1)" == "$out" && "$(mj help "$app" "$cmd" 2>&1)" == "$out" && "$(mj "$app" help "$cmd" 2>&1)" == "$out" ]] && echo true || echo false)"

    # First line: "macjuice <app> <cmd> - description"
    first="$(echo "$out" | head -1)"
    check "$label: has a one-line description" \
        "$([[ "$first" == "macjuice $app $cmd - "?* ]] && echo true || echo false)" "$first"

    # Examples section with at least one runnable-looking line for this app
    examples="$(echo "$out" | awk '/^Examples:/ {f=1; next} /^[A-Za-z]/ {f=0} f && /^  macjuice /')"
    check "$label: has an Examples section" \
        "$([[ "$out" == *$'\nExamples:\n'* && -n "$examples" ]] && echo true || echo false)"
    bad_examples="$(echo "$examples" | grep -v "^  macjuice $app " | grep -v "^$")"
    check "$label: examples are for this app" "$([[ -z "$bad_examples" ]] && echo true || echo false)" "$bad_examples"

    # Every <argument> and --flag in the Usage line needs a description line
    usage="$(echo "$out" | awk '/^Usage:/ {getline; print; exit}')"
    tokens="$(echo "$usage" | sed -E 's/(--[a-z-]+)[= ]<[^>]*>/\1/g' | grep -oE '<[^>]+>|--[a-z-]+' | sort -u)"
    undocumented=""
    while IFS= read -r tok; do
        [[ -z "$tok" ]] && continue
        desc="$(echo "$out" | awk -v t="$tok" '
            index($0, "  " t) == 1 {
                rest = substr($0, length(t) + 3)
                if (rest ~ /^([ =<][^ ]*)?$/ || rest ~ /^[= ]<[^>]*>$/) { want_next = 1; rest = "" }
                sub(/^ *[=<]?[^ ]*> +/, "", rest)
                if (rest != "" && !want_next) { print rest; exit }
                if (want_next) { getline nxt; gsub(/^ +/, "", nxt); print nxt; exit }
            }')"
        [[ -z "${desc// /}" ]] && undocumented="$undocumented $tok"
    done <<<"$tokens"
    check "$label: every argument/flag is documented" "$([[ -z "$undocumented" ]] && echo true || echo false)" "missing:$undocumented"

    # No stray private data: only placeholder domains and +1555555 phone numbers
    emails="$(echo "$out" | grep -oE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[a-z]+' | grep -viE '@(example|contoso|fabrikam)\.com$')"
    phones="$(echo "$out" | grep -oE '\+[0-9]{10,}' | grep -v '^+1555555')"
    check "$label: examples use placeholder data only" "$([[ -z "$emails$phones" ]] && echo true || echo false)" "$emails $phones"
done < <(mj --list-commands)
check "walked at least 70 commands" "$([[ $total -ge 70 ]] && echo true || echo false)" "$total"

# --- Registry covers every command the AppleScript files implement -----------
missing=""
for f in "$REPO_DIR"/scripts/*.applescript; do
    app="$(basename "$f" .applescript)"
    for c in $(grep -oE 'cmd is "[a-z-]+"' "$f" | sed -E 's/cmd is "(.*)"/\1/' | sort -u); do
        [[ "$c" == "setup-check" ]] && continue
        mj --list-commands | grep -qx "$app $c" && continue
        # aliases resolve to a registered command
        mj help "$app" "$c" >/dev/null 2>&1 && continue
        missing="$missing $app:$c"
    done
done
check "every AppleScript command has registered help" "$([[ -z "$missing" ]] && echo true || echo false)" "missing:$missing"

# --- Mistakes point to help ----------------------------------------------------
err="$(mj calendar create "Only a title" 2>&1 >/dev/null)"; rc=$?
check "missing argument exits non-zero" "$([[ $rc -ne 0 ]] && echo true || echo false)"
check "missing argument shows usage, example and --help" \
    "$([[ "$err" == *"Usage:"* && "$err" == *"Example: macjuice calendar create"* && "$err" == *"macjuice calendar create --help"* ]] && echo true || echo false)" "$err"

err="$(mj mail frobnicate 2>&1 >/dev/null)"; rc=$?
check "unknown command exits non-zero" "$([[ $rc -ne 0 ]] && echo true || echo false)"
check "unknown command lists commands and points to --help" \
    "$([[ "$err" == *"unknown command 'frobnicate'"* && "$err" == *"search"* && "$err" == *"macjuice mail --help"* ]] && echo true || echo false)" "$err"

err="$(mj fakefoobar list 2>&1 >/dev/null)"; rc=$?
check "unknown app exits non-zero" "$([[ $rc -ne 0 ]] && echo true || echo false)"
check "unknown app lists apps and points to --help" \
    "$([[ "$err" == *"unknown app 'fakefoobar'"* && "$err" == *"mail"* && "$err" == *"macjuice --help"* ]] && echo true || echo false)" "$err"

mj help mail nope >/dev/null 2>&1
check "'help <app> <unknown>' exits non-zero" "$([[ $? -ne 0 ]] && echo true || echo false)"

# --- Help never touches AppleScript --------------------------------------------
check "help paths never called osascript" "$([[ ! -e "$MARKER" ]] && echo true || echo false)"

print_summary "Help"
