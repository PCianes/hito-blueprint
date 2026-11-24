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
