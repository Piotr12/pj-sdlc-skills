---
name: pj-next-round
description: Read the open issues and pull requests of a pj repo and suggest the next 5 skill runs, grouped for parallel sessions, plus the open actions for humans. Read-only. Use when the user asks what to do next, what to work on, for the status of the pj flow, or to plan parallel agent sessions.
license: MIT
metadata:
  version: "0.2.0"
---

# pj-next-round

Look at the issues, the PRs, and the repo. Suggest the next actions. Change nothing.

| Input | Requires | Result |
|---|---|---|
| None. It works on the current repo. | None. | The top 5 actions as commands to paste, and the actions for humans. |

## Rules

- Follow `<pj>/reference/protocol.md`. `<pj>` is the `pj-prep-the-repo` skill folder, next to this folder.
- Never call `gh` directly. Use the scripts in `<pj>/scripts/`. Post each comment with `comment.sh`.
- Read-only. Do not run the commands that you suggest.
- Read the state from labels, PRs, and markers only. Do not read prose.
- Do not write to the devlog.

## Steps

1. Run `<pj>/scripts/list.sh issues --all` and `<pj>/scripts/list.sh prs`.
2. For each open PR, run `<pj>/scripts/state.sh pr <pr>`.
3. For each open issue without a PR, run `<pj>/scripts/state.sh issue <n>`.
4. Find the possible actions with the table below.
5. Sort the actions by priority. Pick the top 5.
6. Put the actions into parallel groups.
7. Show the report. Write the commands in the syntax of the current agent.

## Actions

| Priority | State | Action |
|---|---|---|
| 1 | PR with actionable threads | `pj-address-review` |
| 2 | PR, not a draft, with `newCommits` true | `pj-review` |
| 3 | `needs-input`, and `answers` is not empty | `pj-grill-for-specs-readiness` |
| 4 | `spec-ready`, no open PR, no other assignee, no `stopped` marker | `pj-implement`, or `pj-repro` for a bug |
| 5 | Fresh | `pj-grill-for-specs-readiness`, or `pj-mock-it-up` first for a UI change |

- Finish work before you start new work. In each priority, older items go first.
- Skip an issue if an issue in its `dependsOn` is open.
- Skip an issue that has another assignee.
- A last marker `stopped` with `reason` `too-big`: suggest `pj-decompose`, not `pj-implement`.

## Human actions

List these apart, for each owner, with their age. They have no command.

- `needs-input` and `answers` is empty: answer the questions, or sign off the spec.
- PR with a clean review, or with 3 rounds: review and merge.
- Parent issue, and each issue with that `parent` has the closed state: close the parent.
- An issue with a `stopped` marker as the last marker: read it and decide.

## Parallel groups

- Two actions can run in parallel if they work on different issues and PRs and change different files.
- Use the spec and the design to guess the files.
- If two actions can change the same files, put them in different groups.
- Group A runs first. Group B runs after A, and so on.
- Run each parallel action in its own session. Each skill uses its own worktree.

## Report

```text
pj-next-round · 2026-10-19 19:40 UTC

#  Group  Command                              Why
1  A      /pj-address-review 51                3 actionable threads
2  A      /pj-review 48                        new commits after round 1
3  A      /pj-implement 42                     spec-ready, no PR
4  A      /pj-grill-for-specs-readiness 57     Fresh
5  B      /pj-implement 44                     spec-ready; same module as #42

Human
- #39  answer Q-016 to Q-018            @alice, 2 days
- #47  review round 3 is clean: merge   @bob, 5 hours
- #30  all child issues closed: close   @alice, 1 day
```

Use `timezone` from `.pj/config.json` for the time.
