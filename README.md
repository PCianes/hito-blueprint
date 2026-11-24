---
type: index
created: 2026-11-24
---

# hito-blueprint

The base of hito, a second brain you share with your AI agents: plain Markdown files in a git repository, with the rules that tell any agent how to read and write them.

Most personal knowledge management (PKM) tools keep your notes in their app and add AI on top. hito starts from the other end. Your notes are open files you own, and agents are first-class users of them from day one. Any agent can work on them (Claude Code, Codex, Gemini CLI, OpenCode), and any viewer can open them (Obsidian, VS Code, GitHub). You can change the agent, the model or the viewer and your notes stay the same.

## Why "hito" and "blueprint"

A *hito*, in Spanish, is the stone that marks a mountain path: a cairn. You follow one to the next and never lose the way. A second brain is for the same thing, finding your way through everything you read, think and do, and keeping what matters, not piling up everything.

The blueprint is the plan every copy is built from: the rules, skills, scripts and checks in `blueprint/`, the same for everyone. This repository, `hito-blueprint`, holds that plan and is the template you start from. Your copy is your hito: your notes, built on the blueprint, with your own changes in `custom/`.

## What you get

- **A place for everything, decided by fact.** Fixed folders for the inbox, goals, projects, knowledge, others' sources, a daily journal, encrypted material and an archive (see Folders). A note's folder depends on facts about it, not on your opinion of its topic. Links connect notes; there are no tags.
- **Rules for your agents, in the open.** One `AGENTS.md`, the file most agents read, is generated from short rule files. It says where each note goes, what agents may write without asking (the inbox and sources) and what they only propose. Agents keep no hidden memory: what they learn becomes a rule or a note you can review.
- **Skills.** Step-by-step procedures in the Agent Skills format, copied to where each agent looks for them.
- **Your rules in every folder.** Rules and skills of your own can follow you to every folder on your machine, so your agents work the same way inside a code repository as in your notes. A project with code keeps its tasks and decisions in hito, and how its code runs in that repository's own `AGENTS.md`.
- **A daily journal.** `today.sh` creates today's note from a template, the same one Obsidian's daily notes can use.
- **Checks that stop mistakes.** git hooks run a check before every commit: every note has its type and date, every link points somewhere, no secret file is ever committed, and, once you set up git-crypt, everything in the sensitive folder is encrypted.
- **A base you can update.** The shared part lives in `blueprint/`, and your changes live in `custom/`. Updating replaces `blueprint/` whole, so there is nothing to merge, and your repository never gets a link back to this one.

It needs only POSIX `sh` and git (on Windows, Git Bash): no app, no server, no database, no account. Everything is local-first and works offline. The base is in English; write your notes in any language.

## Who it is for

One person who wants their notes, projects and daily journal in plain text under version control, worked on with AI agents, and who is comfortable with a terminal and git. It is not a team wiki, not a publishing platform, and not an app.

On privacy: your notes live in your own private repository, and secrets (keys, tokens, `.env` files) never enter it. But whatever an agent reads is sent to its model provider, encrypted on the remote or not, so keep sensitive material to what agents need.

## Start

1. Create your repository from this template ("Use this template", and make it private), or with the GitHub CLI: `gh repo create my-notes --template PCianes/hito-blueprint --private --clone`. Without a GitHub account, download a version (a tag's zip on GitHub), copy its `blueprint/` into an empty folder and run `git init` there.
2. In your clone, run `sh blueprint/scripts/install.sh`. Run it again on every machine where you clone it, because git does not clone the setting that turns on the git hooks.
3. Optional, for `encrypted/`: run `git-crypt init`, keep the key outside the repository, and run `install.sh` again.
4. Replace the text of this file with your own presentation, keeping its frontmatter; it is yours now.

How everything works, and how to change it without editing the base, is in [blueprint/](blueprint/README.md).

## Update

hito is not used by forking or by pulling from this repository. Your copy is a repository of your own, with no link to this one, so your notes can never be pushed here by mistake. New versions arrive by vendoring, the way shadcn/ui hands you its components: the files of the base are copied into your repository, and you commit them like any change of yours.

Run `sh blueprint/scripts/update.sh` for the latest version, or `update.sh v0.3` for a given one. It replaces `blueprint/` and runs `install.sh`; review the result with `git diff` and commit it. Versions are git tags such as `v0.1`, and `blueprint/VERSION` says which one your copy has. hito is young: until v1.0, a version may rename a rule, a folder or a property.

## Folders

The rules are in [AGENTS.md](AGENTS.md).

- [inbox/](inbox/README.md): anything waiting for a decision.
- [goals/](goals/README.md): vision, focus, values and principles.
- [projects/](projects/README.md): everything you do or maintain, one folder each.
- [knowledge/](knowledge/README.md): what you know, in your own words.
- [sources/](sources/README.md): what others say, kept whole.
- [journal/](journal/README.md): one note per day.
- [encrypted/](encrypted/README.md): sensitive material, encrypted on the remote.
- [archive/](archive/README.md): what is finished.

## License

Open source under the [MIT license](LICENSE): use it, copy it and change it as you like. It is maintained for its author's own use, so contributions are not accepted and issues are off.
