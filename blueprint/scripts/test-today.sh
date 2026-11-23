#!/bin/sh
# Proves today.sh: it creates the day's note where the Folders rule puts it, with a frontmatter
# the check accepts, never overwrites one that exists, and rejects what is not a date.
set -u
export LC_ALL=C

src=$(cd "$(dirname "$0")" && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
tmp=$(cd "$tmp" && pwd -P)
r="$tmp/r"
passed=0
failed=0

ok() { passed=$((passed + 1)); }
ko() { failed=$((failed + 1)); echo "FAIL: $1" >&2; }
setup() {
  rm -rf "$r"; mkdir -p "$r/blueprint/scripts" "$r/blueprint/templates"
  cp "$src/today.sh" "$r/blueprint/scripts/"; cp "$src/../templates/journal.md" "$r/blueprint/templates/"
}
run() { HITO_TODAY=$1 sh "$r/blueprint/scripts/today.sh" "${2:-}" > "$tmp/out" 2>&1; }

setup
if run 2026-11-22; then ok; else ko "creates the note: $(cat "$tmp/out")"; fi
f="$r/journal/2026/2026-11-22.md"
if [ "$(cat "$f" 2> /dev/null)" = "$(printf -- '---\ntype: journal\ncreated: 2026-11-22\n---')" ]; then ok
else ko "writes the frontmatter, and nothing else: $(cat "$f" 2> /dev/null)"; fi
if [ "$(cat "$tmp/out")" = "$f" ]; then ok; else ko "prints the path: $(cat "$tmp/out")"; fi
echo 'mine' >> "$f"; run 2026-11-22
if tail -n 1 "$f" | grep -qx mine; then ok; else ko "never overwrites a note that exists"; fi
if [ "$(cat "$tmp/out")" = "$f" ]; then ok; else ko "prints the path of the note that exists"; fi
run 2027-01-01
if [ -f "$r/journal/2027/2027-01-01.md" ]; then ok; else ko "starts the folder of a new year"; fi
if run 22-11-2026; then ko "rejects a day that is not YYYY-MM-DD"; else ok; fi
if [ -e "$r/journal/22-11-2026.md" ] || [ -d "$r/journal/22" ]; then ko "writes nothing for a bad day"; else ok; fi
if run 2026-11-22 --everything; then ko "rejects an unknown option"; else ok; fi

# The owner's template replaces the base one; the date goes wherever the placeholder is.
setup; mkdir -p "$r/custom/templates"
printf -- '---\r\ntype: journal\r\ncreated: {{date:YYYY-MM-DD}}\r\n---\r\n\r\n## {{date:YYYY-MM-DD}}: gratitude, {{date:YYYY-MM-DD}}\r\n' > "$r/custom/templates/journal.md"
run 2026-11-22
if [ "$(cat "$f" 2> /dev/null)" = "$(printf -- '---\ntype: journal\ncreated: 2026-11-22\n---\n\n## 2026-11-22: gratitude, 2026-11-22')" ]; then ok
else ko "uses the owner's template, every placeholder filled and without Windows line endings: $(cat "$f" 2> /dev/null)"; fi
setup; rm "$r/blueprint/templates/journal.md"
if run 2026-11-22; then ko "fails without a template"; else ok; fi
if [ -e "$f" ]; then ko "writes nothing without a template"; else ok; fi

setup; run 2026-11-22
# The check accepts what it writes: the frontmatter carries the type its folder allows.
if grep -qx 'type: journal' "$f" && grep -qx 'created: 2026-11-22' "$f"; then ok; else ko "the type and date the check asks for"; fi

echo "test-today: $passed passed, $failed failed"
[ "$failed" -eq 0 ]
