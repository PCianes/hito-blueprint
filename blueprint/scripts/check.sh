#!/bin/sh
# Every check. Fails closed: any problem is reported and the exit status is 1.
#   check.sh           check the working tree
#   check.sh --staged  check exactly what the next commit will contain (blocking git hooks)
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
# On disk, notes not yet added to git are read too (ignored files are not), so a manual run
# sees what the next git add would bring. Before a commit, only what it carries counts.
untracked=
others=
if [ "$in_git" = yes ] && [ -z "$cached" ]; then untracked=--untracked; others="--others --exclude-standard"; fi

# Before a commit, the tests of the scripts run only if the commit touches the scripts, the
# git hooks or .gitattributes, the only things that can break them; the guards below always run.
# A manual run, or a first commit, runs every test.
run_tests=yes
if [ "$mode" = --warn ]; then
  run_tests=no
elif [ "$mode" = --staged ] && [ "$in_git" = yes ] && git rev-parse -q --verify HEAD > /dev/null; then
  if git diff --cached --quiet HEAD -- blueprint/scripts blueprint/git-hooks custom/git-hooks .gitattributes; then
    run_tests=no
    echo "check: this commit does not touch the scripts or git hooks; their tests were skipped" >&2
  fi
fi

# 1. The scripts still do what they promise. test-check.sh runs this script in throwaway
#    repositories and marks each run with a file it creates; only a run that points at that
#    file skips test-check.sh, so a stray HITO_IN_TEST in the environment skips nothing.
if [ "$run_tests" = yes ]; then
  sh "$base/blueprint/scripts/test-rules.sh" > /dev/null 2>&1 || fail "blueprint/scripts/test-rules.sh fails"
  sh "$base/blueprint/scripts/test-skills.sh" > /dev/null 2>&1 || fail "blueprint/scripts/test-skills.sh fails"
  for t in "$base"/custom/git-hooks/test-*.sh; do
    [ -e "$t" ] || continue
    sh "$t" > /dev/null 2>&1 || fail "${t#"$base"/} fails"
  done
  if [ -n "${HITO_IN_TEST:-}" ] && [ -f "$HITO_IN_TEST/.hito-test-run" ]; then
    echo "check: nested run inside test-check.sh; test-check.sh and test-install.sh skipped" >&2
  elif [ "$have_git" = yes ]; then
    sh "$base/blueprint/scripts/test-check.sh" > /dev/null 2>&1 || fail "blueprint/scripts/test-check.sh fails"
    sh "$base/blueprint/scripts/test-install.sh" > /dev/null 2>&1 || fail "blueprint/scripts/test-install.sh fails"
  else
    echo "check: git is not installed; test-check.sh and test-install.sh skipped" >&2
  fi
fi

# 2. AGENTS.md and the skill copies are current, and custom/ holds nothing the base would
#    silently ignore.
HITO_ROOT=$base sh "$base/blueprint/scripts/rules.sh" --check || status=1
HITO_ROOT=$base sh "$base/blueprint/scripts/skills.sh" --check || status=1

# 3. Every note carries type and created in its frontmatter, with a type its folder allows
#    (see Type in AGENTS.md). It reads what the commit will carry before a commit, and the
#    disk otherwise, with one grep for all notes so it stays fast with thousands of them.
#    In the commit, encrypted/ holds ciphertext, so only its README is read. A note in
#    archive/ keeps the type it had at its old path, archive/ stripped.
if [ "$in_git" = yes ]; then
  notes=$(git -c core.quotePath=false ls-files --cached $others -- inbox goals projects knowledge sources journal archive encrypted/README.md)
  found=$(git -c core.quotePath=false grep $cached $untracked -n -I -E '^(---|type:|created:)' -- inbox goals projects knowledge sources journal archive encrypted/README.md 2> /dev/null)
else
  notes=$(find inbox goals projects knowledge sources journal archive -type f 2> /dev/null; [ -f encrypted/README.md ] && echo encrypted/README.md)
  found=$(printf '%s\n' "$notes" | while IFS= read -r f; do [ -f "$f" ] && grep -n -E '^(---|type:|created:)' "$f" /dev/null; done)
