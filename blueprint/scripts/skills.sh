#!/bin/sh
# Builds the skills agents read from blueprint/skills and custom/skills, and copies them to
# every folder where an agent looks for them: .agents/skills (Codex, OpenCode) and
# .claude/skills (Claude Code). Copies rather than links, so they work on any system.
# It also checks the owner's skills for every folder in custom/global/skills, which global.sh
# copies outside the repository, not here.
#   skills.sh          write them
#   skills.sh --check  fail if the copies differ from what would be written
set -eu
export LC_ALL=C

root=${HITO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}
base="$root/blueprint/skills"
custom="$root/custom/skills"
global="$root/custom/global/skills"
disable="$root/custom/disable"
targets=".agents/skills .claude/skills"

fail() { echo "skills: $*" >&2; exit 1; }

# Skill folder names in a directory; anything that is not a folder fails, except .DS_Store.
names_in() {
  [ -d "$1" ] || return 0
  for d in "$1"/* "$1"/.[!.]* "$1"/..?*; do
    [ -e "$d" ] || continue
    case ${d##*/} in (.DS_Store) continue ;; esac
    [ -d "$d" ] || fail "${d#"$root"/} is not a skill folder"
    echo "${d##*/}"
  done
}

# A skill is a folder with a SKILL.md whose frontmatter has name (equal to the folder name)
# and description, as the Agent Skills format requires.
validate() { # folder
  d=$1; n=${d##*/}; label=${d#"$root"/}
  printf '%s\n' "$n" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$' ||
    fail "$label: skill names use lowercase letters, digits and single hyphens"
  [ -f "$d/SKILL.md" ] || fail "$label has no SKILL.md"
  fm=$(tr -d '\r' < "$d/SKILL.md" | awk 'NR == 1 { if ($0 != "---") exit; next } $0 == "---" { exit } { print }')
  name=$(printf '%s\n' "$fm" | sed -n 's/^name:[[:space:]]*//p' | head -n 1 | sed 's/[[:space:]]*$//; s/^["'\'']//; s/["'\'']$//')
  [ "$name" = "$n" ] || fail "$label/SKILL.md: the frontmatter must say 'name: $n'"
  printf '%s\n' "$fm" | grep -qE '^description:[[:space:]]*[^[:space:]]' ||
    fail "$label/SKILL.md: the frontmatter needs a 'description'"
}

base_names=$(names_in "$base")
custom_names=$(names_in "$custom")
in_base() { printf '%s\n' "$base_names" | grep -qxF "$1"; }
for n in $base_names; do validate "$base/$n"; done
for n in $custom_names; do
  validate "$custom/$n"
  case $n in my-*) continue ;; esac
  in_base "$n" || fail "custom/skills/$n replaces no base skill (own skills are named my-*)"
done

# Skills for every folder are the owner's own, and their names must not clash with a skill
# the agents also find in the repository.
global_names=$(names_in "$global")
for n in $global_names; do
  validate "$global/$n"
  case $n in my-*) ;; (*) fail "custom/global/skills/$n: skills for every folder are your own, named my-*" ;; esac
  [ ! -d "$custom/$n" ] || fail "skill '$n' is both in custom/skills and custom/global/skills"
done

# Disabled base skills must exist and must not also be replaced.
disabled=" "
if [ -f "$disable" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    line=$(printf '%s' "$line" | tr -d '\r')
    case $line in (skills/*) ;; (*) continue ;; esac
    n=${line#skills/}
    in_base "$n" || fail "custom/disable: there is no base skill named '$n'"
    [ ! -d "$custom/$n" ] || fail "skill '$n' is both replaced and disabled"
    disabled="$disabled$n "
  done < "$disable"
fi

# The resolved set, written into a scratch folder: base skills unless disabled or replaced,
# then the owner's.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/out"
for n in $base_names; do
  case $disabled in (*" $n "*) continue ;; esac
  [ -d "$custom/$n" ] && continue
  cp -pR "$base/$n" "$tmp/out/$n"
done
for n in $custom_names; do cp -pR "$custom/$n" "$tmp/out/$n"; done
find "$tmp/out" -name .DS_Store -exec rm -f {} +
any=$(ls -A "$tmp/out")

# Contents and executable bits, as one comparable listing.
listing() { (cd "$1" && find . -type f | sort | while IFS= read -r f; do
  if [ -x "$f" ]; then x=x; else x=-; fi
  printf '%s %s %s\n' "$x" "$(cksum < "$f" | awk '{ print $1, $2 }')" "$f"
done); }

if [ "${1:-}" = "--check" ]; then
  want=$(listing "$tmp/out")
  for t in $targets; do
    if [ -z "$any" ]; then
      [ ! -d "$root/$t" ] || [ -z "$(ls -A "$root/$t")" ] || fail "$t holds skills that come from nowhere; run blueprint/scripts/skills.sh"
      continue
    fi
    [ -d "$root/$t" ] || fail "$t is missing; run blueprint/scripts/skills.sh"
    [ "$(listing "$root/$t")" = "$want" ] || fail "$t is out of date or was edited by hand; run blueprint/scripts/skills.sh"
  done
else
  for t in $targets; do
    rm -rf "${root:?}/$t"
    if [ -n "$any" ]; then mkdir -p "$root/$t"; cp -pR "$tmp/out/." "$root/$t/"; fi
  done
fi
