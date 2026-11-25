#!/bin/sh
# Proves update.sh against a base published in a throwaway folder: it takes the latest version
# (numbers, not letters: v0.10 after v0.9), or the one asked for, swaps blueprint/ whole even when
# that replaces update.sh itself, runs install.sh, touches nothing of the owner's and leaves no
# link to the base. It refuses uncommitted changes to blueprint/, an unknown version, a version
# whose VERSION file says otherwise, and a base with no versions.
# Each published version carries its fingerprint, so the copies run no tests of the base;
# every other check is real.
set -u
export LC_ALL=C

src=$(cd "$(dirname "$0")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
tmp=$(cd "$tmp" && pwd -P)
# install.sh runs global.sh, which writes in the home folder; a throwaway one keeps the real one out.
export HOME="$tmp/home"
mkdir -p "$HOME"
unset CLAUDE_CONFIG_DIR CODEX_HOME XDG_CONFIG_HOME
pub="$tmp/pub"
r="$tmp/r"
export HITO_BLUEPRINT_URL="$pub"
passed=0
failed=0

ok() { passed=$((passed + 1)); }
ko() { failed=$((failed + 1)); echo "FAIL: $1" >&2; }
publish() { # version, then an optional line added to blueprint/templates/journal.md
  printf '%s\n' "$1" > "$pub/blueprint/VERSION"
  { printf '# Changelog\n\n## %s\n\n- Change of %s.\n' "$1" "$1"; [ ! -f "$pub/blueprint/CHANGELOG.md" ] || sed -n '/^## /,$p' "$pub/blueprint/CHANGELOG.md"; } > "$tmp/c" && mv "$tmp/c" "$pub/blueprint/CHANGELOG.md"
  [ -z "${2:-}" ] || printf '%s\n' "$2" >> "$pub/blueprint/templates/journal.md"
  (cd "$pub" && sh blueprint/scripts/check.sh --manifest > "$tmp/manifest") && mv "$tmp/manifest" "$pub/blueprint/MANIFEST"
  git -C "$pub" add -A && git -C "$pub" -c user.name=test -c user.email=test@example.com commit -qm "release $1" && git -C "$pub" tag "$1"
}
run() { (cd "$r" && sh blueprint/scripts/update.sh "$@") < /dev/null > "$tmp/out" 2>&1; }
pass() { d=$1; shift; if run "$@"; then ok; else ko "$d: $(cat "$tmp/out")"; fi; }
reject() { d=$1; want=$2; shift 2
  if run "$@"; then ko "$d (it passed)"; elif grep -qF "$want" "$tmp/out"; then ok; else ko "$d, for the wrong reason: $(cat "$tmp/out")"; fi; }
version() { cat "$r/blueprint/VERSION" 2> /dev/null; }

# A published base with v0.1, and a copy of it already set up, as the template leaves it.
# Like the real base, it keeps Unix line endings: without that, git on Windows (core.autocrlf)
# would hand the copy scripts with Windows line endings, which sh cannot run.
mkdir -p "$pub" && git -C "$pub" init -q && git -C "$pub" config hito.develop true && cp -R "$src" "$pub/blueprint" && rm -f "$pub/blueprint/CHANGELOG.md"
printf '* text=auto eol=lf\n' > "$pub/.gitattributes"
echo old > "$pub/blueprint/OLD.txt"
publish v0.1
setup() {
  rm -rf "$r"; mkdir -p "$r"; git -C "$pub" archive v0.1 | tar -x -C "$r"
  git -C "$r" init -q
  (cd "$r" && sh blueprint/scripts/install.sh) < /dev/null > "$tmp/setup" 2>&1 || ko "the copy sets up: $(cat "$tmp/setup")"
  mkdir -p "$r/knowledge"; printf -- '---\ntype: knowledge\ncreated: 2020-01-01\n---\n\nMine.\n' > "$r/knowledge/mine.md"
  printf -- '- [knowledge](knowledge/mine.md)\n' >> "$r/README.md"
  git -C "$r" add -A && git -C "$r" -c user.name=test -c user.email=test@example.com commit -qm start > /dev/null 2>&1 || ko "the copy commits"
}

# v0.2 changes the journal template and update.sh itself; v0.9 and v0.10 test the order.
sed 's|then commit"|then commit (new update.sh)"|' "$pub/blueprint/scripts/update.sh" > "$tmp/u" && cat "$tmp/u" > "$pub/blueprint/scripts/update.sh"
rm "$pub/blueprint/OLD.txt"
publish v0.2 '## Today'
publish v0.9
publish v0.10
git -C "$pub" tag v9.9-rc  # not a version: the latest stays v0.10

setup; git -C "$r" config --unset core.hooksPath; pass "updates to the latest version"
if [ "$(version)" = v0.10 ]; then ok; else ko "the latest is v0.10, not v0.9 (got $(version))"; fi
if grep -qxF '## Today' "$r/blueprint/templates/journal.md"; then ok; else ko "brings the new files"; fi
if [ ! -e "$r/blueprint/OLD.txt" ]; then ok; else ko "drops the files the new version no longer has"; fi
if grep -qF 'is now v0.10 (was v0.1)' "$tmp/out"; then ok; else ko "the old update.sh finishes after replacing itself: $(cat "$tmp/out")"; fi
if grep -qF 'new update.sh' "$r/blueprint/scripts/update.sh"; then ok; else ko "update.sh itself is replaced"; fi
if grep -qxF -- '- Change of v0.10.' "$tmp/out" && grep -qxF -- '- Change of v0.2.' "$tmp/out" && ! grep -qxF -- '- Change of v0.1.' "$tmp/out"; then ok; else ko "shows the changes after the old version, and not the old one's: $(cat "$tmp/out")"; fi
if [ "$(git -C "$r" status --porcelain | grep -v ' blueprint/')" = "" ]; then ok; else ko "changes nothing outside blueprint/: $(git -C "$r" status --porcelain)"; fi
if grep -qxF 'Mine.' "$r/knowledge/mine.md"; then ok; else ko "keeps the owner's notes"; fi
if [ -z "$(git -C "$r" remote)" ]; then ok; else ko "leaves no remote to the base"; fi
if [ "$(git -C "$r" config core.hooksPath)" = blueprint/git-hooks ]; then ok; else ko "install.sh ran after it"; fi
git -C "$r" add -A
if git -C "$r" -c user.name=test -c user.email=test@example.com commit -qm "chore: update blueprint to v0.10" > "$tmp/c" 2>&1; then ok; else ko "the update can be committed through the git hooks: $(cat "$tmp/c")"; fi
pass "runs again"
if grep -qF 'already v0.10' "$tmp/out" && [ -z "$(git -C "$r" status --porcelain)" ]; then ok; else ko "running again changes nothing"; fi

setup; pass "updates to the version asked for" v0.2
if [ "$(version)" = v0.2 ]; then ok; else ko "v0.2 asked, got $(version)"; fi

setup; echo '# edited' >> "$r/blueprint/rules/links.md"
reject "refuses uncommitted changes to blueprint/" "has changes that are not committed"
if grep -qxF '# edited' "$r/blueprint/rules/links.md"; then ok; else ko "leaves blueprint/ as it was when it refuses"; fi

setup; reject "refuses a version that does not exist" "cannot download v0.7" v0.7
if [ "$(version)" = v0.1 ]; then ok; else ko "leaves blueprint/ as it was when the download fails"; fi
reject "rejects what is not a version" "is not a version" latest

printf 'v9.9\n' > "$pub/blueprint/VERSION"; git -C "$pub" add -A; git -C "$pub" -c user.name=test -c user.email=test@example.com commit -qm bad; git -C "$pub" tag v0.11
setup; reject "refuses a version whose VERSION says otherwise" "v0.11 says it is version 'v9.9'" v0.11
if [ "$(version)" = v0.1 ]; then ok; else ko "leaves blueprint/ as it was"; fi

setup; HITO_BLUEPRINT_URL="$tmp/nothing" reject "says when the base cannot be reached" "cannot reach"
rm -rf "$tmp/empty"; git init -q "$tmp/empty"; git -C "$tmp/empty" -c user.name=test -c user.email=test@example.com commit -q --allow-empty -m x
HITO_BLUEPRINT_URL="$tmp/empty" reject "says when the base has no version yet" "has no version yet"

# Every published version must carry its VERSION file; this copy of the base has one.
if grep -Eqx 'v[0-9]+\.[0-9]+' "$src/VERSION"; then ok; else ko "blueprint/VERSION holds a version such as v0.1"; fi

echo "test-update: $passed passed, $failed failed"
[ "$failed" -eq 0 ]
