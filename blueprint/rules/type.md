## Type

Every note in the content folders (all of them except `blueprint/` and `custom/`) carries `type` and `created` (`YYYY-MM-DD`) in its frontmatter, and the check fails if either is missing or the type is not one its folder allows. Nothing else until a real query needs it, and no tags: they are mostly topics, which are a matter of opinion, so links group notes instead. Generated files such as `AGENTS.md` and the skill copies are not notes.

- `index`: the `README.md` that presents a folder.
- In `projects/`: `project` has a finish line (a talk, a launch); `area` is maintained with no end (a job, a brand). Things move from one to the other, so this is a property, not a folder. Notes inside a project take its type.
- In `knowledge/`: `knowledge` is what you understood about a subject; `model` holds across subjects, and there are few of them.
- Elsewhere, the folder's kind: `inbox`, `goal`, `source`, `journal`. Notes in `encrypted/` take the type they would have outside it.

Tasks are `- [ ]` items in their project's `README.md`. The journal links to them and never copies them.
