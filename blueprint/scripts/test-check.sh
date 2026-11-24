#!/bin/sh
# Proves check.sh and the git hooks: a clean repository passes, and every failure they promise to
# catch is stopped, each for the right reason. Each case runs in a throwaway repository.
set -u

# Inside a hook, git exports variables such as GIT_INDEX_FILE that point at the real
# repository; the throwaway repositories below must never inherit them.
for v in $(env | sed -n 's/^\(GIT_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$v"; done

here=$(cd "$(dirname "$0")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
# The git hooks run global.sh after each commit; a throwaway home keeps it off the real one.
export HOME="$tmp/home"
mkdir -p "$HOME"
unset CLAUDE_CONFIG_DIR CODEX_HOME XDG_CONFIG_HOME
touch "$tmp/.hito-test-run" # lets the nested check.sh skip this file, and nothing else does
r="$tmp/r"
passed=0
failed=0

ok() { passed=$((passed + 1)); }
ko() { failed=$((failed + 1)); echo "FAIL: $1" >&2; }
check() { (cd "$r" && HITO_IN_TEST=$tmp sh blueprint/scripts/check.sh "$@" 2>&1 > /dev/null); }
pass() { d=$1; shift; if out=$(check "$@"); then ok; else ko "$d: $out"; fi; }
# reject DESCRIPTION EXPECTED-MESSAGE [ARGS]: must fail, and for that reason, not a crash.
reject() {
  d=$1; m=$2; shift 2
  if out=$(check "$@"); then ko "$d (passed)"
  elif printf '%s\n' "$out" | grep -qF "$m"; then ok
  else ko "$d (failed for another reason: $out)"; fi
}
stage_blob() { # content, path: put a file in the index exactly as given, bypassing filters
  b=$(printf -- "$1" | git -C "$r" hash-object -w --stdin)
  git -C "$r" update-index --add --cacheinfo "100644,$b,$2"
}
attributes() {
  printf '%s\n' '* text=auto eol=lf' 'encrypted/** filter=git-crypt diff=git-crypt -text' \
    'encrypted/README.md !filter !diff text' '.gitattributes !filter !diff'
}
# A copy carries the fingerprint of its blueprint/; this one is taken from what is on disk, as
# where the base is developed (only there may --manifest run), without leaving that setting.
fingerprint() { (cd "$r" && GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=hito.develop GIT_CONFIG_VALUE_0=true sh blueprint/scripts/check.sh --manifest > "$tmp/manifest" && mv "$tmp/manifest" blueprint/MANIFEST); }
develop() { git -C "$r" config hito.develop true; } # as where the base is developed
setup() { # a minimal valid copy with the git hooks on
  rm -rf "$r"
  mkdir -p "$r/encrypted"
  cp -R "$here/blueprint" "$r/blueprint"
  fingerprint
  printf -- "---\ntype: index\ncreated: 2026-01-01\n---\n\n# encrypted\n" > "$r/encrypted/README.md"
  attributes > "$r/.gitattributes"
  (cd "$r" && sh blueprint/scripts/rules.sh)
  git -C "$r" init -q
  git -C "$r" config core.hooksPath blueprint/git-hooks
  git -C "$r" add -A
}

setup; pass "passes a clean repository" --staged
pass "passes a clean working tree"

# encrypted/
setup; stage_blob 'secret\n' encrypted/plain.md
reject "stops a file stored in clear in encrypted/" "not encrypted" --staged
setup; stage_blob '\000GITCRYPT\000ciphertext' encrypted/sealed.md
pass "accepts a git-crypt blob in encrypted/" --staged
setup; stage_blob '\000GITCRYPT\000ciphertext' 'encrypted/naïve.md'
pass "accepts a git-crypt blob whose name is not ASCII" --staged
setup; stage_blob 'secret\n' Encrypted/plain.md
reject "stops a file in clear in Encrypted/, with a capital letter" "not encrypted" --staged
setup; stage_blob '\000GITCRYPT\000ciphertext' encrypted/sealed.md
grep -v '^encrypted/\*\*' "$r/.gitattributes" > "$tmp/a"; cp "$tmp/a" "$r/.gitattributes"; git -C "$r" add .gitattributes
reject "stops encrypted/ when git-crypt is not set for it" "not encrypted" --staged

# secrets: every pattern, any letter case, anywhere, whatever .gitignore says
for s in .env app.env .env.local app.key app.pem .ENV prod.ENV x.Key x.PEM .Env.local projects/x/app.pem; do
  setup; stage_blob 'secret\n' "$s"
  reject "stops a tracked secret: $s" "secret files are tracked" --staged
done
setup; stage_blob 'x\n' 'a"b.md'
reject "stops a file name git cannot show plainly" "cannot show plainly" --staged

# AGENTS.md, as the commit will carry it
setup; echo edited >> "$r/AGENTS.md"; git -C "$r" add AGENTS.md
reject "stops a hand-edited AGENTS.md" "out of date or was edited" --staged
setup; mkdir -p "$r/custom/rules"; echo '## my rule' > "$r/custom/rules/my-rule.md"
(cd "$r" && sh blueprint/scripts/rules.sh); git -C "$r" add AGENTS.md
reject "stops a AGENTS.md built from a rule left out of the commit" "out of date or was edited" --staged
git -C "$r" add -A; pass "passes once that rule is in the commit" --staged
setup; git -C "$r" rm -q --cached AGENTS.md
reject "stops a commit that drops AGENTS.md" "AGENTS.md is missing" --staged

# notes: type and created in the frontmatter, with a type the folder allows
note() { mkdir -p "$r/$(dirname "$1")"; printf '%b' "$2" > "$r/$1"; git -C "$r" add -- "$1"; }
fm() { printf -- '---\ntype: %s\ncreated: 2026-01-01\n---\n\n# x\n' "$1"; }
setup
note inbox/idea.md "$(fm inbox)"; note goals/vision.md "$(fm goal)"
note projects/README.md "$(fm index)"; note projects/talk/README.md "$(fm area)"; note projects/talk/plan.md "$(fm project)"
note knowledge/git.md "$(fm knowledge)"; note knowledge/leverage.md "$(fm model)"
note sources/video/transcript.md "$(fm source)"; note sources/video/slides.pdf 'pdf'
note journal/2026/2026-01-01.md "$(fm journal)"
pass "accepts a valid note in every folder, and skips files that are not Markdown" --staged
setup; note knowledge/x.md '# no frontmatter\n'
reject "stops a note without frontmatter" "knowledge/x.md: no frontmatter" --staged
setup; note knowledge/x.md '---\ntype: knowledge\ncreated: 2026-01-01\n\n# x\n'
reject "stops a frontmatter that is never closed" "never closed" --staged
setup; note knowledge/x.md '---\ncreated: 2026-01-01\n---\n\ntype: knowledge\n'
reject "stops a note whose type is only in the body" "knowledge/x.md: no type" --staged
setup; note knowledge/x.md "$(fm project)"
reject "stops a type its folder does not allow" 'type "project" is not allowed here' --staged
setup; note projects/README.md "$(fm project)"
reject "stops a folder README that is not an index" 'type "project" is not allowed here' --staged
setup; note projects/talk/README.md "$(fm index)"
reject "stops a project README typed as an index" 'type "index" is not allowed here' --staged
setup; note journal/2026/2026-01-01.md '---\ntype: journal\n---\n'
reject "stops a note without created" "no created date" --staged
setup; note journal/2026/2026-01-01.md '---\ntype: journal\ncreated: 21/11/2026\n---\n'
reject "stops a created date not written YYYY-MM-DD" "no created date" --staged
setup; stage_blob '---\r\ntype: inbox\r\ncreated: 2026-01-01\r\n---\r\n' inbox/x.md
pass "accepts a note with Windows line endings" --staged
setup; note inbox/x.md '# bad\n'; fm inbox > "$r/inbox/x.md"
reject "reads the note as the commit will carry it, not the disk" "inbox/x.md: no frontmatter" --staged
setup; note inbox/x.md "$(fm inbox)"; echo '# bad' > "$r/inbox/x.md"
reject "a manual run reads the disk" "inbox/x.md: no frontmatter"
setup; mkdir -p "$r/knowledge"; echo "# bad" > "$r/knowledge/new.md"
reject "a manual run reads a note not yet added to git" "knowledge/new.md: no frontmatter"
pass "a commit does not carry a note not yet added" --staged
echo "knowledge/new.md" > "$r/.gitignore"; pass "a manual run skips an ignored note"
setup; note archive/README.md "$(fm index)"; note archive/projects/talk/README.md "$(fm area)"; note archive/projects/talk/plan.md "$(fm project)"
pass "accepts archived notes with the type they had" --staged
setup; note archive/projects/talk/README.md "$(fm knowledge)"
reject "stops an archived note with a type its old folder does not allow" 'type "knowledge" is not allowed here' --staged
setup; stage_blob 'pin 1234\n' archive/encrypted/x.md
reject "stops sensitive material moved to archive/" "never in archive/" --staged

# links: every relative link points to something in the commit
L() { printf '%s\n%s\n' "$(fm knowledge)" "$1"; } # a note whose line 7 is $1
setup; note knowledge/a.md "$(L '[b](b.md)')"
reject "stops a link to a note that does not exist" "knowledge/a.md:7: b.md" --staged
note knowledge/b.md "$(fm knowledge)"; pass "passes once that note exists" --staged
setup; note knowledge/b.md "$(fm knowledge)"; note "knowledge/my note.md" "$(fm knowledge)"
note knowledge/a.md "$(L '[w](https://x.y) [m](mailto:a@b.c) [h](#top) [s](b.md#part) [d](../knowledge/) [n](my%20note.md) [t](b.md "title") `[c](nope.md)`')"
pass "skips web links, anchors and inline code; follows anchors, folders, spaces and titles" --staged
setup; note knowledge/a.md "$(printf '%s\n```\n[z](nope.md)\n```\n' "$(fm knowledge)")"
pass "skips links inside a code block" --staged
setup; note knowledge/a.md "$(L '![i](img.png)')"
reject "stops an image that does not exist" "knowledge/a.md:7: img.png" --staged
setup; note knowledge/a.md "$(L '[o](../../x.md)')"
reject "stops a link that leaves the repository" "points outside the repository" --staged
setup; note knowledge/a.md "$(L '[r](/AGENTS.md)')"
reject "stops an absolute link" "not a relative link" --staged
setup; note knowledge/a.md "$(L '[b](b.md)')"; fm knowledge > "$r/knowledge/b.md"
reject "a link counts only if its target is in the commit" "knowledge/a.md:7: b.md" --staged
pass "a manual run follows links on disk"
setup; mkdir -p "$r/knowledge"; L "[b](b.md)" > "$r/knowledge/a.md"
reject "a manual run follows links in a note not yet added to git" "knowledge/a.md:7: b.md"
setup; note projects/README.md "$(printf '%s\n%s\n' "$(fm index)" '[talk](talk/README.md)')"
note projects/talk/README.md "$(printf '%s\n%s\n' "$(fm area)" '[up](../README.md)')"
pass "a project linked both ways passes" --staged
mkdir -p "$r/archive/projects"; git -C "$r" mv projects/talk archive/projects/talk
reject "moving a project to archive/ shows the links to it it broke" "projects/README.md:7: talk/README.md" --staged
reject "and the links in it it broke" "archive/projects/talk/README.md:7: ../README.md" --staged

# skills, as the commit will carry them
setup; mkdir -p "$r/blueprint/skills/demo"; printf -- '---\nname: demo\ndescription: Demo.\n---\n' > "$r/blueprint/skills/demo/SKILL.md"; fingerprint; git -C "$r" add -A
reject "stops a skill whose copies were not generated" "is missing" --staged
(cd "$r" && sh blueprint/scripts/skills.sh); git -C "$r" add -A; pass "passes once the copies are generated and staged" --staged
echo edited >> "$r/.claude/skills/demo/SKILL.md"; git -C "$r" add -A
reject "stops a hand-edited skill copy" "out of date or was edited" --staged

# the git hooks themselves
setup; git -C "$r" config --unset core.hooksPath
reject "stops when the git hooks are off" "the git hooks are off"
for h in pre-commit pre-merge-commit commit-msg post-commit post-merge post-rewrite; do
  setup; chmod -x "$r/blueprint/git-hooks/$h"
  reject "stops when $h is not executable on disk, even if the index says it is" "$h is missing or not executable on disk" --staged
done
setup; grep -v 'eol=lf' "$r/.gitattributes" > "$tmp/a"; cp "$tmp/a" "$r/.gitattributes"; git -C "$r" add .gitattributes
reject "stops scripts without eol=lf" "needs 'eol=lf'" --staged

# the tests cannot be skipped by accident
setup; develop; printf 'exit 1\n' > "$r/blueprint/scripts/test-check.sh"; git -C "$r" add -A
if out=$(cd "$r" && HITO_IN_TEST=/nowhere sh blueprint/scripts/check.sh --staged 2>&1 > /dev/null); then
  ko "a stray HITO_IN_TEST skips test-check.sh (passed)"
elif printf '%s\n' "$out" | grep -qF "test-check.sh fails"; then ok
else ko "a stray HITO_IN_TEST: failed for another reason: $out"; fi

# where the base is developed, the tests of the scripts run only when the commit touches the
# scripts or git hooks
setup; develop; gc() { git -C "$r" -c user.name=T -c user.email=t@e.c commit -q --no-verify "$@" > /dev/null 2>&1; }
gc -m base; printf 'exit 1\n' > "$r/blueprint/scripts/test-rules.sh"; fingerprint; git -C "$r" add -A; gc -m "broken tests"
echo nota > "$r/note.md"; git -C "$r" add note.md
pass "a commit that does not touch the scripts skips their tests" --staged
echo "# touched" >> "$r/blueprint/scripts/rules.sh"; git -C "$r" add -A
reject "a commit that touches the scripts runs their tests" "test-rules.sh fails" --staged
git -C "$r" reset -q -- blueprint/scripts/rules.sh; git -C "$r" checkout -q -- blueprint/scripts/rules.sh
echo "* text=auto" >> "$r/.gitattributes"; git -C "$r" add .gitattributes
reject "a commit that touches .gitattributes runs the tests too" "test-rules.sh fails" --staged
git -C "$r" reset -q -- .gitattributes; git -C "$r" checkout -q -- .gitattributes
reject "a manual run always runs the tests" "test-rules.sh fails"

# in a copy, blueprint/ is the published version, and the tests of the base never run there
setup; echo "# edited" >> "$r/blueprint/scripts/today.sh"; git -C "$r" add -A
reject "stops an edit to blueprint/ in a copy" "blueprint/ is not the published version" --staged
reject "and names the file" "blueprint/scripts/today.sh" --staged
reject "and stops it on disk too" "blueprint/ is not the published version"
setup; echo extra > "$r/blueprint/extra.txt"; git -C "$r" add -A
reject "stops a file added to blueprint/ in a copy" "blueprint/extra.txt" --staged
setup; git -C "$r" rm -qf blueprint/scripts/today.sh
reject "stops a file removed from blueprint/ in a copy" "blueprint/scripts/today.sh" --staged
setup; git -C "$r" rm -qf blueprint/MANIFEST
reject "stops a copy without blueprint/MANIFEST" "blueprint/MANIFEST is missing" --staged
setup; echo "# edited" >> "$r/blueprint/scripts/today.sh"; git -C "$r" add -A; git -C "$r" config hito.develop false
reject "hito.develop set to false is a copy" "blueprint/ is not the published version" --staged
setup; develop; echo "# edited" >> "$r/blueprint/scripts/today.sh"; fingerprint; git -C "$r" add -A
pass "where the base is developed, blueprint/ may be edited, with its MANIFEST written again" --staged
setup; develop; echo "# edited" >> "$r/blueprint/scripts/today.sh"; git -C "$r" add -A
reject "where the base is developed, an out-of-date MANIFEST is stopped" "blueprint/MANIFEST is out of date" --staged
reject "and names the file" "blueprint/scripts/today.sh" --staged
setup; develop; git -C "$r" rm -qf blueprint/MANIFEST
reject "where the base is developed, a missing MANIFEST is stopped" "write it with: sh blueprint/scripts/check.sh --manifest" --staged
setup
if (cd "$r" && sh blueprint/scripts/check.sh --manifest > /dev/null 2>&1); then ko "a copy cannot write its own MANIFEST (it could)"; else ok; fi
develop
if (cd "$r" && sh blueprint/scripts/check.sh --manifest | grep -q ' scripts/check\.sh$'); then ok; else ko "where the base is developed, --manifest prints the fingerprint"; fi
setup; printf '.DS_Store\n' > "$r/.gitignore"; touch "$r/blueprint/.DS_Store"
pass "ignores files git ignores in blueprint/"
setup; printf 'exit 1\n' > "$r/blueprint/scripts/test-rules.sh"; fingerprint; git -C "$r" add -A
pass "a copy never runs the tests of the base" --staged
pass "not even by hand"
mkdir -p "$r/custom/git-hooks"; printf 'exit 1\n' > "$r/custom/git-hooks/test-mine.sh"; git -C "$r" add -A
reject "a copy still runs the owner's own tests" "custom/git-hooks/test-mine.sh fails" --staged
setup; rm -rf "$r/.git"; echo "# edited" >> "$r/blueprint/scripts/today.sh"
reject "stops an edit to blueprint/ without git" "blueprint/ is not the published version"

# where the base is developed, nothing personal reaches it
spanish() { setup; develop; git -C "$r" -c user.name=T -c user.email=t@e.c commit -q --no-verify -m base; }
spanish; echo "El tren sale de la ciudad" >> "$r/README.md"; git -C "$r" add -A
reject "stops a line in Spanish (by two common words) where the base is developed" "must not reach the public base" --staged
spanish; echo "the year: año" >> "$r/README.md"; git -C "$r" add -A
reject "stops a Spanish letter" "año" --staged
spanish; u=Users; echo "see /$u/someone/notes" >> "$r/README.md"; git -C "$r" add -A
reject "stops a home folder path" "/$u/someone" --staged
spanish; echo "dir=/$u/someone/x" > "$r/blueprint/example.sh"; git -C "$r" add -A
reject "stops a home folder path in a script too" "dir=/$u/someone" --staged
spanish; m="someone@gm""ail.com"; echo "write to $m" >> "$r/README.md"; git -C "$r" add -A
reject "stops a personal email address" "$m" --staged
spanish; mkdir -p "$r/knowledge"; printf -- '---\ntype: knowledge\ncreated: 2026-01-01\n---\n\nx\n' > "$r/knowledge/canción.md"; git -C "$r" add -A
reject "stops a file name in Spanish" "canción.md" --staged
spanish; printf '%s\n' "Sign with 1+x@users.noreply.github.com or test@example.com" "Los Angeles, a place" "a naïve reader" >> "$r/README.md"; printf 'printf "a\\n@AGENTS.md\\n"\n# El tren sale de la ciudad\n' > "$r/blueprint/example.sh"; fingerprint; git -C "$r" add -A
pass "accepts English, noreply and example addresses, one common Spanish word alone, a @file, and Spanish in a script" --staged
setup; echo "El tren sale de la ciudad" >> "$r/README.md"; git -C "$r" add -A
pass "in a copy, notes in Spanish are fine" --staged
printf 'docs: notas de la semana\n' > "$tmp/msg"
if (cd "$r" && sh blueprint/git-hooks/commit-msg "$tmp/msg"); then ok; else ko "in a copy, a commit message in Spanish is fine"; fi
develop
if (cd "$r" && sh blueprint/git-hooks/commit-msg "$tmp/msg" 2> /dev/null); then ko "where the base is developed, commit-msg stops a message in Spanish"; else ok; fi
printf 'docs: notes for today\n# Por favor, escribe el mensaje para los cambios\n' > "$tmp/msg"
if (cd "$r" && sh blueprint/git-hooks/commit-msg "$tmp/msg"); then ok; else ko "commit-msg skips the comment lines git strips"; fi

# --warn: after operations git cannot block, it warns and never fails
setup; stage_blob 'secret\n' .env
if out=$(check --warn); then
  if printf '%s\n' "$out" | grep -qF "WARNING: the last operation"; then ok; else ko "--warn does not warn: $out"; fi
else ko "--warn fails instead of warning"; fi

# the commit-msg extension point
setup; printf 'fix: x\n' > "$tmp/msg"
if (cd "$r" && sh blueprint/git-hooks/commit-msg "$tmp/msg"); then ok; else ko "commit-msg passes when custom/ has no hook"; fi
mkdir -p "$r/custom/git-hooks"; printf 'grep -q nope "$1" && exit 1\nexit 0\n' > "$r/custom/git-hooks/commit-msg"
if (cd "$r" && sh blueprint/git-hooks/commit-msg "$tmp/msg"); then ok; else ko "commit-msg passes a message the custom hook accepts"; fi
printf 'fix: nope\n' > "$tmp/msg"
if (cd "$r" && sh blueprint/git-hooks/commit-msg "$tmp/msg" 2> /dev/null); then ko "commit-msg stops a message the custom hook rejects"; else ok; fi
chmod -x "$r/custom/git-hooks/commit-msg"
if (cd "$r" && sh blueprint/git-hooks/commit-msg "$tmp/msg" 2> /dev/null); then ko "commit-msg runs the custom hook without its executable bit"; else ok; fi

# without git
setup; rm -rf "$r/.git"
pass "runs without git, on what it can check"
echo edited >> "$r/AGENTS.md"
reject "still stops a hand-edited AGENTS.md without git" "out of date or was edited"
setup; rm -rf "$r/.git"; mkdir -p "$r/inbox"; echo "# bad" > "$r/inbox/x.md"
reject "still checks notes without git" "inbox/x.md: no frontmatter"
setup; rm -rf "$r/.git"; mkdir -p "$r/knowledge"; L '[b](b.md)' > "$r/knowledge/a.md"
reject "still checks links without git" "knowledge/a.md:7: b.md"
setup; rm -rf "$r/.git"; git -C "$tmp" init -q
pass "inside another repository, checks only itself"
rm -rf "$tmp/.git"

echo "check.sh: $passed passed, $failed failed"
[ "$failed" -eq 0 ]
