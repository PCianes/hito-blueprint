#!/bin/sh
# Sets up a repository around blueprint/, and repairs one: run it after copying blueprint/ in,
# after cloning on another machine, and after an update. It never overwrites anything that
# exists: it only adds what is missing, so running it again changes nothing.
#   - the content folders, each with its README.md, plus README.md and CLAUDE.md at the root;
#   - the lines .gitignore and .gitattributes need;
#   - AGENTS.md and the skill copies;
#   - your rules and skills for every folder (custom/global/), taken to each agent by global.sh;
#   - core.hooksPath, so the git hooks run (it is not cloned, so each machine needs it);
#   - the git-crypt lines for encrypted/, once git-crypt init has been run;
# and ends with check.sh. Only the git-crypt key is left to the owner: it is theirs.
#   install.sh        in a terminal, ask before adding a line to a file of yours outside it
#   install.sh --yes  add it without asking
set -u
export LC_ALL=C

case ${1:-} in ('' | --yes) ;; (*) echo "install: unknown option $1" >&2; exit 2 ;; esac
root=$(cd "$(dirname "$0")/../.." && pwd -P)
cd "$root" || exit 1
say() { echo "install: $*"; }
today=$(date +%Y-%m-%d)

# The content folders of Folders in AGENTS.md; test-install.sh fails if this list and that
# rule disagree.
folders="inbox goals projects knowledge sources journal encrypted archive"

# 1. Folders and their README.md, linked from a README.md at the root.
if [ ! -e README.md ]; then
  {
    printf -- '---\ntype: index\ncreated: %s\n---\n\n# Notes\n\nThe rules are in [AGENTS.md](AGENTS.md).\n\n## Folders\n\n' "$today"
    for d in $folders; do printf -- '- [%s/](%s/README.md)\n' "$d" "$d"; done
  } > README.md
  say "created README.md"
fi
for d in $folders; do
  [ -e "$d/README.md" ] && continue
  mkdir -p "$d"
  printf -- '---\ntype: index\ncreated: %s\n---\n\n# %s\n\nWhat goes here and who writes: [AGENTS.md](../AGENTS.md).\n\nBack to the [start](../README.md).\n' "$today" "$d" > "$d/README.md"
  say "created $d/README.md"
done
# custom/ explains itself with examples that change nothing: a README.md, which never reaches
# AGENTS.md, and a disable file whose example lines are commented out.
mkdir -p custom
if [ ! -e custom/README.md ]; then
  cat > custom/README.md << 'EOF'
# custom

Your changes to the shared base ([blueprint/](../blueprint/README.md)), without editing it.

- `rules/`: a file with the same name as a base rule replaces it; files named `my-*.md` are your own rules and go at the end.
- `skills/`: your skills, one folder each with its `SKILL.md`; one with the name of a base skill replaces it, and yours are named `my-*`.
- `disable`: one line `rules/<name>` or `skills/<name>` for each base rule or skill to leave out.
- `global/rules/` and `global/skills/`: your own rules (`my-*.md`) and skills (`my-*`) for every folder, not only this repository. They reach each agent wherever it works, through `GLOBAL.md` and copies outside the repository.

For example, to be answered in your language, save this as `rules/my-language.md`:

```markdown
## Language

Answer me in Spanish.
```

After any change, run `sh blueprint/scripts/install.sh`: it regenerates [AGENTS.md](../AGENTS.md), `GLOBAL.md` and the copies, and runs the check.
EOF
  say "created custom/README.md"
fi
if [ ! -e custom/disable ]; then
  cat > custom/disable << 'EOF'
# Base rules and skills to leave out, one per line: rules/<name> or skills/<name>.
# The file stays in blueprint/, untouched, but no longer reaches the agents, and an
# update cannot bring it back. Lines starting with # are ignored. For example:
# rules/links
# skills/<name>
EOF
  say "created custom/disable"
fi
# Most agents (Codex, OpenCode, Cursor, Copilot, Windsurf, Hermes) read AGENTS.md by themselves;
# Claude Code and Gemini CLI read their own file, which here only imports it.
if [ ! -e CLAUDE.md ]; then
  printf '# Claude Code\n\nClaude Code does not read `AGENTS.md` by itself, so this file imports it.\n\n@AGENTS.md\n' > CLAUDE.md
  say "created CLAUDE.md"
fi
if [ ! -e GEMINI.md ]; then
  printf '# Gemini CLI\n\nGemini CLI does not read `AGENTS.md` by itself, so this file imports it.\n\n@./AGENTS.md\n' > GEMINI.md
  say "created GEMINI.md"
fi

# 2. Secret files stay out of git.
touch .gitignore
for p in .env '*.env' '.env.*' '*.key' '*.pem'; do
  grep -qxF "$p" .gitignore || { printf '%s\n' "$p" >> .gitignore; say "added $p to .gitignore"; }
done

# 3. Unix line endings for all text. The line goes first, because a later "* text" line
#    would override what follows it, such as the -text that git-crypt needs.
touch .gitattributes
if ! grep -qxF '* text=auto eol=lf' .gitattributes; then
  { echo '* text=auto eol=lf'; cat .gitattributes; } > .gitattributes.tmp && mv .gitattributes.tmp .gitattributes
  say "added * text=auto eol=lf to .gitattributes"
fi
# Diffs show each generated skill copy as one line; the check keeps them equal to the original.
for p in '.agents/skills/** -diff' '.claude/skills/** -diff'; do
  grep -qxF "$p" .gitattributes || { printf '%s\n' "$p" >> .gitattributes; say "added $p to .gitattributes"; }
done

# 4. AGENTS.md and the skill copies, and the rules and skills for every folder taken to each agent.
sh blueprint/scripts/rules.sh || exit 1
sh blueprint/scripts/skills.sh || exit 1
sh blueprint/scripts/global.sh "$@" || exit 1

# 5. The git hooks, if this is the top of a git repository.
if command -v git > /dev/null 2>&1 && [ "$(git rev-parse --show-toplevel 2> /dev/null)" = "$root" ]; then
  if [ "$(git config core.hooksPath)" != blueprint/git-hooks ]; then
    git config core.hooksPath blueprint/git-hooks
    say "turned the git hooks on"
  fi
  # encrypted/ is encrypted once the owner has run git-crypt init (the key is theirs). Before
  # that these lines would break git add in encrypted/, so they wait for it.
  if [ -d "$(git rev-parse --git-dir)/git-crypt/keys" ]; then
    for p in 'encrypted/** filter=git-crypt diff=git-crypt -text' 'encrypted/README.md !filter !diff text' '.gitattributes !filter !diff'; do
      grep -qxF "$p" .gitattributes || { printf '%s\n' "$p" >> .gitattributes; say "added $p to .gitattributes"; }
    done
  fi
else
  say "not the top of a git repository: no git hooks (run git init here and this script again)"
fi

# 6. Everything else is checked.
sh blueprint/scripts/check.sh
