## Type

Every note in the content folders (all of them except `blueprint/` and `custom/`) carries `type` and `created` (`YYYY-MM-DD`) in its frontmatter, and the check fails if either is missing or the type is not one its folder allows. Nothing else until a real query needs it, and no tags: they are mostly topics, which are a matter of opinion, so links group notes instead. Generated files such as `AGENTS.md` and the skill copies are not notes.

- `index`: the `README.md` that presents a folder.
- In `projects/`: `project` has a finish line (a talk, a launch); `area` is maintained with no end (a job, a brand). Things move from one to the other, so this is a property, not a folder. Notes inside a project take its type.
- In `knowledge/`: `knowledge` is an idea you understood. `model` holds across subjects, and there are few of them. `reading` is your reading of one source, named after its title, whether a file or a folder of several (a course): what it says, in a few lines of your own, how far you trust it and why, and links to the notes that came from it.
- Elsewhere, the folder's kind: `inbox`, `goal`, `source`, `journal`. Notes in `encrypted/` take the type they would have outside it, and notes in `archive/` the type they had before.

A `knowledge` or `model` note holds one idea, in the owner's words, titled by that idea and not by where it came from, and linked to the notes it relates to, which is where its value is. Its source, if any, is one line at the end, so the idea can be traced. What the owner thinks of the source goes in its `reading` note, not here. One source may give several notes, each with that line.

Notes in `goals/`, `projects/` and `knowledge/` are named in lowercase words joined by hyphens, after their title or idea (`the-ai-is-killing-online-courses.md`), and those in `knowledge/` carry no date, since an idea does not have one. The check fails otherwise. `README.md` is the exception, and the other folders keep the names they come with: a source as it came, a journal day by its date.

Tasks are `- [ ]` items in their project's `README.md`. The journal links to them and never copies them. When work changes a project, update its README.md in the same change: tick what is done, add what came up, and fix what is no longer true. Ticked tasks may be deleted once they no longer help; git keeps them.
