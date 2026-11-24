# Changelog

What changes in each version of the base, newest first. `update.sh` shows the versions after yours. **Breaking** marks a change that asks you to do something after updating, such as a renamed rule, folder or property; until v1.0 there may be some.

## v0.2

- A copy no longer runs the tests of the base, which were run before the version was published: installing, updating and committing an update take seconds instead of minutes. Tests of your own in `custom/git-hooks/` still run.
- The check stops any edit to `blueprint/` in a copy, because the next update would lose it: `blueprint/MANIFEST` holds the fingerprint of every file of the version. Your changes go in `custom/`. Where the base is developed, `git config hito.develop true` allows editing it.
- Where the base is developed, a commit is stopped if it adds Spanish to Markdown, to a file name or to its message, a path into a home folder, or a personal email address, so nothing personal reaches the public base.
- `update.sh` shows what changed since your version, from this file.

## v0.1

- First published version.
