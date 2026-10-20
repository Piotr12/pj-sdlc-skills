# AGENTS.md

Rules for agents and humans who change this repo.

## Layout

- `skills/pj-*/SKILL.md` is the source of truth for a built skill.
- `skills/pj-prep-the-repo/reference/protocol.md` holds the shared protocol. Each `SKILL.md` links to it and does not repeat it.
- `docs/index.html` shows the flow and links to each `SKILL.md`.
- `skills/pj-prep-the-repo/scripts/` does all git and forge work. Skills call the scripts and do not repeat their steps.
- `skills/pj-prep-the-repo/scripts/forge/<forge>.sh` holds all forge calls. Each adapter defines the same `forge_*` functions.
- `pj-prep-the-repo` copies the scripts and one adapter to `.pj/scripts/` of the target repo. Skills run that copy.
- `hooks/` holds the Claude Code guard hook.

## Changes

- Put deterministic steps in a script. Keep judgement in `SKILL.md`.
- Each script prints one JSON line and uses the exit codes in `lib.sh`.
- Add a case to `tests/prep-scripts.sh` for each script change. Run `bash tests/prep-scripts.sh`.
- Change a forge call in all adapters. Test each adapter: the fake `gh` and the fake Forgejo `curl`.
- Write Markdown in STE-inspired English. CI runs Vale on the Markdown files.
- Use Conventional Commits. Change `main` only through a PR.
