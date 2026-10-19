---
name: pj-prep-the-repo
description: Prepare a new or existing GitHub repo for the pj SDLC skills. Creates the labels and the attachments branch, and opens a PR that adds the AGENTS.md rules, CLAUDE.md, .pj/config.json, and optional enforcement configs. Use when the user asks to set up, initialize, or prepare a repo for the pj skills, or to refresh the pj rules. Safe to run again.
license: MIT
metadata:
  version: "0.1.0"
---

# pj-prep-the-repo

Prepare the current repo for the pj skills. The repo can be new or old.

## Rules

- Do not push to `main`. Make all file changes in a PR.
- Do not overwrite. Merge, or ask the user.
- Do not install tools. Report what is missing and how to install it.
- `<skill>` is the folder of this skill. Run all commands from the root of the repo.

## Scripts

`<skill>/scripts/` does the git and gh work. Each script checks the state first, so a rerun after a crash is safe.
Each script prints one JSON line.

| Exit | Meaning | Action |
|---|---|---|
| 0 | Done | Continue. |
| 3 | The state needs a human decision | Stop. Show `reason` and `detail`. Ask the user. |
| 4 | `origin` has no commits | Stop. Tell the user to push a first commit to `main`. |
| Other | Error | Stop. Show the output. |

| `reason` (exit 3) | Ask the user to |
|---|---|
| `default-branch-not-main` | Rename the default branch to `main` on GitHub, or stop. pj supports `main` only. |
| `shallow-clone` | Run `git fetch --unshallow origin`. |
| `git-too-old` | Install git 2.42 or later. |
| `attachments-not-orphan` | Rename or delete the existing `attachments` branch. |
| `path-in-use`, `worktree-wrong-branch`, `two-prep-branches`, `dirty-leftover` | Look at the named worktree or branch, then clean it up. |
| `sensitive-files` | Remove the listed files from the change, or add them to `.gitignore`. |
| `rulesets-unavailable`, `ruleset-create-failed` | Create the rulesets by hand, or continue without them. |
| `branch-diverged` | Resolve the prep branch by hand. |

## Steps

### 1. Check the tools

| Tool | Needed by | Check | Install |
|---|---|---|---|
| `gh`, logged in | All skills | `gh auth status` | `brew install gh`, then `gh auth login` |
| `git` 2.42 or later | All skills (worktrees) | `git --version` | `brew install git`, or the package manager |
| `gitleaks` (recommended) | Secret scan before each write to `attachments` | `gitleaks version` | `brew install gitleaks`, or a release binary |
| Headless browser | pj-mock-it-up, UI evidence | 1. `npx --no-install playwright --version` 2. `command -v google-chrome chromium chromium-browser`, or the Chrome app on macOS | `npx playwright install --with-deps chromium` |
| Stack tools | Build, lint, tests | The commands in the Project section | As the stack needs |
| Enforcement tools | Build, lint, tests | See `<skill>/reference/enforcement.md` | See `<skill>/reference/enforcement.md` |

Run `<skill>/scripts/prep.sh status` for git, gh, the remote, and the current state.
Show one table with the result for each tool.
Stop before step 2 in these cases. Show the reason.

- `gh` or `git` is missing, or `gitOk` is false.
- `mainOk` is false: the default branch of `origin` is not `main`.
- `shallow` is true.

For the other tools, continue and tell the user which skills cannot work.

### 2. Ignore the worktrees locally

Run `<skill>/scripts/prep.sh exclude`.
It adds `.worktrees/` to `.git/info/exclude`, so the main checkout stays clean before the PR merges.

### 3. Create the labels and the rulesets

Run `<skill>/scripts/prep.sh labels`.
It creates `needs-input` and `spec-ready` if they are missing. It does not change existing labels.

Run `<skill>/scripts/prep.sh rulesets`. It lists the missing rulesets:

| Ruleset | Branch | Rules |
|---|---|---|
| `pj-main` | `main` | PR required, review threads resolved, no force-push, no deletion |
| `pj-attachments` | `attachments` | No force-push, no deletion |

The rulesets make the Autonomy rules hold on the server, for agents and for humans.
If one is missing, show this table and ask the user.
If the user agrees, run `<skill>/scripts/prep.sh rulesets --apply`.

