---
name: pj-implement
description: Implement a spec-ready GitHub issue and open a PR. Claims the issue, writes a design and gets it reviewed, writes the code, tests, and docs, checks the Definition of Done, and marks the PR ready for review. Use when the user asks to implement, build, or work on a pj issue that has the spec-ready label.
license: MIT
metadata:
  version: "0.2.0"
---

# pj-implement

Implement a `spec-ready` issue and open a PR.

| Input | Requires | Result |
|---|---|---|
| `#issue` | The issue has `spec-ready`. | A PR with `Closes #<n>`, ready for review. The issue is then Implemented. |

## Rules

- Follow `<pj>/reference/protocol.md`. `<pj>` is the `pj-prep-the-repo` skill folder, next to this folder.
- Never call `gh` directly. Use the scripts in `<pj>/scripts/`. Post each comment with `comment.sh`.
- Never change the issue labels.
- Work only in `.worktrees/<n>`. Push only to `pj/<n>`.
- A small deviation from the spec: record it under Agent decisions in the PR body.
- A deviation that changes an acceptance criterion: post a `stopped` comment on the issue, and stop. A human decides.
- If you cannot finish: push the branch, post a `stopped` comment with the reason, and stop.
- Keep the PR as a draft when you stop.

## Steps

### 1. Check the issue

Run `<pj>/scripts/state.sh issue <n>`.

| Found | Action |
|---|---|
| No `spec-ready` in `labels` | Stop. Suggest `pj-grill-for-specs-readiness`. |
| `children` is more than 0 | Stop. Implement the child issues. |
| An open PR that is not from `pj/<n>` | Stop. Show the PR. |

Run `<pj>/scripts/spec.sh hash <n>`. If `match` is false, stop and suggest grill. The spec changed after the sign-off.

### 2. Check the bite size

Read the spec from `issues/<n>/spec.md` on `attachments`. Read `biteSize` from `.pj/config.json`.
Check the spec against Too big in the protocol.
If the bite is too big:

1. Get a marker: `<pj>/scripts/marker.sh pj-implement stopped reason=too-big`.
2. Post a comment on the issue with the marker and the criteria that failed.
3. Recommend `pj-decompose`, and stop. The user can tell you to continue.

### 3. Claim the issue

Run `<pj>/scripts/claim.sh <n>`.
It creates or resumes `.worktrees/<n>` on `pj/<n>`, and opens the draft PR. If it exits with 3, stop.
Install the dependencies in the worktree. `pj-repro` can have made the worktree and a failing test already.

### 4. Write the design

Make the design as short as the change allows. A small change needs a few lines.

```text
## Approach            how, in a few sentences
## Changes             modules and files to change
## Data model          the delta, as a Mermaid diagram (if any)
## Test plan           acceptance criterion → test; key logic for mutation tests
## Docs                files in docs/ to update; ADR candidates
## Risks               security, access, performance, migration, failure modes
```

Write it to `attachments`: `<pj>/scripts/attach.sh -m "docs(design): #<n>" issues/<n>/design.md <file>`.

### 5. Review the design

- Run the review in a subagent with a fresh context. Use a different model if you can.
- Give the reviewer the spec, the design, and `docs/`. Do not give it your reasoning.
- Each finding is blocking or non-blocking. Fix the blocking findings, and update the design.
- Do 2 rounds at most.
- If blocking findings remain after round 2, stop. Post a `stopped` comment with the design and the findings.

The rubric of the reviewer:

1. Does the design cover each acceptance criterion and each edge case?
2. Is there a simpler approach?
3. Does it conflict with the data model or an ADR?
4. Does the design handle each risk?
5. Will the tests in the test plan catch a real bug?

### 6. Write the code

1. Record each decision that is hard to reverse as an ADR in `docs/adr/`.
2. Write the code and the tests. Follow `AGENTS.md`.
3. Update `docs/` so that it shows the new state of the system.
4. Commit with Conventional Commits. Push to `pj/<n>`.

### 7. Check the Definition of Done

- Each acceptance criterion has at least one test.
- Build, lint, and tests pass. Use the Project commands from `AGENTS.md` on `origin/main`.
- Mutation tests ran on the key logic that changed. Kill each surviving mutant, or explain it in the PR.
- `docs/` is up to date.
- The code follows the rules in `AGENTS.md`.
- A UI change has screenshots at the same viewports as the mockup.

Fix each failure. If you cannot fix it, go to Rules: you cannot finish.

### 8. Save the evidence

Save the test output and the screenshots to `attachments`:
`<pj>/scripts/attach.sh -m "test(evidence): #<n>" issues/<n>/evidence <folder>`.

### 9. Finish the PR

1. Write the PR body in the format below. Keep the `claim` marker as the first line.
2. Run `<pj>/scripts/pr.sh body <pr> <file>`.
3. Run `<pj>/scripts/pr.sh ready <pr>`.

```text
<!-- pj:v1 {"skill":"pj-implement","event":"claim",...} -->
Closes #<n>

Spec · Design · Evidence          (links to attachments)

## Acceptance criteria            (checklist, each with its test)
## Agent decisions                (made during implementation)
## Surviving mutants              (if any, with the reason)
```

### 10. Write the devlog

Write one devlog entry. Note the design review rounds and the agent decisions.

## Report

Tell the user:

- The link to the PR.
- The agent decisions and the surviving mutants.
- The next step: `pj-review <pr>`.
