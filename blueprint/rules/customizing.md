## Customizing

`blueprint/` is shared by every copy. Improvements that would help every copy are made in the base itself, where it is developed. Changes for one person never go in `blueprint/`; they go in `custom/`:

- a file in `custom/rules/` with the same name as a base rule replaces it (`custom/rules/links.md` replaces `blueprint/rules/links.md`);
- your own rules are files named `my-*.md` in `custom/rules/`;
- to leave a base rule out, add a line `rules/<name>` to `custom/disable`: the rule stays in `blueprint/`, untouched, but no longer reaches `AGENTS.md`, and updates cannot bring it back.

Besides rules, `custom/skills/` holds the owner's skills (see Skills), `custom/git-hooks/commit-msg`, if present, is run with the commit message and can reject it, and `custom/git-hooks/test-*.sh` run with the other tests. Anything else in `custom/` makes the check fail. `AGENTS.md` is generated from both by `blueprint/scripts/rules.sh`. Never edit it by hand.
