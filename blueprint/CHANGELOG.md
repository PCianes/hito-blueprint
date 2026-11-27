# Changelog

What changes in each version of the base, newest first. `update.sh` shows the versions after yours. **Breaking** marks a change that asks you to do something after updating, such as a renamed rule, folder or property; until v1.0 there may be some.

## Unreleased

- Notes in `goals/`, `projects/` and `knowledge/` are named in lowercase words joined by hyphens, and those in `knowledge/` with no date. The check fails otherwise. A `reading` is named after the title of its source, not after its file name.
- A `knowledge` note is titled by its idea as a claim that reads on its own, with the context that makes it true, so it can be found without knowing where it came from.

## v0.3

- Works on Windows, in Git Bash: every test of the base and the rehearsal pass there. Where Windows cannot do something, its tests say so and skip it: files carry no executable bit, and git refuses a file name with a double quote, so neither can ever be committed there.
- A rule: whatever goes into `sources/` comes, in the same change, with its `reading` note and its `knowledge/` notes, or a task to write them, one for each source. Otherwise it is only stored, and never used.
- A new note type in `knowledge/`, `reading`: your reading of one source (what it says, how far you trust it, the notes that came from it). The rules also say what a `knowledge` note is: one idea in your words, titled by the idea, with its source as a one-line reference.
- The check no longer follows links inside `sources/`, except in each `README.md`: the rest is others' material, kept as it came, so its broken links are not yours to fix.
- `raw/`, for others' material too bulky to judge at once or to keep in git. It stays out of git (`install.sh` adds it to `.gitignore`, and the check stops it from being committed), and each item leaves kept whole in `sources/`, distilled into a `reading` note, or deleted. The rules also tell a source worth keeping whole from bulk material, which is only distilled.

## v0.2

- A copy no longer runs the tests of the base, which were run before the version was published: installing, updating and committing an update take seconds instead of minutes. Tests of your own in `custom/git-hooks/` still run.
- The check stops any edit to `blueprint/` in a copy, because the next update would lose it: `blueprint/MANIFEST` holds the fingerprint of every file of the version. Your changes go in `custom/`. Where the base is developed, `git config hito.develop true` allows editing it.
- Where the base is developed, a commit is stopped if it adds Spanish to Markdown, to a file name or to its message, a path into a home folder, or a personal email address, so nothing personal reaches the public base.
- `update.sh` shows what changed since your version, from this file.
- The check tells whether it is at the top of the repository by asking git, not by comparing paths. On Windows the two paths are written differently, so the check believed there was no git and skipped, without failing, every check that needs it: the git hooks, secrets, encryption and the fingerprint. Windows is still not tested.

## v0.1

- First published version.
