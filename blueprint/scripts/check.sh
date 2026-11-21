#!/bin/sh
# Every check. Fails closed: any problem is reported and the exit status is 1.
#   check.sh           check the working tree
#   check.sh --staged  check exactly what the next commit will contain (blocking hooks)
#   check.sh --warn    after cherry-pick, rebase or a fast-forward merge, which git gives no
#                      blocking hook for: check what is now committed, skip the tests, and
#                      print a warning with how to undo instead of failing
# Without git, only the checks that do not need it run, and it says what it skipped.
set -u
export LC_ALL=C

mode=${1:-}
root=$(cd "$(dirname "$0")/../.." && pwd -P)
cd "$root" || exit 1
status=0
fail() { echo "check: $*" >&2; status=1; }
have_git=no
command -v git > /dev/null 2>&1 && have_git=yes

# This folder must be the top of its own work tree, not a folder inside another repository.
in_git=no
if [ "$have_git" = yes ] && [ "$(git rev-parse --show-toplevel 2> /dev/null)" = "$root" ]; then
  in_git=yes
fi

# What the checks read: the working tree, or a copy of what the index holds for the base,
# custom/, AGENTS.md and the skill copies. encrypted/ is never copied, so nothing is decrypted to disk.
base=$root
cached=
if [ "$in_git" = yes ] && { [ "$mode" = --staged ] || [ "$mode" = --warn ]; }; then
  base=$(mktemp -d)
  trap 'rm -rf "$base"' EXIT
  git ls-files -z -- AGENTS.md blueprint custom .agents/skills .claude/skills | git checkout-index -z --stdin --prefix="$base/"
  cached=--cached
fi

# Before a commit, the tests of the scripts run only if the commit touches the scripts, the
# hooks or .gitattributes, the only things that can break them; the guards below always run.
# A manual run, or a first commit, runs every test.
run_tests=yes
if [ "$mode" = --warn ]; then
  run_tests=no
elif [ "$mode" = --staged ] && [ "$in_git" = yes ] && git rev-parse -q --verify HEAD > /dev/null; then
  if git diff --cached --quiet HEAD -- blueprint/scripts blueprint/hooks custom/hooks .gitattributes; then
    run_tests=no
    echo "check: this commit does not touch the scripts or hooks; their tests were skipped" >&2
  fi
fi

# 1. The scripts still do what they promise. test-check.sh runs this script in throwaway
#    repositories and marks each run with a file it creates; only a run that points at that
#    file skips test-check.sh, so a stray HITO_IN_TEST in the environment skips nothing.
if [ "$run_tests" = yes ]; then
  sh "$base/blueprint/scripts/test-rules.sh" > /dev/null 2>&1 || fail "blueprint/scripts/test-rules.sh fails"
  sh "$base/blueprint/scripts/test-skills.sh" > /dev/null 2>&1 || fail "blueprint/scripts/test-skills.sh fails"
  for t in "$base"/custom/hooks/test-*.sh; do
    [ -e "$t" ] || continue
    sh "$t" > /dev/null 2>&1 || fail "${t#"$base"/} fails"
  done
  if [ -n "${HITO_IN_TEST:-}" ] && [ -f "$HITO_IN_TEST/.hito-test-run" ]; then
    echo "check: nested run inside test-check.sh; test-check.sh skipped" >&2
  elif [ "$have_git" = yes ]; then
    sh "$base/blueprint/scripts/test-check.sh" > /dev/null 2>&1 || fail "blueprint/scripts/test-check.sh fails"
  else
    echo "check: git is not installed; test-check.sh skipped" >&2
  fi
fi

# 2. AGENTS.md and the skill copies are current, and custom/ holds nothing the base would
#    silently ignore.
HITO_ROOT=$base sh "$base/blueprint/scripts/rules.sh" --check || status=1
HITO_ROOT=$base sh "$base/blueprint/scripts/skills.sh" --check || status=1

# 3. Every note carries type and created in its frontmatter, with a type its folder allows
#    (see Type in AGENTS.md). It reads what the commit will carry before a commit, and the
#    disk otherwise, with one grep for all notes so it stays fast with thousands of them.
#    In the commit, encrypted/ holds ciphertext, so only its README is read.
if [ "$in_git" = yes ]; then
  notes=$(git -c core.quotePath=false ls-files -- inbox goals projects knowledge sources journal encrypted/README.md)
  found=$(git -c core.quotePath=false grep $cached -n -I -E '^(---|type:|created:)' -- inbox goals projects knowledge sources journal encrypted/README.md 2> /dev/null)
else
  notes=$(find inbox goals projects knowledge sources journal -type f 2> /dev/null; [ -f encrypted/README.md ] && echo encrypted/README.md)
  found=$(printf '%s\n' "$notes" | while IFS= read -r f; do [ -f "$f" ] && grep -n -E '^(---|type:|created:)' "$f" /dev/null; done)
