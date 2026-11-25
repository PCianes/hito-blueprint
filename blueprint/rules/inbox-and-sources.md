## Inbox and sources

`inbox/` holds what is waiting for a decision; `sources/` holds others' material already chosen to keep. These are the only folders where agents write without review: bots, dictation and agents drop anything in the inbox, and agents may store others' material whole in `sources/`. Everywhere else they propose. Processing empties the inbox:

- an idea of yours → a note in `knowledge/` or a task in a project;
- something by others worth keeping → `sources/`, and what you take from it in `knowledge/`;
- the rest → deleted.

Not everything others wrote is a source. What is worth keeping whole, because it will be consulted or quoted as it is (a lesson, a book, a skill, a script), goes in `sources/`. Bulk material whose value is only in what it yields (forum posts, chats, a whole channel) does not: it is distilled into a `reading` note, the parts worth keeping whole are kept, and the rest is deleted.

`raw/` is the inbox for others' material: what is captured and not yet judged, or too bulky for git. It stays out of git, and the check fails if anything in it is committed. Each item leaves `raw/` one of three ways: kept whole in `sources/`, distilled into a `reading` note (keeping whole only the parts worth it), or deleted. What you already know you want whole, such as a transcript downloaded on purpose, goes straight to `sources/`. Like sources, what enters `raw/` leaves a task to process it: being out of git, it is easy to forget, and it has no copy on the remote.

Nothing goes into `sources/` on its own: in the same change, write its `reading` note and the `knowledge/` notes with what the owner takes from it, or leave a task to write them, one for each source stored (a course, a video, an article), as a `- [ ]` item in the project it belongs to, or in `inbox/` if it has none, linking to what was stored. A source with neither is only stored, and is never used.
