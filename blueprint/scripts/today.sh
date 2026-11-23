#!/bin/sh
# Creates today's journal note, journal/YYYY/YYYY-MM-DD.md, from the journal template, unless it
# already exists, and prints its path. The template is custom/templates/journal.md if the owner
# has one, otherwise blueprint/templates/journal.md; {{date:YYYY-MM-DD}} in it becomes the day,
# the same placeholder Obsidian's daily notes fill in. It needs no viewer, so any agent or a
# terminal can use it.
#   today.sh         create it if missing and print the path
#   today.sh --open  also open it with the system's default app for Markdown
set -u
export LC_ALL=C

root=$(cd "$(dirname "$0")/../.." && pwd -P)
case ${1:-} in ('' | --open) ;; (*) echo "today: unknown option $1" >&2; exit 2 ;; esac
day=${HITO_TODAY:-$(date +%Y-%m-%d)}  # HITO_TODAY lets the tests pick the day
case $day in
  ([0-9][0-9][0-9][0-9]-[0-1][0-9]-[0-3][0-9]) ;;
  (*) echo "today: '$day' is not a date as YYYY-MM-DD" >&2; exit 2 ;;
esac
template="$root/custom/templates/journal.md"
[ -f "$template" ] || template="$root/blueprint/templates/journal.md"
[ -f "$template" ] || { echo "today: there is no journal template in blueprint/templates" >&2; exit 1; }
f="$root/journal/${day%%-*}/$day.md"
if [ ! -e "$f" ]; then
  mkdir -p "${f%/*}" || exit 1
  tr -d '\r' < "$template" | sed "s/{{date:YYYY-MM-DD}}/$day/g" > "$f.tmp" && mv "$f.tmp" "$f" || { rm -f "$f.tmp"; exit 1; }
fi
echo "$f"
if [ "${1:-}" = --open ]; then
  if command -v open > /dev/null 2>&1; then open "$f"
  elif command -v xdg-open > /dev/null 2>&1; then xdg-open "$f"
  else echo "today: no app to open it with; the path is above" >&2; exit 1
  fi
fi
