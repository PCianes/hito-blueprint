#!/bin/sh
# Replaces blueprint/ with a published version of the base, then runs install.sh. A copy never
# edits blueprint/, so there is nothing to merge: the folder is swapped whole, and what the owner
# changed lives in custom/. The repository gets no link to the base: it is cloned into a
# temporary folder that is deleted afterwards, so nothing here can ever be pushed there. Review
# the result with git diff and commit it.
#   update.sh          update to the latest version (tags vMAJOR.MINOR)
#   update.sh v0.3     update to that version
# HITO_BLUEPRINT_URL replaces where the base is published (the tests use a local one).
# All of it is one block, so sh has read the whole script before it replaces itself.
{
set -u
export LC_ALL=C
root=$(cd "$(dirname "$0")/../.." && pwd -P)
url=${HITO_BLUEPRINT_URL:-https://github.com/PCianes/hito-blueprint}
fail() { echo "update: $*" >&2; exit 1; }
case ${1:-} in ('' | v[0-9]*.[0-9]*) ;; (*) echo "update: '$1' is not a version such as v0.3" >&2; exit 2 ;; esac
command -v git > /dev/null || fail "it needs git to download the base"
# Changes to blueprint/ would be lost, and they belong in custom/ anyway.
if git -C "$root" rev-parse --git-dir > /dev/null 2>&1; then
  [ -z "$(git -C "$root" status --porcelain -- blueprint)" ] ||
    fail "blueprint/ has changes that are not committed; they would be lost (changes of your own go in custom/)"
fi
tag=${1:-}
if [ -z "$tag" ]; then
  tags=$(git ls-remote --tags --refs "$url" 2> /dev/null) || fail "cannot reach $url"
  tag=$(printf '%s\n' "$tags" | sed 's|.*refs/tags/||' | grep -E '^v[0-9]+\.[0-9]+$' | sort -t . -k 1.2,1n -k 2,2n | tail -n 1)
  [ -n "$tag" ] || fail "$url has no version yet"
fi
now=$(cat "$root/blueprint/VERSION" 2> /dev/null)
[ "$now" != "$tag" ] || { echo "update: blueprint/ is already $tag"; exit 0; }
tmp=$(mktemp -d) || exit 1
trap 'rm -rf "$tmp"' EXIT
git clone -q --depth 1 --branch "$tag" "$url" "$tmp/base" 2> /dev/null || fail "cannot download $tag from $url"
[ -f "$tmp/base/blueprint/scripts/install.sh" ] || fail "$tag has no blueprint/scripts/install.sh"
[ "$(cat "$tmp/base/blueprint/VERSION" 2> /dev/null)" = "$tag" ] || fail "$tag says it is version '$(cat "$tmp/base/blueprint/VERSION" 2> /dev/null)'"
rm -rf "$root/blueprint" && cp -R "$tmp/base/blueprint" "$root/blueprint" || fail "could not replace blueprint/; restore it with: git checkout -- blueprint"
echo "update: blueprint/ is now $tag${now:+ (was $now)}; review it with git diff, then commit"
# What changed since the old version, from the new CHANGELOG.md: every section above the old one.
[ ! -f "$root/blueprint/CHANGELOG.md" ] || awk -v old="$now" '/^## v/ { if ($2 == old) exit; p = 1 } p' "$root/blueprint/CHANGELOG.md"
sh "$root/blueprint/scripts/install.sh"
exit $?
}
