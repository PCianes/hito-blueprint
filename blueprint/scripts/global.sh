#!/bin/sh
# Takes the owner's rules and skills for every folder (custom/global/) to where each agent reads
# them outside the repository, so they hold in any folder, not only here:
#   - Claude Code (~/.claude/CLAUDE.md) and Gemini CLI (~/.gemini/GEMINI.md) import GLOBAL.md
#     with one line, so a change reaches them with nothing to rerun;
#   - Codex (~/.codex/AGENTS.md) and OpenCode (~/.config/opencode/AGENTS.md) cannot import, so
#     they get a copy;
#   - skills are copied to ~/.claude/skills (Claude Code) and ~/.agents/skills (Codex, OpenCode).
# Only for agents whose folder exists. Every line, copy and skill names the file or folder it
# came from, and this script only changes what came from this repository or from one that no
# longer exists (it was moved). A file of the owner's is never changed without asking: the line
# is added to it only with a yes, and the rest is reported. With no rules or skills for every
# folder left, it removes what it put there. install.sh runs it, and so do the git hooks after
# each commit, merge and rewrite.
#   global.sh           in a terminal, ask before adding the line to a file the owner has
#   global.sh --yes     add it without asking
#   global.sh --no-ask  never add it, only report (the git hooks)
set -u
export LC_ALL=C

root=$(cd "$(dirname "$0")/../.." && pwd -P)
mode=${1:-}
case $mode in ('' | --yes | --no-ask) ;; (*) echo "global: unknown option $mode" >&2; exit 2 ;; esac
home=${HOME:?HOME is not set}
gfile="$root/GLOBAL.md"
gskills="$root/custom/global/skills"
say() { echo "global: $*"; }
rules=no
[ -f "$gfile" ] && rules=yes
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# 1. Agents that import: one line, @ and the full path of a GLOBAL.md.
line="@$gfile"
import() { # agent folder, file name, agent
  [ -d "$1" ] || return 0
  f="$1/$2"
  moved=no
  if [ -f "$f" ]; then
    # Lines that point to a GLOBAL.md that is gone (moved, or no rules left) are dropped.
    grep -x '@/.*/GLOBAL\.md' "$f" | while IFS= read -r l; do [ -e "${l#@}" ] || echo "$l"; done > "$tmp/dead"
    if [ -s "$tmp/dead" ]; then
      grep -vxF -f "$tmp/dead" "$f" |
        awk '{ l[NR] = $0 } END { n = NR; while (n > 0 && l[n] ~ /^[[:space:]]*$/) n--; for (i = 1; i <= n; i++) print l[i] }' > "$tmp/kept"
      if grep -q '[^[:space:]]' "$tmp/kept"; then cat "$tmp/kept" > "$f"; else rm -f "$f"; fi
      moved=yes
      [ "$rules" = yes ] || say "removed from $f the line that loaded GLOBAL.md"
    fi
  fi
  [ "$rules" = yes ] || return 0
  if [ ! -e "$f" ]; then
    printf '%s\n' "$line" > "$f"
    say "$3 loads your rules for every folder: $f imports GLOBAL.md"
    return 0
  fi
  grep -qxF "$line" "$f" && return 0
  other=$(grep -x '@/.*/GLOBAL\.md' "$f" | head -n 1)
  if [ -n "$other" ]; then
    say "$f already loads another GLOBAL.md ($other); not changed"
    return 0
  fi
  answer=n
  if [ "$mode" = --yes ] || [ "$moved" = yes ]; then  # replacing its own line asks nothing
    answer=y
  elif [ -z "$mode" ] && [ -t 0 ]; then
    printf 'global: add the line %s at the end of %s, so %s loads your rules for every folder? [y/N] ' "$line" "$f" "$3"
    read -r answer || answer=n
  fi
  case $answer in
    (y | Y | yes | s | S | si | sí)
      [ -s "$f" ] && [ -n "$(tail -c 1 "$f")" ] && echo >> "$f"
      printf '\n%s\n' "$line" >> "$f"
      say "$3 loads your rules for every folder: added the import of GLOBAL.md to $f" ;;
    (*) say "$3 does not load your rules for every folder; add this line at the end of $f: $line" ;;
  esac
}
import "${CLAUDE_CONFIG_DIR:-$home/.claude}" CLAUDE.md "Claude Code"
import "$home/.gemini" GEMINI.md "Gemini CLI"

