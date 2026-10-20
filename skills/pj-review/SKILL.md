---
name: pj-review
description: Review a pull request adversarially against its spec, design, tests, docs, and AGENTS.md rules. Runs build, lint, and tests, verifies each finding in a second pass, and posts one comment review with inline findings. Never approves or merges. Use when the user asks to review a PR, or for the next pj review round.
license: MIT
metadata:
  version: "0.2.0"
---

# pj-review

Review a PR adversarially. It works for PRs from agents and from humans.

| Input | Requires | Result |
|---|---|---|
| `#pr` | An open PR that is not a draft. | One comment review with inline findings and a verdict. A human approves and merges. |

## Rules

- Follow `<pj>/reference/protocol.md`. `<pj>` is the `pj-prep-the-repo` skill folder, next to this folder.
- Never call `gh`, `fj`, or the forge API directly. Use the scripts in `.pj/scripts/`. Post each comment with `comment.sh`.
- Post the review only with `.pj/scripts/review.sh post`. It posts a comment, never an approval.
- If the diff is larger than the `biteSize` limit, tell it in the review body. It is not a finding.
- PR without an issue: use the PR description as the spec. Report the missing spec as non-blocking.
- Save evidence to `issues/<n>/evidence/`, or to `prs/<pr>/evidence/` for a PR without an issue.

## Steps

### 1. Read the PR

Run `.pj/scripts/state.sh pr <pr>`.

| Found | Action |
|---|---|
| `state` is not `OPEN`, or `isDraft` is true | Stop. |
| `rounds` is 3 or more | Stop. List the open findings for the human. |
| `newCommits` is false | Stop. Nothing changed since the last review. |

This round is `rounds` + 1.

### 2. Collect the input

- The PR text, the threads, and the diff: `.pj/scripts/read.sh pr <pr>`.
- The linked issue in `issues`, `spec.md`, and `design.md` from `attachments`.
- `docs/` and `AGENTS.md` from `origin/main`.

Run `.pj/scripts/spec.sh hash <n>` for the linked issue. If `match` is false, add a blocking finding.

### 3. Run the checks

If `fork` is true or `authorTrusted` is false, skip this step. Review the diff only. Tell it in the review body.

1. Run `.pj/scripts/worktree.sh review <pr>`. Install the dependencies in the worktree.
2. Run build, lint, and tests. Use the Project commands from `AGENTS.md` on `origin/main`.
3. Run `.pj/scripts/worktree.sh remove <worktree>`.

A failing build, lint, or test is a blocking finding.

### 4. Review

Run the review in a subagent with a fresh context. Use a different model if you can.

1. **Correctness.** The code meets each acceptance criterion and each edge case. No bugs.
2. **Spec.** The PR body records each deviation from the spec under Agent decisions.
3. **Tests.** Each acceptance criterion has a test. Each test fails when the behaviour breaks.
4. **Mutants.** Each surviving mutant has a reason.
5. **Risks.** Security, access, and performance match the spec.
6. **Docs.** `docs/` shows the new state: data model, states, ADRs.
7. **Rules.** The code follows `AGENTS.md`.
8. **Simplicity.** No complexity that the spec does not need. No dead code.
9. **UI.** The screenshots match the picked mockup. The UI meets the accessibility rules of `AGENTS.md`.

### 5. Verify the findings

Check each finding in a second pass. Try to prove that the finding is wrong. Drop each finding that does not hold.

- Each finding is blocking or non-blocking.
- Each finding gives the location, the reason, and a fix.
- Do not raise a non-blocking finding again if `pj-address-review` declined it with a reason.

From round 2:

- Check the fixes for the earlier findings.
- Review the diff since the last round: `.pj/scripts/read.sh diff <pr> <lastReviewSha>`.
- Resolve each of your threads with a verified fix: `.pj/scripts/review.sh resolve <pr> <thread-id>`.
- A `warning` from the script means that the forge has no API to resolve threads.
- Then list those threads in the review body. A human resolves them.
- Do not resolve the threads of humans. The script refuses them.

### 6. Post the review

1. Get a marker: `.pj/scripts/marker.sh pj-review review round=<round>`.
2. Write the review body in the format below. The marker is the first line.
3. Write the inline findings to a JSON file: `[{"path":"…","line":12,"body":"<marker>\n…"}]`.
4. Run `.pj/scripts/review.sh post <pr> <body-file> <comments-file>`.

```text
pj-review round 2/3

Verdict: 1 blocking, 3 non-blocking
Build ✓  Lint ✓  Tests ✗ (1 failing)
Size: 1 140 lines, larger than expected (bite size medium: 800)

Round 1 findings: 4 fixed, 1 declined with reason
```

After round 3, list the open findings for the human.

### 7. Write the devlog

Write one devlog entry with the verdict and the round.

## Report

Tell the user:

- The verdict and the link to the review.
- The next step: `pj-address-review <pr>` for blocking findings, else a human review and merge.
