---
name: pj-repro
description: Reproduce a bug from a spec-ready GitHub issue with a failing test before the fix. Claims the issue, writes and commits a test that fails for the reported reason, saves the output as evidence, then continues with pj-implement. Use when the user asks to reproduce a bug, or to start a bug fix with a failing test.
license: MIT
metadata:
  version: "0.2.0"
---

# pj-repro

Reproduce a bug with a failing test before the fix.

| Input | Requires | Result |
|---|---|---|
| `#issue`, a bug | The issue has `spec-ready`. | A failing test on `pj/<n>`. Then `pj-implement` continues. |

## Rules

- Follow `<pj>/reference/protocol.md`. `<pj>` is the `pj-prep-the-repo` skill folder, next to this folder.
- Never call `gh` directly. Use the scripts in `<pj>/scripts/`. Post each comment with `comment.sh`.
- Never change the issue labels.
- Change only test files. Do not fix the bug in this skill.

## Steps

1. Run `<pj>/scripts/state.sh issue <n>`. If `spec-ready` is not in `labels`, stop. Suggest grill.
2. Run `<pj>/scripts/spec.sh hash <n>`. If `match` is false, stop and suggest grill.
3. Read the Bug details in the spec and the attachments of the issue.
4. Run `<pj>/scripts/claim.sh <n> pj-repro`. If it exits with 3, stop. Install the dependencies.
5. Write a test that fails for the reported reason.
6. Run the test. Make sure that it fails for the correct reason, not for a setup error.
7. If the bug does not reproduce, go to Not reproduced.
8. Commit the test as its own commit: `test: reproduce #<n>`. Push to `pj/<n>`.
9. Save the test output: `<pj>/scripts/attach.sh -m "test(repro): #<n>" issues/<n>/evidence/repro.txt <file>`.
10. Write one devlog entry.
11. Continue with `pj-implement <n>` in the same worktree.

## Not reproduced

1. Get a marker: `<pj>/scripts/marker.sh pj-repro stopped reason=no-repro`.
2. Post a comment on the issue with the marker. Tell what you tried and the result.
3. @mention the user who ran the skill in the comment.
4. Write one devlog entry, and stop.

## Report

Tell the user:

- The test and the failure output, or what you tried.
- The next step: `pj-implement <n>`, or a human answer on the issue.
