#!/bin/sh
# Proves skills.sh: replacing, adding and disabling skills, copying them where every agent
# looks, and every mistake it must catch, each for the right reason.
set -u

script="$(cd "$(dirname "$0")" && pwd)/skills.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
r="$tmp/r"
passed=0
failed=0

ok() { passed=$((passed + 1)); }
ko() { failed=$((failed + 1)); echo "FAIL: $1" >&2; }
skill() { # folder, name, description
  mkdir -p "$1"
  printf -- '---\nname: %s\ndescription: %s\n---\n\n# %s\n' "$2" "$3" "$2" > "$1/SKILL.md"
}
setup() {
  rm -rf "$r"
  mkdir -p "$r/blueprint/skills" "$r/custom/skills"
  skill "$r/blueprint/skills/alpha" alpha "Base alpha."
  skill "$r/blueprint/skills/beta" beta "Base beta."
}
run() { HITO_ROOT="$r" sh "$script" "$@" 2>&1 > /dev/null; }
pass() { d=$1; shift; if out=$(run "$@"); then ok; else ko "$d: $out"; fi; }
# reject DESCRIPTION EXPECTED-MESSAGE [ARGS]: must fail, and for that reason, not a crash.
reject() {
  d=$1; m=$2; shift 2
  if out=$(run "$@"); then ko "$d (passed)"
  elif printf '%s\n' "$out" | grep -qF "$m"; then ok
  else ko "$d (failed for another reason: $out)"; fi
}
in_both() { # description, relative path, expected text
  for t in .agents/skills .claude/skills; do
    if grep -qF "$3" "$r/$t/$2" 2> /dev/null; then ok; else ko "$1 ($t)"; fi
  done
}
absent() { # description, relative path
  for t in .agents/skills .claude/skills; do
    if [ -e "$r/$t/$2" ]; then ko "$1 ($t)"; else ok; fi
  done
}

setup; pass "builds from the base alone"
in_both "copies base skills where every agent looks" alpha/SKILL.md "Base alpha."

setup; skill "$r/custom/skills/alpha" alpha "Mine."; pass "builds with a replacement"
in_both "uses the replacement" alpha/SKILL.md "Mine."

setup; skill "$r/custom/skills/my-own" my-own "Own."; pass "builds with an own skill"
in_both "adds the own skill" my-own/SKILL.md "Own."

setup; echo 'skills/beta' > "$r/custom/disable"; pass "builds with a disabled skill"
absent "drops the disabled skill" beta
setup; printf '# Example, commented out:\n# skills/beta\n\n' > "$r/custom/disable"; pass "accepts comments and blank lines in custom/disable"
in_both "a commented line disables nothing" beta/SKILL.md "Base beta."

setup; mkdir -p "$r/blueprint/skills/alpha/scripts"; printf '#!/bin/sh\necho hi\n' > "$r/blueprint/skills/alpha/scripts/run me.sh"
chmod +x "$r/blueprint/skills/alpha/scripts/run me.sh"; touch "$r/blueprint/skills/alpha/.DS_Store"
pass "builds a skill with scripts"
if [ -x "$r/.claude/skills/alpha/scripts/run me.sh" ]; then ok; else ko "keeps the executable bit and spaces in names"; fi
absent "leaves .DS_Store out" alpha/.DS_Store

setup; mkdir -p "$r/.claude"; echo keep > "$r/.claude/settings.local.json"; run
if [ -f "$r/.claude/settings.local.json" ]; then ok; else ko "leaves the rest of .claude/ alone"; fi

setup; rm -rf "$r/blueprint/skills" "$r/custom/skills"; pass "builds with no skills at all"
absent "creates nothing when there are no skills" alpha

# mistakes
setup; skill "$r/custom/skills/alpah" alpah "Typo."; reject "rejects replacing a skill that does not exist (typo)" "replaces no base skill"
setup; skill "$r/blueprint/skills/Bad_Name" Bad_Name "x"; reject "rejects an invalid skill name" "lowercase letters"
setup; skill "$r/blueprint/skills/gamma" delta "x"; reject "rejects a name that differs from the folder" "must say 'name: gamma'"
setup; mkdir -p "$r/blueprint/skills/gamma"; printf -- '---\nname: gamma\n---\n' > "$r/blueprint/skills/gamma/SKILL.md"; reject "rejects a skill without description" "needs a 'description'"
setup; mkdir -p "$r/blueprint/skills/gamma"; reject "rejects a skill without SKILL.md" "has no SKILL.md"
setup; echo x > "$r/custom/skills/notes.txt"; reject "rejects a stray file in custom/skills" "is not a skill folder"
setup; skill "$r/custom/skills/.hidden" .hidden "x"; reject "rejects a hidden skill folder" "lowercase letters"
setup; echo 'skills/gamma' > "$r/custom/disable"; reject "rejects disabling a skill that does not exist" "no base skill named"
setup; skill "$r/custom/skills/beta" beta "Mine."; echo 'skills/beta' > "$r/custom/disable"; reject "rejects replacing and disabling the same skill" "both replaced and disabled"
setup; printf 'rules/x\r\nskills/beta\r\n' > "$r/custom/disable"; pass "reads skills lines among rules lines, with Windows line endings"
absent "drops the skill named on that line" beta

# skills for every folder: checked here, copied by global.sh, never into the repository
setup; skill "$r/custom/global/skills/my-any" my-any "Anywhere."; pass "accepts a skill for every folder"
absent "does not copy a skill for every folder into the repository" my-any
pass "check passes with a skill for every folder" --check
setup; skill "$r/custom/global/skills/notes" notes "x"; reject "rejects a skill for every folder not named my-*" "are your own, named my-*"
setup; skill "$r/custom/global/skills/my-bad" my-other "x"; reject "rejects a skill for every folder whose name differs from its folder" "must say 'name: my-bad'"
setup; mkdir -p "$r/custom/global/skills/my-empty"; reject "rejects a skill for every folder without SKILL.md" "has no SKILL.md"
setup; mkdir -p "$r/custom/global/skills"; echo x > "$r/custom/global/skills/notes.txt"; reject "rejects a stray file in custom/global/skills" "is not a skill folder"
setup; skill "$r/custom/global/skills/my-own" my-own "x"; skill "$r/custom/skills/my-own" my-own "y"; reject "rejects the same skill in custom/skills and custom/global/skills" "both in custom/skills and custom/global/skills"

# --check
setup; run; pass "check passes when the copies are current" --check
echo edited >> "$r/.claude/skills/alpha/SKILL.md"; reject "check catches a hand edit in one copy" "out of date or was edited" --check
setup; run; skill "$r/.agents/skills/zeta" zeta "x"; reject "check catches a skill added by hand to a copy" "out of date or was edited" --check
setup; run; chmod +x "$r/.agents/skills/alpha/SKILL.md"; reject "check catches a changed executable bit" "out of date or was edited" --check
setup; run; skill "$r/blueprint/skills/alpha" alpha "Changed."; reject "check catches stale copies" "out of date or was edited" --check
setup; reject "check fails when the copies are missing" "is missing" --check
setup; rm -rf "$r/blueprint/skills" "$r/custom/skills"; mkdir -p "$r/.agents/skills/old"; reject "check catches copies of skills that no longer exist" "come from nowhere" --check

echo "skills.sh: $passed passed, $failed failed"
[ "$failed" -eq 0 ]
