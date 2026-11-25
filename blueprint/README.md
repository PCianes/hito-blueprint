# blueprint

The shared base of a plain-text notes system for one person and their agents: Markdown files in git, readable by any agent and any viewer. Everything here is common to every copy and stays in English; each owner writes their own notes and changes in whatever language they like.

## Principles

- AI first: built for agents to work on from the start, not an existing system with AI added on top.
- Decoupled: the data are open files the owner keeps, and so is what agents learn, which never stays inside an agent; the viewer, the model and the agent can each be replaced without touching them.

## What's inside

- `rules/`: one file per rule, plus `ORDER`, the order in which they appear.
- `scripts/rules.sh`: builds `AGENTS.md` at the repository root from these rules and the owner's changes in `custom/`, and `GLOBAL.md` from the owner's rules for every folder in `custom/global/rules/`, which also go at the end of `AGENTS.md` so they hold in the repository wherever it is opened. With `--check`, it fails if either is out of date or was edited by hand.
- `skills/`: common skills, one folder each with its `SKILL.md`, in the Agent Skills format.
- `scripts/skills.sh`: copies the base skills and the owner's in `custom/skills/` to `.agents/skills/` (Codex, OpenCode) and `.claude/skills/` (Claude Code), where agents look for them. With `--check`, it fails if the copies are out of date or were edited by hand. It also checks the owner's skills for every folder in `custom/global/skills/`, which it does not copy here.
- `scripts/global.sh`: takes the owner's rules and skills for every folder to where each installed agent reads them outside the repository, so they hold in any folder. Claude Code (`~/.claude/CLAUDE.md`) and Gemini CLI (`~/.gemini/GEMINI.md`) get one line that imports `GLOBAL.md`, so a change reaches them at once; Codex (`~/.codex/AGENTS.md`) and OpenCode (`~/.config/opencode/AGENTS.md`), which cannot import, get a copy; skills are copied to `~/.claude/skills/` and `~/.agents/skills/`. Each line, copy and skill names where it came from, so it changes only what came from this repository (or from one that was moved), and never a file of yours: it asks before adding the line to one, and reports the rest. With nothing for every folder left, it removes what it put there.
- `templates/`: templates for new notes. `journal.md` is the one for each day; `{{date:YYYY-MM-DD}}` in it becomes the date, the placeholder Obsidian's daily notes also fill in, so Obsidian can use the same file.
- `scripts/today.sh`: creates today's journal note, `journal/YYYY/YYYY-MM-DD.md`, from the journal template, unless it exists, and prints its path; with `--open`, it also opens it with the system's default app for Markdown. It needs no viewer, so any agent or a terminal can use it. To open it from any folder, an alias in your shell's startup file helps, for example `alias today='sh ~/notes/blueprint/scripts/today.sh --open'` in `~/.zshrc`; an agent can add it for you.
- `scripts/update.sh`: replaces `blueprint/` with a published version of the base, the latest or the one given, runs `install.sh` and shows what changed since your version (see Update). `VERSION` says which version this is, `CHANGELOG.md` what each version changed, and `MANIFEST` holds the fingerprint of every file of the version, so the check can tell if a copy edited `blueprint/`.
- `scripts/install.sh`: sets up a repository around `blueprint/`, and repairs one. It creates what is missing and never overwrites what exists: the content folders with their `README.md`, a `README.md`, a `CLAUDE.md` and a `GEMINI.md` at the root, `custom/README.md` and `custom/disable` with examples that change nothing, the lines `.gitignore` and `.gitattributes` need, `AGENTS.md`, `GLOBAL.md` and the copies, the rules and skills for every folder taken to each agent (with `--yes`, without asking before adding the line to a file of yours), `core.hooksPath` and, once you have run `git-crypt init`, the git-crypt lines for `encrypted/`; then it runs `check.sh`. Running it again changes nothing. Only the git-crypt key is left to you.
- `scripts/check.sh`: runs every check. It fails if `blueprint/` does not match its `MANIFEST`, that is, if a copy edited the base, which the next update would undo (where the base is developed, `git config hito.develop true` says so, and only there does `check.sh --manifest > blueprint/MANIFEST` write the fingerprint, which every commit must keep current); if the tests fail, if `AGENTS.md` or the skill copies are out of date, if `custom/` holds something the base would ignore, if the git hooks are off, if scripts lack `eol=lf`, if a note lacks `type` and `created` or carries a type its folder does not allow, if a relative link points to nothing, if a secret file is tracked (any letter case, anywhere), or if anything in `encrypted/` is not set and stored as git-crypt ciphertext. With `--staged`, as the git hooks run it, it checks exactly what the next commit will contain rather than the files on disk, and runs the tests only if the commit touches the scripts, the git hooks or `.gitattributes`; the guards run on every commit. Run it by hand to run every test. A copy runs only its owner's tests, in `custom/git-hooks/`: the tests of the base ran before the version was published, so a copy checks itself in seconds. Where the base is developed, which is public, a commit is also stopped if it adds Spanish to Markdown, to a file name or to its message, a path into a home folder, or a personal email address.
- `scripts/test-rules.sh`, `scripts/test-skills.sh`, `scripts/test-global.sh`, `scripts/test-today.sh`, `scripts/test-update.sh`, `scripts/test-check.sh` and `scripts/test-install.sh`: prove, in throwaway copies and a throwaway home, that the scripts above do what they promise and stop every mistake they claim to stop, each for the right reason. `check.sh` runs all seven.
- `git-hooks/pre-commit` and `git-hooks/pre-merge-commit`: run `check.sh --staged` before each commit and each merge commit, and stop it if anything fails.
- `git-hooks/commit-msg`: runs `custom/git-hooks/commit-msg`, if the owner has one, so they can reject commit messages, for example ones with trailers they do not want.
- `git-hooks/post-commit`, `git-hooks/post-merge` and `git-hooks/post-rewrite`: run `global.sh --no-ask`, so the copies outside the repository follow what was just committed, and `check.sh --warn` after operations git gives no blocking hook for, printing a warning with how to undo them.

