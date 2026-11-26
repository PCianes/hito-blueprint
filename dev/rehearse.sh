#!/bin/sh
# The rehearsal: hito used as a person uses it, with real commits through the git hooks, on what
# is committed here (HEAD). The tests prove each script alone; this proves them together.
#   sh dev/rehearse.sh           rehearse here; the pipeline runs it on every push
#   sh dev/rehearse.sh <copy>    also update a throwaway clone of that copy (yours, say) to HEAD
# Everything happens in a throwaway folder with a throwaway home folder; nothing here or in the
# copy given is touched. Only made-up data is used, because this file is public.
set -u
export LC_ALL=C
for v in $(env | sed -n 's/^\(GIT_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$v"; done

here=$(cd "$(dirname "$0")/.." && pwd -P)
real=${1:-}
[ -z "$real" ] || real=$(cd "$real" && pwd -P) || exit 2
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
tmp=$(cd "$tmp" && pwd -P)
export HOME="$tmp/home"
mkdir -p "$HOME"
unset CLAUDE_CONFIG_DIR CODEX_HOME XDG_CONFIG_HOME HITO_TODAY HITO_BLUEPRINT_URL HITO_IN_TEST
git config --global user.name "Test Owner"
git config --global user.email test@example.com
git config --global init.defaultBranch main
git config --global advice.detachedHead false
bad=0
n=0

# try DESCRIPTION pass|reject COMMAND...: a command that must pass, or must be refused.
try() {
  d=$1; want=$2; shift 2; n=$((n + 1))
  if "$@" > "$tmp/out" 2>&1; then got=pass; else got=reject; fi
  if [ "$got" = "$want" ]; then echo "ok    $d ($got)"
  else bad=$((bad + 1)); echo "FAIL  $d ($got, should $want)"; sed 's/^/        /' "$tmp/out" | head -8; fi
}
# is DESCRIPTION COMMAND...: a condition that must hold.
is() {
  d=$1; shift; n=$((n + 1))
  if "$@" > /dev/null 2>&1; then echo "ok    $d"; else bad=$((bad + 1)); echo "FAIL  $d"; fi
}
note() { mkdir -p "$(dirname "$1")"; printf -- '---\ntype: %s\ncreated: 2026-01-01\n---\n\n%s\n' "$2" "${3:-Text.}" > "$1"; }
version=$(git -C "$here" show HEAD:blueprint/VERSION)
previous=$(git -C "$here" tag -l 'v*.*' | grep -E '^v[0-9]+\.[0-9]+$' | grep -vx "$version" | sort -t . -k 1.2,1n -k 2,2n | tail -n 1)

echo "== this repository, as committed ($version)"
D="$tmp/develop"; git clone -q "$here" "$D"
git -C "$D" config core.hooksPath blueprint/git-hooks; git -C "$D" config hito.develop true
try "the full check, tests included, where the base is developed" pass sh "$D/blueprint/scripts/check.sh"
is "blueprint/MANIFEST matches blueprint/" sh -c "cd '$D' && sh blueprint/scripts/check.sh --manifest | cmp -s - blueprint/MANIFEST"
is "the CHANGELOG has a section for $version" grep -qx "## $version" "$D/blueprint/CHANGELOG.md"
is "the pipeline runs only in hito-blueprint" grep -q "if: github.repository == 'PCianes/hito-blueprint'" "$D/.github/workflows/check.yml"
echo "El tren sale de la ciudad" >> "$D/README.md"; git -C "$D" add README.md
try "a commit with notes in Spanish never reaches the public base" reject git -C "$D" commit -qm "docs: notes"
git -C "$D" checkout -q -- README.md 2> /dev/null; git -C "$D" reset -q --hard
git -C "$D" commit -q --allow-empty -m "docs: notas de la semana" > "$tmp/out" 2>&1
is "nor a commit message in Spanish" test "$(git -C "$D" log -1 --format=%s)" != "docs: notas de la semana"

echo "== a new copy, as \"Use this template\" creates it"
C="$tmp/copy"; mkdir -p "$C"; git -C "$here" archive HEAD | tar -x -C "$C"
git -C "$C" init -q; git -C "$C" add -A; git -C "$C" commit -q --no-verify -m "Initial commit"
try "install.sh" pass sh "$C/blueprint/scripts/install.sh"
is "install.sh changes nothing: the template already has it" test -z "$(git -C "$C" status --porcelain)"
is "the copy has no remote" test -z "$(git -C "$C" remote)"
t0=$(date +%s); try "the full check of a copy" pass sh "$C/blueprint/scripts/check.sh"; t1=$(date +%s)
is "takes seconds, not minutes ($((t1 - t0)) s)" test $((t1 - t0)) -le 20
note "$C/knowledge/first.md" knowledge; printf -- '- [first](knowledge/first.md)\n' >> "$C/README.md"; git -C "$C" add -A
try "first note, committed through the git hooks" pass git -C "$C" commit -qm "docs: first note"
echo "El tren sale de la ciudad" >> "$C/knowledge/first.md"; git -C "$C" add -A
try "notes in Spanish are fine in a copy" pass git -C "$C" commit -qm "docs: notas de la semana"

echo "== an owner's mistakes, with real commits"
cd "$C" || exit 1
reset() { git reset -q --hard; git clean -qfd; }
mkdir -p custom/rules custom/git-hooks
printf '## Style\n\nWrite short sentences.\n' > custom/rules/my-style.md
printf '#!/bin/sh\n! grep -qiE "^co-authored-by *:" "$1"\n' > custom/git-hooks/commit-msg
sh blueprint/scripts/rules.sh; git add -A
try "an owner's rule and commit-msg hook" pass git commit -qm "feat: my rule and hook"
echo "More." >> custom/rules/my-style.md
try "a changed rule without regenerating AGENTS.md" reject git commit -qam "feat: change"
reset; echo "More." >> custom/rules/my-style.md; sh blueprint/scripts/rules.sh
try "a commit that leaves the regenerated AGENTS.md out" reject git commit -qm "feat: change" custom/rules/my-style.md
try "the rule and AGENTS.md together" pass git commit -qam "feat: change"
for s in projects/x/app.pem .ENV prod.ENV x.Key .Env.local; do
  reset; mkdir -p "$(dirname "$s")"; echo k > "$s"; git add -f "$s"
  try "a secret file forced in: $s" reject git commit -qm "feat: secret"
  git rm -q --cached "$s" 2> /dev/null; rm -f "$s"
done
reset; note knowledge/two.md knowledge; printf -- '- [two](knowledge/two.md)\n' >> README.md; git add -A
try "a message with an assistant's trailer, by the owner's hook" reject git commit -qm "feat: x" -m "Co-Authored-By: An Assistant <a@example.com>"
try "the same commit with a clean message" pass git commit -qm "feat: second note"
reset; echo "no frontmatter" > knowledge/loose.md; git add -A
try "a note without frontmatter" reject git commit -qm "docs: loose"
reset; note journal/2026/2026-01-01.md knowledge; git add -A
try "a journal day with the wrong type" reject git commit -qm "docs: day"
reset; note journal/2026/2026-01-01.md journal; git add -A
try "a journal day in its year folder" pass git commit -qm "docs: day"
reset; note knowledge/linked.md knowledge "[gone](gone.md)"; printf -- '- [linked](knowledge/linked.md)\n' >> README.md; git add -A
try "a link to nothing" reject git commit -qm "docs: linked"
reset; echo "# edited" >> blueprint/rules/links.md; git add -A
try "an edit to blueprint/ in a copy" reject git commit -qm "fix: edit the base"
reset; chmod -x blueprint/git-hooks/pre-commit
if [ -x blueprint/git-hooks/pre-commit ]; then
  echo "      skipped a git hook that lost its executable bit: this file system has no such bit"
else
  try "a git hook that lost its executable bit on disk" reject sh blueprint/scripts/check.sh --staged
fi
reset; chmod +x blueprint/git-hooks/pre-commit
mkdir -p custom/skills/my-demo; printf -- '---\nname: my-demo\ndescription: Demo.\n---\n\n# Demo\n' > custom/skills/my-demo/SKILL.md; git add -A
try "a new skill without its copies" reject git commit -qm "feat: skill"
sh blueprint/scripts/skills.sh; git add -A
try "the skill with its copies for each agent" pass git commit -qm "feat: skill"
echo x >> .claude/skills/my-demo/SKILL.md; git add -A
try "a skill copy edited by hand" reject git commit -qm "feat: edit"
reset
if command -v git-crypt > /dev/null 2>&1; then
  git-crypt init > /dev/null 2>&1; sh blueprint/scripts/install.sh > /dev/null 2>&1
  is "after git-crypt init, install.sh sets encryption for encrypted/" grep -q git-crypt .gitattributes
  git add -A; try "the encryption setting, committed" pass git commit -qm "chore: encrypt encrypted/"
  printf 'private data\n' > encrypted/naïve.md; git add -A
  try "a file in encrypted/, with a name that is not ASCII" pass git commit -qm "feat: private"
  h=$(git cat-file blob "HEAD:encrypted/naïve.md" | dd bs=1 skip=1 count=8 2> /dev/null)
  rm encrypted/naïve.md; git checkout -q -- encrypted/naïve.md
  is "stored encrypted, and back in clear identical" test "$h" = GITCRYPT -a "$(cat encrypted/naïve.md)" = "private data"
  perl -0pi -e 's/^encrypted\/\*\* filter.*\n//m' .gitattributes; echo other > encrypted/other.md; git add -A
  try "removing the encryption rule and adding a file" reject git commit -qm "chore: no encryption"
  reset
else
  echo "skip  git-crypt is not installed: encryption not rehearsed"
fi
git checkout -q -b side; echo k > .env; git add -f .env; git commit -q --no-verify -m "feat: secret past the hook"; git checkout -q main
try "a merge commit from a branch with .env" reject git merge -q --no-ff --no-edit side
git merge --abort 2> /dev/null; reset
git merge -q --ff-only side > /dev/null 2> "$tmp/out"
is "a fast-forward merge with .env warns" grep -q "WARNING: the last operation" "$tmp/out"
git reset -q --hard ORIG_HEAD
git cherry-pick side > /dev/null 2> "$tmp/out"
is "a cherry-pick with .env warns" grep -q "WARNING: the last operation" "$tmp/out"
git reset -q --hard HEAD~1
cd "$tmp" || exit 1

echo "== another machine: clone and install"
I="$tmp/clone"; git clone -q "$C" "$I"
try "a clone without the git hooks on is stopped" reject sh "$I/blueprint/scripts/check.sh"
try "install.sh in the clone" pass sh "$I/blueprint/scripts/install.sh"
is "install.sh turned the git hooks on" test "$(git -C "$I" config core.hooksPath)" = blueprint/git-hooks
is "and changed nothing" test -z "$(git -C "$I" status --porcelain)"
W="$tmp/windows"; git -c core.autocrlf=true clone -q "$C" "$W"; git -C "$W" config core.autocrlf true; git -C "$W" config core.hooksPath blueprint/git-hooks
try "a clone with core.autocrlf=true (Windows)" pass sh "$W/blueprint/scripts/check.sh"

echo "== rules and skills for every folder (home folder: $HOME)"
G="$tmp/global"; git clone -q "$C" "$G"; git -C "$G" config core.hooksPath blueprint/git-hooks
mkdir -p "$HOME/.claude/skills/Theirs" "$HOME/.gemini" "$HOME/.codex" "$HOME/.config/opencode"
printf '# Mine\nkeep' > "$HOME/.claude/CLAUDE.md"; echo theirs > "$HOME/.claude/skills/Theirs/SKILL.md"; printf '# Mine\n' > "$HOME/.codex/AGENTS.md"
gp=$(cd "$G" && pwd -P)
mkdir -p "$G/custom/global/rules" "$G/custom/global/skills/my-probe"
echo '## Anywhere' > "$G/custom/global/rules/my-any.md"
printf -- '---\nname: my-probe\ndescription: Probe.\n---\n' > "$G/custom/global/skills/my-probe/SKILL.md"
try "install.sh with rules for every folder, without a terminal" pass sh "$G/blueprint/scripts/install.sh"
is "the rule for every folder ends AGENTS.md too" grep -qxF "## Anywhere" "$G/AGENTS.md"
is "without a terminal, the owner's CLAUDE.md is left alone" test "$(cat "$HOME/.claude/CLAUDE.md")" = "$(printf '# Mine\nkeep')"
is "Gemini imports GLOBAL.md" test "$(cat "$HOME/.gemini/GEMINI.md")" = "@$gp/GLOBAL.md"
is "Codex's own AGENTS.md is left alone" test "$(cat "$HOME/.codex/AGENTS.md")" = "# Mine"
is "OpenCode gets the copy" grep -qxF '## Anywhere' "$HOME/.config/opencode/AGENTS.md"
is "the skill reaches both folders, and the others stay" test -f "$HOME/.claude/skills/my-probe/SKILL.md" -a -f "$HOME/.agents/skills/my-probe/SKILL.md" -a "$(cat "$HOME/.claude/skills/Theirs/SKILL.md")" = theirs
git -C "$G" add -A; try "commit with GLOBAL.md and the skill" pass git -C "$G" commit -qm "feat: global"
echo '## Changed' > "$G/custom/global/rules/my-any.md"; git -C "$G" add -A
try "commit with GLOBAL.md out of date" reject git -C "$G" commit -qm "feat: stale"
(cd "$G" && sh blueprint/scripts/rules.sh && git add -A); try "commit after regenerating it" pass git -C "$G" commit -qm "feat: changed"
is "the git hook after the commit updated OpenCode's copy" grep -qxF '## Changed' "$HOME/.config/opencode/AGENTS.md"
mv "$G" "$tmp/global-moved"; G="$tmp/global-moved"; gp=$(cd "$G" && pwd -P)
try "install.sh after moving the repository" pass sh "$G/blueprint/scripts/install.sh"
is "the import lines follow it, once" test "$(grep -c "@$gp/GLOBAL.md" "$HOME/.gemini/GEMINI.md")" = 1
git -C "$G" rm -rq custom/global; (cd "$G" && sh blueprint/scripts/rules.sh && git add -A)
try "commit that removes everything for every folder" pass git -C "$G" commit -qm "feat: no global"
is "what it put there is gone, and the owner's files stay" test ! -e "$HOME/.gemini/GEMINI.md" -a ! -e "$HOME/.agents/skills/my-probe" -a "$(cat "$HOME/.codex/AGENTS.md")" = "# Mine" -a "$(cat "$HOME/.claude/CLAUDE.md")" = "$(printf '# Mine\nkeep')"

echo "== today.sh"
T="$tmp/today"; git clone -q "$C" "$T"; git -C "$T" config core.hooksPath blueprint/git-hooks
out=$(cd / && HITO_TODAY=2027-01-04 sh "$T/blueprint/scripts/today.sh")
is "from another folder it creates the day's note and prints its path" test "$out" = "$(cd "$T" && pwd -P)/journal/2027/2027-01-04.md" -a -f "$out"
git -C "$T" add -A; try "the day's note, committed" pass git -C "$T" commit -qm "docs: day"
echo "Mine." >> "$out"; HITO_TODAY=2027-01-04 sh "$T/blueprint/scripts/today.sh" > /dev/null
is "it never overwrites a note that exists" grep -qxF "Mine." "$out"

echo "== update.sh from the previous version${previous:+ ($previous)} to $version"
if [ -z "$previous" ]; then
  echo "skip  no earlier version is tagged here"
else
  P="$tmp/published"; git clone -q "$here" "$P"
  git -C "$P" tag -l "$version" | grep -q . || git -C "$P" tag "$version" HEAD
  U="$tmp/old-copy"; mkdir -p "$U"; git -C "$P" archive "$previous" | tar -x -C "$U"
  git -C "$U" init -q; git -C "$U" config core.hooksPath blueprint/git-hooks
  note "$U/knowledge/mine.md" knowledge "Mine."; printf -- '- [mine](knowledge/mine.md)\n' >> "$U/README.md"
  git -C "$U" add -A; git -C "$U" commit -q --no-verify -m "a copy at $previous"
  try "update.sh to the latest version" pass env HITO_BLUEPRINT_URL="$P" sh "$U/blueprint/scripts/update.sh"
  is "the copy is at $version" test "$(cat "$U/blueprint/VERSION")" = "$version"
  is "its note is untouched" grep -qxF "Mine." "$U/knowledge/mine.md"
  is "nothing outside blueprint/, AGENTS.md and .gitignore changed" test -z "$(git -C "$U" status --porcelain | grep -v ' blueprint/' | grep -v ' AGENTS.md$' | grep -v ' .gitignore$')"
  gi=$(git -C "$U" diff -U0 .gitignore | grep '^[-+][^-+]' || true)
  is ".gitignore at most gained /raw/" test "$gi" = "" -o "$gi" = "+/raw/"
  git -C "$U" add -A; t0=$(date +%s)
  try "the update, committed through the git hooks" pass git -C "$U" commit -qm "chore: update blueprint to $version"
  t1=$(date +%s); is "in seconds ($((t1 - t0)) s)" test $((t1 - t0)) -le 20
  is "still no remote" test -z "$(git -C "$U" remote)"
  try "update.sh once more says it is up to date" pass env HITO_BLUEPRINT_URL="$P" sh "$U/blueprint/scripts/update.sh"
  is "and changes nothing" test -z "$(git -C "$U" status --porcelain)"
fi

if [ -n "$real" ]; then
  echo "== a real copy: $real, in a throwaway clone"
  if [ -z "$previous" ] && [ -z "${P:-}" ]; then P="$tmp/published"; git clone -q "$here" "$P"; git -C "$P" tag "$version" HEAD; fi
  R="$tmp/real"; git clone -q "$real" "$R"; git -C "$R" config core.hooksPath blueprint/git-hooks
  remotes=$(git -C "$R" remote)
  try "update.sh to $version" pass env HITO_BLUEPRINT_URL="$P" sh "$R/blueprint/scripts/update.sh"
  echo "      changed: $(git -C "$R" status --porcelain | tr '\n' ' ')"
  is "only blueprint/ and AGENTS.md change" test -z "$(git -C "$R" status --porcelain | grep -v ' blueprint/' | grep -v ' AGENTS.md$')"
  git -C "$R" add -A; try "the update, committed through its git hooks" pass git -C "$R" commit -qm "chore: update blueprint to $version"
  is "no remote was added" test "$(git -C "$R" remote)" = "$remotes"
fi

echo "== $n checks, $bad failed"
[ "$bad" -eq 0 ]
