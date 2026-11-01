# 0001 Delegated decisions in pj-handhold

## Context

The pj flow waits for a human at each decision: the grill questions, the spec sign-off, a stopped run, and the ask threads of a PR.
Users want to give one issue to the agents and come back to a reviewed PR.
The trust rules accept answers only from trusted humans. A comment with a marker is never an answer.

## Decision

- A trusted user can delegate the human decisions of one issue to `pj-handhold`.
- `handhold.sh start` posts a `delegate` marker. A `done` or `stopped` marker of `pj-handhold` ends the delegation.
- Under a delegation, an `answer` comment from a trusted author counts as an answer. `state.sh` marks it `delegated`.
- A decider agent in a fresh session writes the answers. It follows a fixed rubric and gives each decision a confidence.
- Skills record delegated answers under Agent decisions. The decision log goes to the issue and to the PR.
- Each step runs in a new headless agent session, with the guard hook, a permission mode, and a budget.
- The driver never merges, approves, or closes. A human reviews and merges the PR.
- The driver refuses issues from untrusted authors.

## Consequences

- An issue can go from Fresh to a reviewed PR with no human answer.
- The spec sign-off is no longer always human. The `ready` marker shows `by=delegate`. The PR log lists each decision, low confidence first.
- In the team setup, the bot posts the `delegate` marker. The marker does not prove which human started the run.
- `pj-next-round` skips delegated issues, so humans and the driver do not work on the same issue.
- A wrong delegated decision reaches the PR. The human finds it in the decision log before the merge.
- The run needs a machine that stays awake. A later CI trigger can run `handhold.sh` instead.
