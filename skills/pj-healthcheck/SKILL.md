---
name: pj-healthcheck
description: Check a pj repo for setup problems, attachments branch hygiene, and drift between docs/ and the code. Reports findings with the commands to fix them. Read-only. Use when the user asks for a health check, an audit of the pj setup, attachments cleanup, or docs drift, or after pj-prep-the-repo.
license: MIT
metadata:
  version: "0.2.0"
---

# pj-healthcheck

Check the repo setup, the `attachments` branch, and `docs/`. Suggest actions. Change nothing.

| Input | Requires | Result |
|---|---|---|
| Optional: `setup`, `attachments`, or `docs`. The default is all three. | None. A repo without prep fails the setup checks. | A report in the session, with the commands for each suggested action. |

## Rules

- Follow `<pj>/reference/protocol.md`. `<pj>` is the `pj-prep-the-repo` skill folder, next to this folder.
- Never call `gh`, `fj`, or the forge API directly. Use the scripts in `<pj>/scripts/`.
- The scripts in `<pj>/scripts/` also work before the prep PR merges.
- Read-only. The human runs the commands, and decides which docs findings get an issue.
- A delete breaks the links to that file in issue comments. Tell the user which issues have such links.
- A delete does not make the repo smaller. Only a squash of the branch does. Tell this in the report.
- A squash keeps the paths, so the links still work.
- A squash needs a force-push to `attachments`. Only a human does that.

## Setup checks

Run `<pj>/scripts/prep.sh status` first. It reports git, the forge, its CLI and login, the remote, and the prep state.
Then run `<pj>/scripts/list.sh labels`, `list.sh issues --all`, and `list.sh prs --all`.

| Check | Finding | Suggested action |
|---|---|---|
| Tools | A tool from the tools list in `<pj>/SKILL.md` is missing. | The install command from the tools list. |
| Labels | `needs-input` or `spec-ready` is missing. An issue has both labels. | Run `pj-prep-the-repo`. Remove the wrong label. |
| Attachments branch | The branch is missing, or it shares history with `main`. | Run `pj-prep-the-repo`. Make the branch again as an orphan. |
| AGENTS.md | The file or the pj rules block is missing. The block differs from `<pj>/templates/AGENTS.rules.md`. | Run `pj-prep-the-repo`. |
| Config | `.pj/config.json` is missing, or a value is not valid. See Config in the protocol. | Run `pj-prep-the-repo`. |
| Forge | `forge` is empty: the script cannot tell the forge of `origin`. | `<pj>/scripts/prep.sh forge github` or `<pj>/scripts/prep.sh forge forgejo` |
| Scripts | `scripts` is `missing` or `stale`: `.pj/scripts/` on `main` differs from `<pj>/scripts/`. | Run `pj-prep-the-repo`, then merge its PR. |
| Worktrees | `.worktrees/` is not in `.gitignore`. | Run `pj-prep-the-repo`. |
| Worktrees | A worktree for a merged or closed PR, or a `review-` worktree that a run left. | `git worktree remove <path>` |
| Worktrees | A stale entry in `git worktree list`. | `git worktree prune` |
| CLAUDE.md | The file does not import `@AGENTS.md`. | Run `pj-prep-the-repo`. |
| Rulesets | `prep.sh rulesets` reports a missing ruleset (Forgejo: branch protection). | Run `pj-prep-the-repo`. |

## Attachments checks

Read the branch with `git ls-tree -r -l origin/attachments`.

| Check | Finding | Suggested action |
|---|---|---|
| Orphans | A folder for an issue or a PR that does not exist. | Delete the folder. |
| Unpicked variants | A mockup variant on a closed issue. The spec does not name it as the pick. | Delete the variant. |
| Rule breaks | Video, a file over 1 MB, an image that is not png or webp, a path outside the layout. | Delete, compress, or move the file. |
| Consistency | An issue with `spec-ready` and no `spec.md`. | Run `pj-grill-for-specs-readiness` again. |
| History size | The branch history is much larger than its current files. | Squash the branch. |

Never suggest to delete these files. They are the history of the system.

- `spec.md` and `design.md`.
- The mockup variant that the spec names as the pick.
- All attachments of open issues and open PRs.

## Docs checks

Compare `docs/` with the source code on `origin/main`. The code is the truth.

| Check | Finding |
|---|---|
| Data model | An entity or a relation in the code that is not in `docs/data-model.md`, or the opposite. |
| States | A state or a transition in the code that is not in the stateDiagram, or the opposite. |
| ADRs | Code that contradicts an ADR that has no successor. |
| API contract | An endpoint or a field in the code that is not in the contract, or the opposite. |
| References | A link or a path in `docs/` to a file or a symbol that does not exist. |
| AGENTS.md | A command in the Project section that does not exist in the repo. |
| Rule breaks | An erDiagram with more than 9 entities. Mermaid that does not parse. |

For each finding, give the doc location, the code location, and the correction.
Mark each finding as certain or possible.

## Report

```text
setup: 1 finding
Labels             #63 has needs-input and spec-ready

attachments: 48 MB in history, 12 MB in files

Orphans            2 folders   1.1 MB
Unpicked variants  9 variants  6.3 MB
Rule breaks        1 file      3.2 MB   issues/41/evidence/run.mp4
Consistency        1 issue              #57 spec-ready, no spec.md
History size       squash would save about 36 MB

docs: 4 findings
certain   data-model.md:12      entity Invoice missing      src/db/schema.ts:88
certain   data-model.md:40      state "archived" missing    lib/order/state.dart:15
possible  adr/0003-…md          code uses polling, ADR says websockets
certain   AGENTS.md:5           "npm run e2e" not in package.json
```

After the table, list the commands for each finding.
Write one devlog entry.