It needs only POSIX `sh` and git. On Windows, run it from Git Bash (installed with Git for Windows) or WSL. It also works without git, with less: see below.

## Install

1. Create your repository from the template, `hito-blueprint` on GitHub ("Use this template", and make it private), and clone it; or, with the GitHub CLI, `gh repo create my-notes --template PCianes/hito-blueprint --private --clone`. It starts with everything `install.sh` creates, and no link to the template. Without a GitHub account, download a version (a tag's zip on GitHub) and copy its `blueprint/` into a folder and run `git init` there (optional, but without git there are no git hooks and no encryption; see Without git). If the folder already has an `AGENTS.md`, move its content to `custom/rules/my-*.md` first, because the next step overwrites it.
2. Run `sh blueprint/scripts/install.sh`. It creates what is missing, never overwrites what exists, and ends with the check. Run it again on every machine after cloning, because the git hooks setting is not cloned, and after each update.
3. To change rules or skills, see `custom/README.md`, which `install.sh` creates with an example, and Customize without editing below.
4. Optional, for `encrypted/`: run `git-crypt init`, keep the key outside the repository, and run `install.sh` again; it sets git-crypt for `encrypted/` in `.gitattributes`.

The rules end up in `AGENTS.md`, the file most agents (Codex, OpenCode and others) load by themselves at the start of a session, so every rule reaches them without depending on the agent choosing to read another file. Claude Code and Gemini CLI read their own file instead; the `CLAUDE.md` and `GEMINI.md` that `install.sh` creates only import `AGENTS.md`. Keep the rules short: Codex reads only the first 32 KiB by default.

## Customize without editing

Never edit `blueprint/` in your copy: the next update would overwrite it. Put changes in `custom/` instead. Today rules, skills and the commit message can be customized:

- **Replace:** a file in `custom/rules/` with the same name as a base rule replaces it. `custom/rules/links.md` replaces `blueprint/rules/links.md`.
- **Add:** your own rules are files named `my-*.md` in `custom/rules/`. They go after the base rules.
- **Disable:** one line `rules/<name>` per rule in `custom/disable` leaves that rule out of `AGENTS.md`. The file in `blueprint/` stays untouched, so an update cannot bring the rule back.
- **Every folder:** rules (`my-*.md`) in `custom/global/rules/` and skills (`my-*`) in `custom/global/skills/` hold wherever an agent works, not only in this repository: they go in `GLOBAL.md`, which `global.sh` takes to each agent, and at the end of `AGENTS.md`. Put there only what does not speak of this repository.
- **Skills:** the same three moves in `custom/skills/`: a folder with the name of a base skill replaces it, your own are named `my-*`, and a line `skills/<name>` in `custom/disable` leaves one out, untouched in `blueprint/`. Each needs a `SKILL.md` with `name` (the folder name) and `description` in its frontmatter.
- **Templates:** a file in `custom/templates/` with the name of a base template replaces it. `custom/templates/journal.md` changes what each day's note starts with.
- **Commit messages:** `custom/git-hooks/commit-msg` gets the message file as its argument and rejects the commit by exiting with an error. It runs with `sh`, so it needs no executable bit.
- **Tests for your git hooks:** any `custom/git-hooks/test-*.sh` runs with the other tests before each commit.

Run `sh blueprint/scripts/install.sh` after each change. The check fails if a custom file or a `disable` line points to a rule that does not exist, or if `custom/` holds anything the base would not read (a misspelled name, a wrong extension), so a typo or a rule renamed upstream never goes unnoticed. Folder names cannot be changed, and scripts are not replaced.

## What the git hooks cannot stop

The checks are local and git decides when its hooks run, so some ways in are not blocked:

- `git commit --no-verify` skips the blocking git hooks on purpose.
- cherry-pick, rebase and fast-forward merges have no blocking hook; the post-* git hooks warn right after, with how to undo.
- Commits made with plumbing (`git commit-tree`), branches fetched from elsewhere, and clones where `core.hooksPath` was never set.
- The encryption check sees that a file starts like git-crypt ciphertext and that git-crypt is set for it; it cannot tell real ciphertext from a forged header.

Run `sh blueprint/scripts/check.sh` after any of these. For a guarantee that does not depend on each machine, run it in CI on every push.

## Update

Because `blueprint/` is never edited in a copy, updating means replacing the whole folder with a newer version: `sh blueprint/scripts/update.sh` does it with the latest one (or `update.sh v0.3` with that one), then runs `install.sh`, which adds anything new the base needs and ends with the check. Review the result with `git diff` and commit it. It downloads the version into a temporary folder and deletes it afterwards, so your repository never gets a link to the base, and it refuses to run while `blueprint/` has changes not committed. Versions are git tags such as `v0.1`, and `blueprint/VERSION` says which one a copy has. After updating, it shows the sections of `blueprint/CHANGELOG.md` after your version; one marked **Breaking** asks you to do something.

## Without git

The notes, rules and `custom/` work in any synced folder (iCloud, Dropbox, a USB stick), but you lose what git provides:

- There is no hook, so nothing runs the checks for you. Run `sh blueprint/scripts/rules.sh` and `sh blueprint/scripts/skills.sh` after each change and `sh blueprint/scripts/check.sh` now and then; without git it checks what it can and says what it skipped.
- `encrypted/` is not encrypted: git-crypt only works with git. Keep sensitive material out, or use storage with end-to-end encryption.
- There is no history to recover from, beyond what the sync service keeps.

Do not put a git repository inside iCloud or a similar service: they sync the internals of `.git` piecemeal and can corrupt it. Use one or the other.
