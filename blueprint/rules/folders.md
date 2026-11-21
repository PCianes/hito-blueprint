## Folders

A folder exists only if (a) deciding whether a note belongs there is a question of fact, or (b) it changes who may write in it. Everything else is told apart with properties, not folders. Folder names are fixed, because rules, scripts and links depend on them; you may add folders of your own if they pass this same test.

| Folder | What goes there | Who writes |
| --- | --- | --- |
| `inbox/` | Anything waiting for a decision | Owner, and anything that captures for them: bots, dictation, agents |
| `goals/` | Vision, focus, values, principles | Owner only; agents read |
| `projects/` | Everything the owner does or maintains, one folder each with its `README.md` | Owner; agents propose |
| `knowledge/` | What the owner knows, in their own words | Owner; agents propose |
| `sources/` | What others say, kept whole | Owner and agents |
| `journal/` | One file per day, `YYYY/YYYY-MM-DD.md`: a folder per year, the full date in the name | Owner; agents propose |
| `encrypted/` | Sensitive material: encrypted on the remote, readable on the owner's machine | Owner; agents propose |
| `blueprint/` | The shared base: rules, skills and scripts | Only where the base is developed; nobody in a copy |
| `custom/` | The owner's changes to the base | Owner; agents propose |
| `.agents/skills/`, `.claude/skills/` | Copies of the skills, generated for each agent | Nobody: `skills.sh` writes them |

Inside each folder the same test applies: a subfolder exists only if placing a note in it is a question of fact, such as a project, the year of a journal day, the author or channel of a source, or one source made of several files. Topics are not facts, so `knowledge/` stays flat; links and each folder's `README.md` organize it.

"Agents propose" means an agent may draft, and the owner decides what stays.