# 2. Agents that cannot import: a copy whose first line names the GLOBAL.md it came from.
mark="<!-- Copied by hito from $gfile; do not edit by hand. -->"
copy() { # agent folder, agent
  [ -d "$1" ] || return 0
  f="$1/AGENTS.md"
  if [ -e "$f" ]; then
    src=$(sed -n '1s/^<!-- Copied by hito from \(.*\); do not edit by hand\. -->$/\1/p' "$f")
    if [ -z "$src" ]; then
      [ "$rules" = no ] || say "$f is yours, so it was not changed: $2 does not get your rules for every folder"
      return 0
    fi
    if [ "$src" != "$gfile" ] && [ -e "$src" ]; then
      [ "$rules" = no ] || say "$f is a copy from another repository ($src); not changed"
      return 0
    fi
  fi
  if [ "$rules" = yes ]; then
    { echo "$mark"; echo; cat "$gfile"; } > "$tmp/copy"
    cmp -s "$tmp/copy" "$f" 2> /dev/null && return 0
    cat "$tmp/copy" > "$f"
    say "$2 gets your rules for every folder: copied GLOBAL.md to $f"
  elif [ -e "$f" ]; then
    rm -f "$f"
    say "removed $f: there are no rules for every folder"
  fi
}
codex=${CODEX_HOME:-$home/.codex}
opencode=${XDG_CONFIG_HOME:-$home/.config}/opencode
copy "$codex" Codex
copy "$opencode" OpenCode

# 3. Skills: a copy of each folder, with a file .hito-copy that names the folder it came from.
listing() { (cd "$1" && find . -type f ! -name .hito-copy ! -name .DS_Store | sort | while IFS= read -r f; do
  if [ -x "$f" ]; then x=x; else x=-; fi
  printf '%s %s %s\n' "$x" "$(cksum < "$f" | awk '{ print $1, $2 }')" "$f"
done); }
source_of() { sed -n '1s/^Copied by hito from \(.*\); do not edit by hand\.$/\1/p' "$1/.hito-copy" 2> /dev/null; }
skills() { # skills folder
  t=$1
  for s in "$gskills"/*; do
    [ -d "$s" ] || continue
    n=${s##*/}; d="$t/$n"
    if [ -e "$d" ]; then
      src=$(source_of "$d")
      if [ -z "$src" ]; then say "$d is yours, so it was not changed: your skill $n does not reach it"; continue; fi
      if [ "$src" != "$s" ] && [ -e "$src" ]; then say "$d is a copy from another repository ($src); not changed"; continue; fi
      [ "$(listing "$s")" = "$(listing "$d")" ] && [ "$src" = "$s" ] && continue
      rm -rf "$d"
    fi
    mkdir -p "$t"
    cp -pR "$s" "$d"
    find "$d" -name .DS_Store -exec rm -f {} +
    echo "Copied by hito from $s; do not edit by hand." > "$d/.hito-copy"
    say "copied your skill $n to $t"
  done
  # Copies whose source is gone (removed, or its repository moved) are removed.
  for d in "$t"/*; do
    [ -d "$d" ] || continue
    src=$(source_of "$d")
    [ -n "$src" ] && [ ! -d "$src" ] || continue
    rm -rf "$d"
    say "removed the skill ${d##*/} from $t: it is no longer in custom/global/skills"
  done
}
[ -d "${CLAUDE_CONFIG_DIR:-$home/.claude}" ] && skills "${CLAUDE_CONFIG_DIR:-$home/.claude}/skills"
if [ -d "$codex" ] || [ -d "$opencode" ]; then skills "$home/.agents/skills"; fi
exit 0