fi
bad=$({ printf '%s\n' "$notes" | sed 's/^/F /'; printf '%s\n' "$found" | sed 's/^/G /'; } | awk '
  function allowed(p) {
    if (p == "archive/README.md") return "index"
    sub(/^archive\//, "", p)
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
  /^F / { p = substr($0, 3); if (p ~ /\.md$/ && tolower(p) !~ /^archive\/encrypted\//) file[++n] = p; next }
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

# 4. Every relative link points to something that exists: in what the commit will carry
#    before a commit, and on disk otherwise, so moving a note (to archive/, say) or renaming
#    one never leaves a dead link unnoticed. Links to the web or to an anchor in the same
#    note, and links inside code, are skipped. Rules are read in AGENTS.md, where their links
#    end up, and skill copies in their originals; in the commit, encrypted/ is ciphertext.
tab=$(printf '\t')
pattern='^[[:space:]]*(```|~~~)|\]\('
existing=
if [ "$in_git" = yes ]; then
  skip="':(exclude).agents' ':(exclude).claude' ':(exclude)blueprint/rules' ':(exclude)custom/rules' ':(exclude)encrypted'"
  found=$({ eval "git -c core.quotePath=false grep $cached $untracked -n -I -E \"\$pattern\" -- '*.md' $skip"
    git -c core.quotePath=false grep $cached $untracked -n -I -E "$pattern" -- encrypted/README.md; } 2> /dev/null)
  [ -n "$cached" ] && existing=$(git -c core.quotePath=false ls-files)
else
  found=$(find . -type f -name '*.md' ! -path './.git/*' ! -path './.agents/*' ! -path './.claude/*' \
    ! -path './blueprint/rules/*' ! -path './custom/rules/*' \( ! -path './encrypted/*' -o -path ./encrypted/README.md \) \
    -exec grep -n -E "$pattern" /dev/null {} + 2> /dev/null | sed 's|^\./||')
fi
links=$({ [ -n "$cached" ] && printf '%s\n' "$existing" | sed 's/^/E /'; printf '%s\n' "$found" | sed 's/^/G /'; } | awk -v staged="$cached" '
  function resolve(dir, t,   n, i, k, part, out) {
    n = split(dir "/" t, part, "/"); k = 0
    for (i = 1; i <= n; i++) {
      if (part[i] == "" || part[i] == ".") continue
      if (part[i] == "..") { if (k == 0) return ""; k--; continue }
      seg[++k] = part[i]
    }
    out = "."; for (i = 1; i <= k; i++) out = (i == 1 ? seg[i] : out "/" seg[i])
    return out
  }
  /^E / { p = substr($0, 3); have[p] = 1; while (sub(/\/[^\/]*$/, "", p)) have[p] = 1; next }
  /^G / {
    s = substr($0, 3)
    if (!match(s, /:[0-9]+:/)) next
    p = substr(s, 1, RSTART - 1); ln = substr(s, RSTART + 1, RLENGTH - 2); t = substr(s, RSTART + RLENGTH)
    if (t ~ /^[ \t]*(```|~~~)/) { fence[p] = !fence[p]; next }
    if (fence[p]) next
    gsub(/`[^`]*`/, "", t)
    dir = p; if (!sub(/\/[^\/]*$/, "", dir)) dir = ""
    while (match(t, /\]\([^)]*\)/)) {
      l = substr(t, RSTART + 2, RLENGTH - 3); t = substr(t, RSTART + RLENGTH)
      sub(/^[ \t]+/, "", l); sub(/[ \t].*$/, "", l); sub(/^</, "", l); sub(/>$/, "", l)
      if (l == "" || l ~ /^#/ || l ~ /^[A-Za-z][A-Za-z0-9+.-]*:/) continue
      target = l; sub(/[#?].*$/, "", target); gsub(/%20/, " ", target)
      if (target ~ /^\//) { state = "absolute"; r = "." }
      else { r = resolve(dir, target); if (r == "") { state = "outside"; r = "." } else if (staged == "") state = "disk"; else state = (r in have) ? "ok" : "missing" }
      print p "\t" ln "\t" l "\t" r "\t" state
    }
  }')
broken=$(printf '%s\n' "$links" | while IFS="$tab" read -r src ln l r state; do
  case $state in
    (ok | "") ;;
    (disk) [ -e "$r" ] || echo "$src:$ln: $l" ;;
    (outside) echo "$src:$ln: $l (points outside the repository)" ;;
    (absolute) echo "$src:$ln: $l (not a relative link)" ;;
    (*) echo "$src:$ln: $l" ;;
  esac
done)
[ -z "$broken" ] || fail "links to nothing; fix each one or the file it points to (see Links in AGENTS.md):
$broken"

if [ "$in_git" = no ]; then
  echo "check: not the top of a git repository; the git hooks, secrets and encryption are NOT checked, and encrypted/ is not encrypted" >&2
  exit $status
fi

# 5. The git hooks are on and executable, both on disk (where git runs them from) and in the
#    commit; otherwise none of this runs.
[ "$(git config core.hooksPath)" = "blueprint/git-hooks" ] || fail "the git hooks are off; run: git config core.hooksPath blueprint/git-hooks"
for h in pre-commit pre-merge-commit commit-msg post-commit post-merge post-rewrite; do
  [ -x "$root/blueprint/git-hooks/$h" ] || fail "blueprint/git-hooks/$h is missing or not executable on disk, so git would skip it"
  [ -x "$base/blueprint/git-hooks/$h" ] || fail "blueprint/git-hooks/$h is missing or not executable in the commit"
done

# 6. Scripts and git hooks keep Unix line endings on every system (core.autocrlf would break them).
for f in $(git ls-files -- 'blueprint/scripts/*' 'blueprint/git-hooks/*' 'custom/git-hooks/*'); do
  [ "$(git check-attr $cached eol -- "$f" | sed 's/.*: eol: //')" = lf ] || fail "$f needs 'eol=lf' in .gitattributes (see blueprint/README.md)"
done

# 7. No secret file is tracked, wherever it is, in any letter case, whatever .gitignore says.
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

# 8. Everything tracked in encrypted/ (any letter case), except its README, is set to be
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
# Archiving never takes anything out of encrypted/: archive/encrypted/ would not be encrypted.
leak=$(printf '%s\n' "$files" | awk 'tolower($0) ~ /^archive\/encrypted\//')
[ -z "$leak" ] || fail "sensitive material stays in encrypted/, never in archive/:
$leak"

# 9. After an operation git cannot block, the new commit's message must pass the owner's hook.
if [ "$mode" = --warn ] && [ -f custom/git-hooks/commit-msg ]; then
  m=$(mktemp)
  git log -1 --format=%B > "$m"
  sh custom/git-hooks/commit-msg "$m" || status=1
  rm -f "$m"
fi

if [ "$mode" = --warn ] && [ $status -ne 0 ]; then
  echo "" >&2
  echo "check: WARNING: the last operation left the repository failing the checks above." >&2
  echo "check: git gives no hook that can block it. Undo it with: git reset --hard ORIG_HEAD" >&2
  exit 0
fi
exit $status
