# AGENTS.md

Rules for agents and humans who change this repo.

## Layout

- `skills/pj-*/SKILL.md` is the source of truth for a built skill.
- `docs/` holds the design of the planned skills, and the shared protocol in `docs/index.html`.
- `skills/pj-prep-the-repo/scripts/` does all git and gh work. Skills call the scripts and do not repeat their steps.
- `hooks/` holds the Claude Code guard hook.

## Changes

- Put deterministic steps in a script. Keep judgement in `SKILL.md`.
- Each script prints one JSON line and uses the exit codes in `lib.sh`.
- Add a case to `tests/prep-scripts.sh` for each script change. Run `bash tests/prep-scripts.sh`.
- Write Markdown in STE-inspired English. CI runs Vale on the Markdown files.
- Use Conventional Commits. Change `main` only through a PR.
