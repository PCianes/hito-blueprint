#!/bin/sh
# Proves install.sh: it sets up an empty repository that passes the check, changes nothing
# when run again, never overwrites what exists, and repairs what is missing.
# The copies get stub tests, so the check that install.sh runs at the end does not run this
# file again; every other check is real.
set -u
export LC_ALL=C

src=$(cd "$(dirname "$0")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
r="$tmp/r"
passed=0
failed=0

ok() { passed=$((passed + 1)); }
ko() { failed=$((failed + 1)); echo "FAIL: $1" >&2; }
setup() { # an empty repository with blueprint/ copied in
  rm -rf "$r"; mkdir -p "$r"
  cp -R "$src" "$r/blueprint"
  for t in "$r"/blueprint/scripts/test-*.sh; do echo 'exit 0' > "$t"; done
  git -C "$r" init -q
  git -C "$r" config user.name test; git -C "$r" config user.email test@example.com
}
run() { (cd "$r" && sh blueprint/scripts/install.sh) > "$tmp/out" 2>&1; }
pass() { if run; then ok; else ko "$1: $(cat "$tmp/out")"; fi; }
has() { if grep -qxF "$3" "$r/$2"; then ok; else ko "$1"; fi; }
snapshot() { (cd "$r" && find . -path ./.git -prune -o -type f -print | sort | xargs cksum; git config core.hooksPath); }

setup; pass "sets up an empty repository that passes the check"
for d in inbox goals projects knowledge sources journal encrypted archive; do
  [ -f "$r/$d/README.md" ] || ko "creates $d/README.md"
done
for f in README.md CLAUDE.md GEMINI.md AGENTS.md custom/README.md custom/disable; do [ -f "$r/$f" ] || ko "creates $f"; done
has "CLAUDE.md imports AGENTS.md" CLAUDE.md '@AGENTS.md'
has "GEMINI.md imports AGENTS.md" GEMINI.md '@./AGENTS.md'
if grep -q '^## Language' "$r/AGENTS.md"; then ko "the example rule in custom/README.md does not reach AGENTS.md"; else ok; fi
if [ "$(grep -v '^#' "$r/custom/disable" | grep -c .)" = 0 ]; then ok; else ko "custom/disable disables nothing until an example is uncommented"; fi
(cd "$r" && sed 's/^# rules\/links$/rules\/links/' custom/disable > d && mv d custom/disable && sh blueprint/scripts/rules.sh)
if grep -q '^## Links' "$r/AGENTS.md"; then ko "uncommenting an example in custom/disable leaves that rule out"; else ok; fi
has "ignores .env" .gitignore '.env'
has "ignores *.pem" .gitignore '*.pem'
has "keeps Unix line endings" .gitattributes '* text=auto eol=lf'
has "shows skill copies as one line" .gitattributes '.claude/skills/** -diff'
if grep -q git-crypt "$r/.gitattributes"; then ko "adds no git-crypt line before git-crypt init"; else ok; fi
if [ "$(git -C "$r" config core.hooksPath)" = blueprint/git-hooks ]; then ok; else ko "turns the git hooks on"; fi
git -C "$r" add -A
if git -C "$r" commit -qm "feat: start" > "$tmp/out" 2>&1; then ok; else ko "the result can be committed through the git hooks: $(cat "$tmp/out")"; fi

before=$(snapshot); pass "runs again"
if [ "$(snapshot)" = "$before" ]; then ok; else ko "running again changes nothing"; fi
if grep -q '^install: ' "$tmp/out"; then ko "running again reports nothing to do: $(cat "$tmp/out")"; else ok; fi

setup
mkdir -p "$r/projects"; printf -- '---\ntype: index\ncreated: 2020-01-01\n---\n\n# Mine\n\nBack to the [start](../README.md).\n' > "$r/projects/README.md"
printf '.DS_Store\n.env\n' > "$r/.gitignore"
printf 'encrypted/** filter=git-crypt diff=git-crypt -text\n' > "$r/.gitattributes"
pass "completes a repository that already has some files"
if grep -qxF '# Mine' "$r/projects/README.md"; then ok; else ko "keeps an existing README.md"; fi
if [ "$(grep -cxF '.env' "$r/.gitignore")" = 1 ] && grep -qxF '.DS_Store' "$r/.gitignore"; then ok; else ko "keeps .gitignore and adds no line twice"; fi
if [ "$(sed -n 1p "$r/.gitattributes")" = '* text=auto eol=lf' ] && [ "$(sed -n 2p "$r/.gitattributes")" = 'encrypted/** filter=git-crypt diff=git-crypt -text' ]; then ok
else ko "puts the line-ending rule first, before the lines it would override"; fi

setup; mkdir -p "$r/.git/git-crypt/keys"; pass "sets up encrypted/ once git-crypt is initialized"
has "encrypts encrypted/" .gitattributes 'encrypted/** filter=git-crypt diff=git-crypt -text'
has "keeps the README of encrypted/ in clear" .gitattributes 'encrypted/README.md !filter !diff text'
has "keeps .gitattributes in clear" .gitattributes '.gitattributes !filter !diff'
pass "runs again with git-crypt"
if [ "$(grep -cxF 'encrypted/** filter=git-crypt diff=git-crypt -text' "$r/.gitattributes")" = 1 ]; then ok; else ko "adds the git-crypt lines once"; fi

setup; git -C "$r" config core.hooksPath elsewhere; pass "repairs a wrong core.hooksPath"
if [ "$(git -C "$r" config core.hooksPath)" = blueprint/git-hooks ]; then ok; else ko "points core.hooksPath at blueprint/git-hooks"; fi

setup; rm -rf "$r/.git"; pass "works without git"
if grep -qF 'no git hooks' "$tmp/out"; then ok; else ko "says the git hooks are off without git"; fi

setup; echo 'gamma' >> "$r/blueprint/rules/ORDER"
if run; then ko "stops when rules.sh fails"; else ok; fi

setup; mkdir -p "$r/knowledge"; echo 'no frontmatter' > "$r/knowledge/x.md"
if run; then ko "ends with the check, which fails on a note without frontmatter"
elif grep -qF 'knowledge/x.md' "$tmp/out"; then ok
else ko "fails for the note, not another reason: $(cat "$tmp/out")"; fi

# The folders it creates are the content folders of the Folders rule.
rule=$(sed -n 's/^| `\([a-z]*\)\/` |.*/\1/p' "$src/rules/folders.md" | grep -vx -e blueprint -e custom | tr '\n' ' ')
mine=$(sed -n 's/^folders="\(.*\)"$/\1 /p' "$src/scripts/install.sh")
if [ "$rule" = "$mine" ]; then ok; else ko "creates the folders of rules/folders.md (rule: $rule; install.sh: $mine)"; fi

echo "test-install: $passed passed, $failed failed"
[ "$failed" -eq 0 ]
