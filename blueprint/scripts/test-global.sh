#!/bin/sh
# Proves global.sh in a throwaway home: each agent gets the rules and skills for every folder
# the way it can read them, running again changes nothing, and nothing of the owner's or of
# another repository is changed without asking.
set -u
export LC_ALL=C

src=$(cd "$(dirname "$0")" && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
tmp=$(cd "$tmp" && pwd -P)
r="$tmp/r"
h="$tmp/home"
passed=0
failed=0
unset CLAUDE_CONFIG_DIR CODEX_HOME XDG_CONFIG_HOME

ok() { passed=$((passed + 1)); }
ko() { failed=$((failed + 1)); echo "FAIL: $1" >&2; }
setup() { # a repository with rules for every folder, and a home where every agent is installed
  rm -rf "$r" "$h"
  mkdir -p "$r/blueprint/scripts" "$h/.claude" "$h/.gemini" "$h/.codex" "$h/.config/opencode"
  cp "$src/global.sh" "$r/blueprint/scripts/"
  printf '# Rules for every folder\n\n## Mine\n' > "$r/GLOBAL.md"
}
skill() { mkdir -p "$r/custom/global/skills/$1"; printf -- '---\nname: %s\ndescription: %s\n---\n' "$1" "$2" > "$r/custom/global/skills/$1/SKILL.md"; }
run() { HOME="$h" sh "$r/blueprint/scripts/global.sh" "$@" < /dev/null > "$tmp/out" 2>&1; }
pass() { d=$1; shift; if run "$@"; then ok; else ko "$d: $(cat "$tmp/out")"; fi; }
said() { if grep -qF "$2" "$tmp/out"; then ok; else ko "$1: $(cat "$tmp/out")"; fi; }
quiet() { if [ -s "$tmp/out" ]; then ko "$1: $(cat "$tmp/out")"; else ok; fi; }
is() { if [ "$(cat "$2" 2> /dev/null)" = "$3" ]; then ok; else ko "$1: $(cat "$2" 2> /dev/null)"; fi; }
gone() { if [ -e "$2" ]; then ko "$1"; else ok; fi; }
snapshot() { (cd "$h" && find . -type f | sort | while IFS= read -r f; do cksum "$f"; done); }
line="@$r/GLOBAL.md"
copy="<!-- Copied by hito from $r/GLOBAL.md; do not edit by hand. -->

# Rules for every folder

## Mine"

setup; pass "takes the rules to every agent"
is "Claude Code imports GLOBAL.md" "$h/.claude/CLAUDE.md" "$line"
is "Gemini CLI imports GLOBAL.md" "$h/.gemini/GEMINI.md" "$line"
is "Codex gets a copy that names its source" "$h/.codex/AGENTS.md" "$copy"
is "OpenCode gets a copy that names its source" "$h/.config/opencode/AGENTS.md" "$copy"
before=$(snapshot); pass "runs again"
if [ "$(snapshot)" = "$before" ]; then ok; else ko "running again changes nothing"; fi
quiet "running again says nothing"
echo '## More' >> "$r/GLOBAL.md"; pass "runs after a change"
if grep -qxF '## More' "$h/.codex/AGENTS.md" && grep -qxF '## More' "$h/.config/opencode/AGENTS.md"; then ok; else ko "updates the copies"; fi
is "leaves the import line as it was" "$h/.claude/CLAUDE.md" "$line"

setup; rm -rf "$h"; mkdir -p "$h"; pass "runs with no agent installed"
if [ -z "$(ls -A "$h")" ]; then ok; else ko "creates nothing for agents that are not installed"; fi
setup; rm -rf "$h/.codex" "$h/.config" "$h/.gemini"; pass "runs with only Claude Code"
gone "creates no folder for Codex or OpenCode" "$h/.agents"
gone "creates no file for Gemini CLI" "$h/.gemini"

# A file of the owner's: the line only with a yes; the rest is reported, never changed.
setup; printf '# Mine\nkeep' > "$h/.claude/CLAUDE.md"; pass "meets a CLAUDE.md of the owner's"
is "does not change it without asking" "$h/.claude/CLAUDE.md" "# Mine
keep"
said "says which line to add" "add this line at the end of $h/.claude/CLAUDE.md: $line"
pass "meets it again without asking" --no-ask
is "--no-ask never changes it" "$h/.claude/CLAUDE.md" "# Mine
keep"
pass "adds the line when told yes" --yes
is "adds the line at the end, after what was there" "$h/.claude/CLAUDE.md" "# Mine
keep

$line"
pass "runs again after the yes"
quiet "asks nothing once the line is there"
printf '# Mine\n' > "$h/.codex/AGENTS.md"; pass "meets an AGENTS.md of the owner's"
is "never changes the owner's AGENTS.md" "$h/.codex/AGENTS.md" "# Mine"
said "says Codex does not get the rules" "Codex does not get your rules"

# Moving the repository: what came from the old place is repaired; another live one is left.
setup; old="$tmp/old"; printf '# Mine\n\n@%s/GLOBAL.md\n' "$old" > "$h/.claude/CLAUDE.md"
printf '<!-- Copied by hito from %s/GLOBAL.md; do not edit by hand. -->\n\nold\n' "$old" > "$h/.codex/AGENTS.md"
pass "runs after the repository moved"
is "replaces the line that pointed to the old place, without asking" "$h/.claude/CLAUDE.md" "# Mine

$line"
is "replaces the copy from the old place" "$h/.codex/AGENTS.md" "$copy"
setup; mkdir -p "$old"; touch "$old/GLOBAL.md"; printf '@%s/GLOBAL.md\n' "$old" > "$h/.claude/CLAUDE.md"
printf '<!-- Copied by hito from %s/GLOBAL.md; do not edit by hand. -->\n\nother\n' "$old" > "$h/.codex/AGENTS.md"
pass "meets another repository that still exists"
is "leaves its line" "$h/.claude/CLAUDE.md" "@$old/GLOBAL.md"
is "leaves its copy" "$h/.codex/AGENTS.md" "<!-- Copied by hito from $old/GLOBAL.md; do not edit by hand. -->

other"
said "says the line points elsewhere" "already loads another GLOBAL.md"
rm -rf "$old"

# No rules for every folder left: what it put there goes, the owner's stays.
setup; printf '# Mine\n' > "$h/.gemini/GEMINI.md"; run --yes; printf '# Mine\n' > "$h/.codex/AGENTS.md"
rm "$r/GLOBAL.md"; pass "runs once there are no rules for every folder"
gone "removes the CLAUDE.md that held only its line" "$h/.claude/CLAUDE.md"
is "removes its line from the owner's GEMINI.md and keeps the rest" "$h/.gemini/GEMINI.md" "# Mine"
gone "removes its copy for OpenCode" "$h/.config/opencode/AGENTS.md"
is "keeps the owner's AGENTS.md" "$h/.codex/AGENTS.md" "# Mine"
pass "runs again without rules"
quiet "says nothing when there is nothing to remove"

# Skills: a marked copy where each agent looks; others' folders are never touched.
setup; skill my-any "Anywhere."; mkdir -p "$r/custom/global/skills/my-any/scripts"
printf '#!/bin/sh\n' > "$r/custom/global/skills/my-any/scripts/go.sh"; chmod +x "$r/custom/global/skills/my-any/scripts/go.sh"
mkdir -p "$h/.claude/skills/Research"; echo theirs > "$h/.claude/skills/Research/SKILL.md"
pass "takes a skill to every agent"
for t in .claude/skills .agents/skills; do
  if grep -qF 'Anywhere.' "$h/$t/my-any/SKILL.md" 2> /dev/null; then ok; else ko "copies the skill to $t"; fi
  if [ -x "$h/$t/my-any/scripts/go.sh" ]; then ok; else ko "keeps the executable bit in $t"; fi
  is "marks the copy in $t with its source" "$h/$t/my-any/.hito-copy" "Copied by hito from $r/custom/global/skills/my-any; do not edit by hand."
done
is "leaves other skills alone" "$h/.claude/skills/Research/SKILL.md" theirs
before=$(snapshot); pass "runs again with a skill"
if [ "$(snapshot)" = "$before" ]; then ok; else ko "running again copies nothing"; fi
quiet "running again with a skill says nothing"
skill my-any "Changed."; pass "runs after a skill changes"
if grep -qF 'Changed.' "$h/.agents/skills/my-any/SKILL.md"; then ok; else ko "updates the copy"; fi
rm -r "$r/custom/global/skills/my-any"; pass "runs after a skill is removed"
gone "removes its copy" "$h/.claude/skills/my-any"
is "still leaves other skills alone" "$h/.claude/skills/Research/SKILL.md" theirs
setup; skill my-any "Mine."; mkdir -p "$h/.claude/skills/my-any"; echo own > "$h/.claude/skills/my-any/SKILL.md"
pass "meets a skill folder of the owner's with the same name"
is "does not change it" "$h/.claude/skills/my-any/SKILL.md" own
said "says the skill does not reach it" "your skill my-any does not reach it"

# Where each agent says its folder is.
setup; rm -rf "$h/.codex"; mkdir -p "$tmp/codexhome"
if CODEX_HOME="$tmp/codexhome" run; then ok; else ko "runs with CODEX_HOME"; fi
is "copies to the folder CODEX_HOME names" "$tmp/codexhome/AGENTS.md" "$copy"
rm -rf "$tmp/codexhome"

setup; if run --everything; then ko "rejects an unknown option"; else ok; fi

echo "test-global: $passed passed, $failed failed"
[ "$failed" -eq 0 ]