### 4. Create the attachments branch

Run `<skill>/scripts/prep.sh attachments`.
It creates the orphan `attachments` branch and the worktree `.worktrees/attachments`, or reuses them.
If `attachments` shares history with `main`, it exits with 3.

`.worktrees/attachments` is for the human, to read files. Skills write with `<skill>/scripts/attach.sh`.

### 5. Create the work worktree

Run `<skill>/scripts/prep.sh worktree`.
It creates `.worktrees/prep` on a `pj/prep-the-repo` branch, or reuses the branch of an open prep PR.
Make all file changes of steps 6 to 11 in `.worktrees/prep`.

### 6. Write the config

Ask the user for the bite size and the timezone. Show this table for the bite size:

| `biteSize` | Max acceptance criteria | Max diff lines |
|---|---|---|
| `small` | 7 | 400 |
| `medium` | 8 | 800 |
| `large` | 9 | 1600 |

`timezone` is an IANA name, for example `Europe/Berlin`. The default is `UTC`.
The devlog and the reports use it.

If `.pj/config.json` exists, show its values and ask if the user wants to keep them.
Write `.pj/config.json` from `<skill>/templates/config.json`.

### 7. Write AGENTS.md

The pj rules block is `<skill>/templates/AGENTS.rules.md`, with its markers.

| Found | Action |
|---|---|
| No `AGENTS.md` | Create it: `# AGENTS.md`, a `## Project` section, then the block. |
| `AGENTS.md` with the markers | Replace the text between the markers. Keep all other text. |
| `AGENTS.md` without the markers | Add the block at the end. Keep all other text. |

If a rule in the other text conflicts with a pj rule, show the conflict and ask the user.

### 8. Fill the Project section

Find the stack and the commands in the repo:

| File | Stack | Commands |
|---|---|---|
| `package.json` | Web | The `build`, `lint`, and `test` scripts |
| `pubspec.yaml` | Flutter | `flutter build`, `dart analyze`, `flutter test` |

Write one line for each: Stack, Build, Lint, Test.
If the section has values, keep them. Fill only the missing values.
If the commands are not clear, ask the user.

### 9. Make CLAUDE.md import AGENTS.md

| Found | Action |
|---|---|
| No `CLAUDE.md` | Create it with one line: `@AGENTS.md`. |
| `CLAUDE.md` without `@AGENTS.md` | Add `@AGENTS.md` as the first line. Suggest that the user moves the other content into `AGENTS.md`. Ask. |
| `CLAUDE.md` with `@AGENTS.md` | No action. |

### 10. Update .gitignore

Add `.worktrees/` to `.gitignore` if it is not there.

### 11. Handle an existing project

- If the code has persistence and `docs/data-model.md` does not exist, offer to make it from the code.
- Use a Mermaid erDiagram with max 9 entities in each diagram.
- For a larger model, add sub-diagrams and one overview diagram.
- Keep all other content in `docs/`. pj-healthcheck reports drift.
- Do not change open issues or PRs. Issues without a label are Fresh.

Then offer the enforcement configs for the stack. Use `<skill>/reference/enforcement.md`.
Add the configs that the user accepts. Add their commands to the Project section.

### 12. Open the PR

Write the PR body to a temporary file outside `.worktrees/prep`. List each file that you added or changed, and why.
Run `<skill>/scripts/prep.sh pr <body-file>`.
It commits, pushes, and opens the PR or updates the open one. It then removes `.worktrees/prep`.
If there are no file changes, it opens no PR.

### 13. Check the result

If the pj-healthcheck skill is available, run it and show the report.

### 14. Write the devlog

Do this at the end of each run. Also do it if the run stops early.
Use 2 to 5 short notes. Add links to the PR and the issues.

```sh
<skill>/scripts/devlog.sh --tz <timezone> pj-prep-the-repo <repo> <outcome> "<note>" "<note>"
```

`<timezone>` is the value from step 6. If the run stopped before step 6, leave out `--tz`.
If the script cannot write to `attachments`, it prints the entry. Put it in the report.

## Report

Tell the user:

- The result of the tool check.
- What you created, and what existed.
- The rulesets that exist, and the ones that the user declined.
- The link to the PR.
- The questions that are still open.
