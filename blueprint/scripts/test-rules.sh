#!/bin/sh
# Proves rules.sh: replacing, adding and disabling rules, and every mistake it must catch.
set -u

script="$(cd "$(dirname "$0")" && pwd)/rules.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
r="$tmp/r"
passed=0
failed=0

ok() { passed=$((passed + 1)); }
ko() { failed=$((failed + 1)); echo "FAIL: $1" >&2; }
setup() {
  rm -rf "$r"
  mkdir -p "$r/blueprint/rules" "$r/custom/rules"
  printf 'alpha\nbeta\n' > "$r/blueprint/rules/ORDER"
  echo '## alpha base' > "$r/blueprint/rules/alpha.md"
  echo '## beta base' > "$r/blueprint/rules/beta.md"
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
has() { if grep -qxF "$2" "$r/AGENTS.md"; then ok; else ko "$1"; fi; }
lacks() { if grep -qxF "$2" "$r/AGENTS.md"; then ko "$1"; else ok; fi; }
headings() { grep '^## ' "$r/AGENTS.md" | tr '\n' '|'; }

setup; pass "builds from the base alone"
if [ "$(headings)" = "## alpha base|## beta base|" ]; then ok; else ko "keeps the ORDER"; fi

setup; echo '## alpha mine' > "$r/custom/rules/alpha.md"; pass "builds with a replacement"
has "uses the replacement" "## alpha mine"
lacks "drops the replaced base rule" "## alpha base"

setup; echo '## my rule' > "$r/custom/rules/my-rule.md"; pass "builds with an own rule"
if [ "$(headings)" = "## alpha base|## beta base|## my rule|" ]; then ok; else ko "puts own rules last"; fi

setup; echo 'rules/beta' > "$r/custom/disable"; pass "builds with a disabled rule"
lacks "drops the disabled rule" "## beta base"
setup; printf '# Example, commented out:\n# rules/beta\n\n' > "$r/custom/disable"; pass "accepts comments and blank lines in custom/disable"
has "a commented line disables nothing" "## beta base"

setup; echo x > "$r/custom/rules/alpah.md"; reject "rejects replacing a rule that does not exist (typo)" "replaces no base rule"
setup; echo 'rules/gamma' > "$r/custom/disable"; reject "rejects disabling a rule that does not exist" "there is no base rule named"
setup; echo 'beta' > "$r/custom/disable"; reject "rejects a disable line without rules/" "must look like rules/"
setup; echo x > "$r/custom/rules/beta.md"; echo 'rules/beta' > "$r/custom/disable"; reject "rejects replacing and disabling the same rule" "both replaced and disabled"
setup; echo x > "$r/blueprint/rules/gamma.md"; reject "rejects a base rule missing from ORDER" "is not listed in ORDER"
setup; echo gamma >> "$r/blueprint/rules/ORDER"; reject "rejects an ORDER entry without a file" "does not exist"
setup; echo alpha >> "$r/blueprint/rules/ORDER"; reject "rejects a rule listed twice in ORDER" "more than once"
setup; printf 'rules/beta\r\n' > "$r/custom/disable"; pass "reads a disable file with Windows line endings"
lacks "drops the rule named on that line" "## beta base"
setup; echo x > "$r/custom/rules/my-x.MD"; reject "rejects a rule with an uppercase extension" "not something the base reads"
setup; echo x > "$r/custom/rules/links.markdown"; reject "rejects a rule with another extension" "not something the base reads"
setup; mkdir -p "$r/custom/rules/sub"; reject "rejects a folder inside custom/rules" "not something the base reads"
setup; echo x > "$r/custom/rules/.links.md"; reject "rejects a hidden rule file" "not something the base reads"
setup; echo 'rules/beta' > "$r/custom/disabled"; reject "rejects a misspelled custom/disable" "not something the base reads"
setup; echo x > "$r/custom/git-hooks-extra"; reject "rejects an unknown entry in custom/" "not something the base reads"
setup; mkdir -p "$r/custom/git-hooks"; echo x > "$r/custom/git-hooks/pre-commit"; reject "rejects a custom hook the base does not run" "not something the base reads"
setup; echo x > "$r/blueprint/rules/notes.txt"; reject "rejects a stray file in blueprint/rules" "not something the base reads"
setup; touch "$r/custom/rules/.DS_Store" "$r/custom/.DS_Store"; mkdir -p "$r/custom/git-hooks"; echo x > "$r/custom/git-hooks/commit-msg"; echo x > "$r/custom/git-hooks/test-msg.sh"; pass "accepts what the base reads, and Finder's .DS_Store"
setup; printf '## alpha mine\r\n' > "$r/custom/rules/alpha.md"; pass "builds from a rule with Windows line endings"
has "drops the carriage returns" "## alpha mine"
run; sed 's/$/\r/' "$r/AGENTS.md" > "$r/x"; mv "$r/x" "$r/AGENTS.md"; pass "check ignores Windows line endings in AGENTS.md" --check
setup; echo '## my Zeta' > "$r/custom/rules/my-Zeta.md"; echo '## my alpha' > "$r/custom/rules/my-alpha.md"
LC_ALL=en_US.UTF-8 run; if LC_ALL=C run --check; then ok; else ko "orders own rules the same in every locale"; fi

setup; run; pass "check passes when AGENTS.md is current" --check
echo edited >> "$r/AGENTS.md"; reject "check catches a hand edit" "out of date or was edited" --check
setup; run; echo '## beta new' > "$r/blueprint/rules/beta.md"; reject "check catches a stale AGENTS.md" "out of date or was edited" --check
setup; reject "check fails when AGENTS.md is missing" "AGENTS.md is missing" --check

# Rules for every folder: GLOBAL.md, only while there are some, and the end of AGENTS.md.
gl() { mkdir -p "$r/custom/global/rules"; echo "$2" > "$r/custom/global/rules/$1"; }
setup; pass "builds without rules for every folder"
if [ -e "$r/GLOBAL.md" ]; then ko "writes no GLOBAL.md without rules for every folder"; else ok; fi
setup; gl my-b.md '## global b'; gl my-a.md '## global a'; pass "builds with rules for every folder"
if [ "$(grep '^## ' "$r/GLOBAL.md" | tr '\n' '|')" = "## global a|## global b|" ]; then ok; else ko "GLOBAL.md holds them in name order"; fi
if grep -qF 'from `custom/global/rules/`. Do not edit by hand.' "$r/GLOBAL.md"; then ok; else ko "GLOBAL.md says it is generated"; fi
echo '## mine' > "$r/custom/rules/my-z.md"; run
if [ "$(headings)" = "## alpha base|## beta base|## mine|## global a|## global b|" ]; then ok; else ko "puts them at the end of AGENTS.md too, after the owner's rules: $(headings)"; fi
pass "check passes when GLOBAL.md is current" --check
echo edited >> "$r/GLOBAL.md"; reject "check catches a hand edit of GLOBAL.md" "GLOBAL.md is out of date or was edited" --check
run; gl my-a.md '## global a changed'; reject "check catches a stale AGENTS.md after a rule for every folder changes" "AGENTS.md is out of date" --check
run; cp "$r/GLOBAL.md" "$tmp/g"; gl my-a.md '## global a again'; run; cp "$tmp/g" "$r/GLOBAL.md"; reject "check catches a stale GLOBAL.md" "GLOBAL.md is out of date or was edited" --check
rm "$r/GLOBAL.md"; reject "check fails when GLOBAL.md is missing" "GLOBAL.md is missing" --check
run; cp "$r/GLOBAL.md" "$tmp/g"; rm -r "$r/custom/global/rules"; run; cp "$tmp/g" "$r/GLOBAL.md"; reject "check catches a GLOBAL.md left over" "GLOBAL.md comes from no rule" --check
pass "removes GLOBAL.md once no rule is left"
if [ -e "$r/GLOBAL.md" ]; then ko "GLOBAL.md is gone"; else ok; fi
setup; gl links.md x; reject "rejects a rule for every folder not named my-*" "are your own, named my-*.md"
setup; gl my-x.txt x; reject "rejects a stray file in custom/global/rules" "not something the base reads"
setup; mkdir -p "$r/custom/global/rules/my-sub.md"; reject "rejects a folder named like a rule in custom/global/rules" "not something the base reads"
setup; mkdir -p "$r/custom/global/hooks"; reject "rejects an unknown entry in custom/global" "not something the base reads"
setup; gl my-x.md x; echo y > "$r/custom/rules/my-x.md"; reject "rejects the same rule in custom/rules and custom/global/rules" "both in custom/rules and custom/global/rules"
setup; gl my-x.md x; echo 'config: {}' > "$r/custom/rules/.markdownlint-cli2.yaml"; cp "$r/custom/rules/.markdownlint-cli2.yaml" "$r/custom/global/rules/"; pass "takes the same linter settings in both folders for no clash"
setup; gl my-x.md x; mkdir -p "$r/custom/global/skills"; touch "$r/custom/global/.DS_Store" "$r/custom/global/rules/.DS_Store"; pass "accepts what custom/global holds, and .DS_Store"
setup; printf '## global crlf\r\n' > "$r/x"; mkdir -p "$r/custom/global/rules"; mv "$r/x" "$r/custom/global/rules/my-c.md"; pass "builds from a rule for every folder with Windows line endings"
if grep -qxF '## global crlf' "$r/GLOBAL.md"; then ok; else ko "drops the carriage returns in GLOBAL.md"; fi
has "drops them in AGENTS.md too" '## global crlf'

# Templates: the owner's replace the base ones with their name; nothing else goes there.
setup; mkdir -p "$r/blueprint/templates" "$r/custom/templates"; echo base > "$r/blueprint/templates/journal.md"
echo mine > "$r/custom/templates/journal.md"; touch "$r/custom/templates/.DS_Store"; pass "accepts a template that replaces a base one"
echo x > "$r/custom/templates/weekly.md"; reject "rejects a template that replaces none" "custom/templates/weekly.md replaces no base template"
rm "$r/custom/templates/weekly.md"; mkdir "$r/custom/templates/journal"; reject "rejects a folder in custom/templates" "replaces no base template"

echo "rules.sh: $passed passed, $failed failed"
[ "$failed" -eq 0 ]
