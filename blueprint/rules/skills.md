## Skills

A skill is a procedure an agent follows: a folder with a `SKILL.md` whose frontmatter has `name` (equal to the folder name) and `description` (when to use it), plus any scripts it needs. Common skills live in `blueprint/skills/`, the owner's in `custom/skills/`: a custom skill with the name of a base one replaces it, the owner's own are named `my-*`, and a line `skills/<name>` in `custom/disable` leaves a base one out, untouched in `blueprint/` but no longer copied for the agents. `blueprint/scripts/skills.sh` copies the result to `.agents/skills/` and `.claude/skills/`, where agents look for them. Never edit those copies.

Write skills for the weakest model that will run them: plain steps, scripts in `sh`, and no tool names of any one agent.
