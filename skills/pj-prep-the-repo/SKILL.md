---
name: pj-prep-the-repo
description: Prepare a new or existing GitHub repo for the pj SDLC skills. Creates the labels and the attachments branch, and opens a PR that adds the AGENTS.md rules, CLAUDE.md, .pj/config.json, and optional enforcement configs. Use when the user asks to set up, initialize, or prepare a repo for the pj skills, or to refresh the pj rules. Safe to run again.
---

# pj-prep-the-repo

Prepare the current repo for the pj skills. The repo can be new or old.

## Rules

- Do not push to the default branch. Make all file changes in a PR.
- Do not overwrite. Merge, or ask the user.
- Do not install tools. Report what is missing and how to install it.
- Paths to `templates/` and `reference/` are relative to the folder of this skill.

In the commands, `<default>` is the default branch:
`gh repo view --json defaultBranchRef -q .defaultBranchRef.name`.

## Steps

### 1. Check the tools

| Tool | Needed by | Check | Install |
|---|---|---|---|
| `gh`, logged in | All skills | `gh auth status` | `brew install gh`, then `gh auth login` |
| `git` 2.42 or later | All skills (worktrees) | `git --version` | `brew install git` |
| Headless browser | pj-mock-it-up, UI evidence | 1. `npx --no-install playwright --version` 2. `command -v google-chrome chromium chromium-browser`, or the Chrome app on macOS | `npx playwright install --with-deps chromium` |
| Stack tools | Build, lint, tests | The commands in the Project section | As the stack needs |
| Enforcement tools | Build, lint, tests | See `reference/enforcement.md` | See `reference/enforcement.md` |

Show one table with the result for each tool.
If `gh` or `git` is missing, stop.
For the other tools, continue and tell the user which skills cannot work.

### 2. Ignore the worktrees locally

Add `.worktrees/` to `.git/info/exclude`.
The main checkout then stays clean before the PR is merged.

### 3. Create the labels

Run `gh label list`. Create each label that is missing:

```sh
gh label create needs-input --color FBCA04 --description "pj: waiting for a human answer"
gh label create spec-ready --color 0E8A16 --description "pj: meets the Definition of Ready"
```

If a label exists, use it. Do not change its color or description.

### 4. Create the attachments branch

Run `git fetch origin`.

- **The branch exists.** Run `git merge-base origin/<default> origin/attachments`.
  If it prints a commit, the branch is not an orphan. Stop and ask the user.
  If `.worktrees/attachments` does not exist, run `git worktree add .worktrees/attachments attachments`.
- **The branch does not exist.** Create it:

```sh
git worktree add --orphan -b attachments .worktrees/attachments
cp templates/gitattributes .worktrees/attachments/.gitattributes
git -C .worktrees/attachments add .gitattributes
git -C .worktrees/attachments commit -m "chore: create attachments branch"
git -C .worktrees/attachments push -u origin attachments
```

`.worktrees/attachments` is for the human, to read files. Skills write from detached worktrees.

### 5. Create the work worktree

```sh
git worktree add -b pj/prep-the-repo .worktrees/prep origin/<default>
```

If the branch exists, use `git worktree add .worktrees/prep pj/prep-the-repo`.
Make all file changes of steps 6 to 11 in `.worktrees/prep`.

### 6. Write the config

Ask the user for the bite size. Show this table:

| `biteSize` | Max acceptance criteria | Max diff lines |
|---|---|---|
| `small` | 7 | 400 |
| `medium` | 8 | 800 |
| `large` | 9 | 1600 |

If `.pj/config.json` exists, show its value and ask if the user wants to keep it.
Write `.pj/config.json` from `templates/config.json`.

### 7. Write AGENTS.md

The pj rules block is `templates/AGENTS.rules.md`, with its markers.

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

- If the code has persistence and `docs/data-model.md` does not exist:
  offer to make it from the code.
  Use a Mermaid erDiagram with max 9 entities in each diagram.
  For a larger model, add sub-diagrams and one overview diagram.
- Keep all other content in `docs/`. pj-healthcheck reports drift.
- Do not change open issues or PRs. Issues without a label are Fresh.

Then offer the enforcement configs for the stack. Use `reference/enforcement.md`.
Add the configs that the user accepts. Add their commands to the Project section.

### 12. Open the PR

```sh
git -C .worktrees/prep add -A
git -C .worktrees/prep commit -m "chore: prepare repo for pj skills"
git -C .worktrees/prep push -u origin pj/prep-the-repo
gh pr create --head pj/prep-the-repo --base <default> --title "chore: prepare repo for pj skills" --body "<summary>"
```

In the body, list each file that you added or changed, and why.
If there are no file changes, do not open a PR.

### 13. Check the result

If the pj-healthcheck skill is available, run it and show the report.

### 14. Write the devlog

Do this at the end of each run. Also do it if the run stops early.

```sh
id=$(date +%s)
git fetch origin attachments
git worktree add --detach .worktrees/att-$id origin/attachments
day=$(TZ=Europe/Warsaw date +%F)
time=$(TZ=Europe/Warsaw date +%H:%M)
file=.worktrees/att-$id/devlog/$day-devlog.html
```

If `$file` does not exist, create it with this header:

```html
<!doctype html><meta charset="utf-8"><title>devlog DAY</title>
<style>body{font:15px/1.5 system-ui,sans-serif;max-width:900px;margin:24px auto;padding:0 16px}article{border-top:1px solid #ccc;padding:8px 0}h2{font-size:15px;margin:0}</style>
<h1>devlog DAY</h1>
```

Append one entry. Use 2 to 5 short notes. Add links to the PR and the issues.

```html
<article>
  <h2>TIME · pj-prep-the-repo · OUTCOME</h2>
  <ul>
    <li>…</li>
  </ul>
</article>
```

Commit and push. If the push fails, rebase and push again. The union merge driver joins the entries.

```sh
git -C .worktrees/att-$id add devlog
git -C .worktrees/att-$id commit -m "chore(devlog): pj-prep-the-repo"
git -C .worktrees/att-$id push origin HEAD:attachments \
  || { git -C .worktrees/att-$id fetch origin attachments \
       && git -C .worktrees/att-$id rebase origin/attachments \
       && git -C .worktrees/att-$id push origin HEAD:attachments; }
git worktree remove .worktrees/att-$id
```

## Report

Tell the user:

- The result of the tool check.
- What you created, and what existed.
- The link to the PR.
- The questions that are still open.