fi
bad=$({ printf '%s\n' "$notes" | sed 's/^/F /'; printf '%s\n' "$found" | sed 's/^/G /'; } | awk '
  function allowed(p) {
    if (p ~ /^(inbox|goals|projects|knowledge|sources|journal|encrypted)\/README\.md$/) return "index"
    if (p ~ /^inbox\//) return "inbox"
    if (p ~ /^goals\//) return "goal"
    if (p ~ /^projects\//) return "project area"
    if (p ~ /^knowledge\//) return "knowledge model"
    if (p ~ /^sources\//) return "source"
    if (p ~ /^journal\//) return "journal"
    return ""
  }
  function value(s) { sub(/^[a-z]+:[ \t]*/, "", s); sub(/[ \t]+$/, "", s); return s }
  /^F / { p = substr($0, 3); if (p ~ /\.md$/) file[++n] = p; next }
  /^G / {
    s = substr($0, 3); sub(/\r$/, "", s)
    if (!match(s, /:[0-9]+:/)) next
    p = substr(s, 1, RSTART - 1); ln = substr(s, RSTART + 1, RLENGTH - 2) + 0; t = substr(s, RSTART + RLENGTH)
    if (t == "---") { if (ln == 1) opened[p] = 1; else if (!(p in shut)) shut[p] = ln }
    else if (t ~ /^type:/ && !(p in tline)) { tline[p] = ln; tval[p] = value(t) }
    else if (t ~ /^created:/ && !(p in cline)) { cline[p] = ln; cval[p] = value(t) }
  }
  END {
    for (i = 1; i <= n; i++) {
      p = file[i]; want = allowed(p); why = ""
      if (!(p in opened)) why = "no frontmatter (the first line must be ---)"
      else if (!(p in shut)) why = "its frontmatter is never closed with ---"
      else {
        if (!(p in tline) || tline[p] > shut[p]) why = "no type"
        else if (index(" " want " ", " " tval[p] " ") == 0) why = "type \"" tval[p] "\" is not allowed here (allowed: " want ")"
        if (!(p in cline) || cline[p] > shut[p] || cval[p] !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/)
          why = why (why == "" ? "" : "; ") "no created date as YYYY-MM-DD"
      }
      if (why != "") print p ": " why
    }
  }')
[ -z "$bad" ] || fail "notes without a valid frontmatter (see Type in AGENTS.md):
$bad"

if [ "$in_git" = no ]; then
  echo "check: not the top of a git repository; the hooks, secrets and encryption are NOT checked, and encrypted/ is not encrypted" >&2
  exit $status
fi

# 4. The hooks are on and executable, both on disk (where git runs them from) and in the
#    commit; otherwise none of this runs.
[ "$(git config core.hooksPath)" = "blueprint/hooks" ] || fail "the hooks are off; run: git config core.hooksPath blueprint/hooks"
for h in pre-commit pre-merge-commit commit-msg post-commit post-merge post-rewrite; do
  [ -x "$root/blueprint/hooks/$h" ] || fail "blueprint/hooks/$h is missing or not executable on disk, so git would skip it"
  [ -x "$base/blueprint/hooks/$h" ] || fail "blueprint/hooks/$h is missing or not executable in the commit"
done

# 5. Scripts and hooks keep Unix line endings on every system (core.autocrlf would break them).
for f in $(git ls-files -- 'blueprint/scripts/*' 'blueprint/hooks/*' 'custom/hooks/*'); do
  [ "$(git check-attr $cached eol -- "$f" | sed 's/.*: eol: //')" = lf ] || fail "$f needs 'eol=lf' in .gitattributes (see blueprint/README.md)"
done

# 6. No secret file is tracked, wherever it is, in any letter case, whatever .gitignore says.
#    core.quotePath=false shows names such as salud-año.md as they are; names git still
#    quotes (control characters, quotes) are rejected, since they cannot be checked.
files=$(git -c core.quotePath=false ls-files)
secrets=$(printf '%s\n' "$files" | awk '{ n = tolower($0); sub(/.*\//, "", n) }
  n ~ /\.env$/ || n ~ /^\.env\./ || n ~ /\.key$/ || n ~ /\.pem$/')
[ -z "$secrets" ] || fail "secret files are tracked; remove them from the index:
$secrets"
odd=$(printf '%s\n' "$files" | grep '^"' || true)
[ -z "$odd" ] || fail "file names git cannot show plainly; rename them:
$odd"

# 7. Everything tracked in encrypted/ (any letter case), except its README, is set to be
#    encrypted by git-crypt and is stored encrypted: git-crypt blobs start with a NUL byte
#    and "GITCRYPT". This cannot tell real ciphertext from a forged header.
plain=$(printf '%s\n' "$files" | awk '{ n = tolower($0) } n ~ /^encrypted\// && $0 != "encrypted/README.md"' |
  while IFS= read -r f; do
    filter=$(git check-attr $cached filter -- "$f" | sed 's/.*: filter: //')
    magic=$(git cat-file blob ":$f" 2> /dev/null | dd bs=1 skip=1 count=8 2> /dev/null)
    [ "$filter" = git-crypt ] && [ "$magic" = GITCRYPT ] || echo "$f"
  done)
[ -z "$plain" ] || fail "not encrypted; check .gitattributes and git-crypt:
$plain"

# 8. After an operation git cannot block, the new commit's message must pass the owner's hook.
if [ "$mode" = --warn ] && [ -f custom/hooks/commit-msg ]; then
  m=$(mktemp)
  git log -1 --format=%B > "$m"
  sh custom/hooks/commit-msg "$m" || status=1
  rm -f "$m"
fi

if [ "$mode" = --warn ] && [ $status -ne 0 ]; then
  echo "" >&2
  echo "check: WARNING: the last operation left the repository failing the checks above." >&2
  echo "check: git gives no hook that can block it. Undo it with: git reset --hard ORIG_HEAD" >&2
  exit 0
fi
exit $status
