# Developing the base

This repository is where the base is developed and published. It is also the template every copy starts from, so it is a copy with no notes: the content folders hold only their `README.md`, and `custom/` only its examples. Keep it that way; notes belong in a copy.

- **Here `blueprint/` is edited**, but only with what helps any copy. What is for one person goes in that person's `custom/`.
- **Before saying a change to something that runs works** (`blueprint/scripts/`, `blueprint/git-hooks/`), try to break it: a test that fails for the reason it should, each fault the check must stop put in on purpose, and real commits with the git hooks, a clean clone, `install.sh` in a new copy and `update.sh` from the previous version, rehearsed in throwaway copies. A change to text only needs the check.
- **Commits are public.** Conventional Commits in English, with nothing personal in them, signed with an address that is not private.
- **To publish a version:** set `blueprint/VERSION` to it, commit, tag it with the same name (`git tag v0.2`) and push the branch and the tag. `update.sh` refuses a tag whose `VERSION` says otherwise. The template gives new copies the main branch as it is, so only what passed the check goes there.
- **Contributions are not accepted**, so issues stay off.
