# blueprint

The shared base of a plain-text notes system for one person and their agents: Markdown files in git, readable by any agent and any viewer. Everything here is common to every copy and stays in English; each owner writes their own notes and changes in whatever language they like.

## Principles

- AI first: built for agents to work on from the start, not an existing system with AI added on top.
- Decoupled: the data are open files the owner keeps, and so is what agents learn, which never stays inside an agent; the viewer, the model and the agent can each be replaced without touching them.

## What's inside

- `rules/`: one file per rule, plus `ORDER`, the order in which they appear.
- `scripts/rules.sh`: builds `AGENTS.md` at the repository root from these rules and the owner's changes in `custom/`. With `--check`, it fails if `AGENTS.md` is out of date or was edited by hand.
- `skills/`: common skills, one folder each with its `SKILL.md`, in the Agent Skills format.
- `scripts/skills.sh`: copies the base skills and the owner's in `custom/skills/` to `.agents/skills/` (Codex, OpenCode) and `.claude/skills/` (Claude Code), where agents look for them. With `--check`, it fails if the copies are out of date or were edited by hand.
- `scripts/install.sh`: sets up a repository around `blueprint/`, and repairs one. It creates what is missing and never overwrites what exists: the content folders with their `README.md`, a `README.md`, a `CLAUDE.md` and a `GEMINI.md` at the root, `custom/README.md` and `custom/disable` with examples that change nothing, the lines `.gitignore` and `.gitattributes` need, `AGENTS.md` and the skill copies, `core.hooksPath` and, once you have run `git-crypt init`, the git-crypt lines for `encrypted/`; then it runs `check.sh`. Running it again changes nothing. Only the git-crypt key is left to you.
- `scripts/check.sh`: runs every check. It fails if the tests fail, if `AGENTS.md` or the skill copies are out of date, if `custom/` holds something the base would ignore, if the git hooks are off, if scripts lack `eol=lf`, if a note lacks `type` and `created` or carries a type its folder does not allow, if a relative link points to nothing, if a secret file is tracked (any letter case, anywhere), or if anything in `encrypted/` is not set and stored as git-crypt ciphertext. With `--staged`, as the git hooks run it, it checks exactly what the next commit will contain rather than the files on disk, and runs the tests only if the commit touches the scripts, the git hooks or `.gitattributes`; the guards run on every commit. Run it by hand to run every test.
- `scripts/test-rules.sh`, `scripts/test-skills.sh`, `scripts/test-check.sh` and `scripts/test-install.sh`: prove, in throwaway copies, that the scripts above do what they promise and stop every mistake they claim to stop, each for the right reason. `check.sh` runs all four.
- `git-hooks/pre-commit` and `git-hooks/pre-merge-commit`: run `check.sh --staged` before each commit and each merge commit, and stop it if anything fails.
- `git-hooks/commit-msg`: runs `custom/git-hooks/commit-msg`, if the owner has one, so they can reject commit messages, for example ones with trailers they do not want.
- `git-hooks/post-commit`, `git-hooks/post-merge` and `git-hooks/post-rewrite`: run `check.sh --warn` after operations git gives no blocking hook for, and print a warning with how to undo them.

It needs only POSIX `sh` and git. On Windows, run it from Git Bash (installed with Git for Windows) or WSL; it is not tested there yet. It also works without git, with less: see below.

## Install

1. Copy `blueprint/` into a folder and run `git init` there (optional, but without git there are no git hooks and no encryption; see Without git). If the folder already has an `AGENTS.md`, move its content to `custom/rules/my-*.md` first, because the next step overwrites it.
2. Run `sh blueprint/scripts/install.sh`. It creates what is missing, never overwrites what exists, and ends with the check. Run it again on every machine after cloning, because the git hooks setting is not cloned, and after each update.
3. To change rules or skills, see `custom/README.md`, which `install.sh` creates with an example, and Customize without editing below.
4. Optional, for `encrypted/`: run `git-crypt init`, keep the key outside the repository, and run `install.sh` again; it sets git-crypt for `encrypted/` in `.gitattributes`.

The rules end up in `AGENTS.md`, the file most agents (Codex, OpenCode and others) load by themselves at the start of a session, so every rule reaches them without depending on the agent choosing to read another file. Claude Code and Gemini CLI read their own file instead; the `CLAUDE.md` and `GEMINI.md` that `install.sh` creates only import `AGENTS.md`. Keep the rules short: Codex reads only the first 32 KiB by default.

## Customize without editing

Never edit `blueprint/` in your copy: the next update would overwrite it. Put changes in `custom/` instead. Today rules, skills and the commit message can be customized:

- **Replace:** a file in `custom/rules/` with the same name as a base rule replaces it. `custom/rules/links.md` replaces `blueprint/rules/links.md`.
- **Add:** your own rules are files named `my-*.md` in `custom/rules/`. They go after the base rules.
- **Disable:** one line `rules/<name>` per rule in `custom/disable` leaves that rule out of `AGENTS.md`. The file in `blueprint/` stays untouched, so an update cannot bring the rule back.
- **Skills:** the same three moves in `custom/skills/`: a folder with the name of a base skill replaces it, your own are named `my-*`, and a line `skills/<name>` in `custom/disable` leaves one out, untouched in `blueprint/`. Each needs a `SKILL.md` with `name` (the folder name) and `description` in its frontmatter.
- **Commit messages:** `custom/git-hooks/commit-msg` gets the message file as its argument and rejects the commit by exiting with an error. It runs with `sh`, so it needs no executable bit.
- **Tests for your git hooks:** any `custom/git-hooks/test-*.sh` runs with the other tests before each commit.

Run `sh blueprint/scripts/rules.sh` and `sh blueprint/scripts/skills.sh` after each change. The check fails if a custom file or a `disable` line points to a rule that does not exist, or if `custom/` holds anything the base would not read (a misspelled name, a wrong extension), so a typo or a rule renamed upstream never goes unnoticed. Folder names cannot be changed, and scripts are not replaced.

## What the git hooks cannot stop

The checks are local and git decides when its hooks run, so some ways in are not blocked:

- `git commit --no-verify` skips the blocking git hooks on purpose.
- cherry-pick, rebase and fast-forward merges have no blocking hook; the post-* git hooks warn right after, with how to undo.
- Commits made with plumbing (`git commit-tree`), branches fetched from elsewhere, and clones where `core.hooksPath` was never set.
- The encryption check sees that a file starts like git-crypt ciphertext and that git-crypt is set for it; it cannot tell real ciphertext from a forged header.

Run `sh blueprint/scripts/check.sh` after any of these. For a guarantee that does not depend on each machine, run it in CI on every push.

## Update

Because `blueprint/` is never edited in a copy, updating means replacing the whole folder with a newer version, then running `sh blueprint/scripts/install.sh`, which adds anything new the base needs and ends with the check. Versions will be git tags, with a changelog that marks breaking changes: a renamed rule, folder or property.

## Without git

The notes, rules and `custom/` work in any synced folder (iCloud, Dropbox, a USB stick), but you lose what git provides:

- There is no hook, so nothing runs the checks for you. Run `sh blueprint/scripts/rules.sh` and `sh blueprint/scripts/skills.sh` after each change and `sh blueprint/scripts/check.sh` now and then; without git it checks what it can and says what it skipped.
- `encrypted/` is not encrypted: git-crypt only works with git. Keep sensitive material out, or use storage with end-to-end encryption.
- There is no history to recover from, beyond what the sync service keeps.

Do not put a git repository inside iCloud or a similar service: they sync the internals of `.git` piecemeal and can corrupt it. Use one or the other.
