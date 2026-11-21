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

echo "rules.sh: $passed passed, $failed failed"
[ "$failed" -eq 0 ]
