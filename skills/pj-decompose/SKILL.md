---
name: pj-decompose
description: Split a spec-ready issue that is too big for one implementation run into vertical child issues. Each child gets a spec subset, a link to the parent, and the spec-ready label. Use when pj-implement says the bite is too big, or when the user asks to split, break down, or decompose an issue.
license: MIT
metadata:
  version: "0.2.0"
---

# pj-decompose

Split an issue that is too big into child issues.

| Input | Requires | Result |
|---|---|---|
| `#issue`, the parent | The parent has `spec-ready`. | Child issues under the parent. Each child has a spec and `spec-ready`. |

## Rules

- Follow `<pj>/reference/protocol.md`. `<pj>` is the `pj-prep-the-repo` skill folder, next to this folder.
- Never call `gh`, `fj`, or the forge API directly. Use the scripts in `.pj/scripts/`. Post each comment with `comment.sh`.
- Create issues only after the user approves the plan.
- One level only. A child does not get children.
- The parent keeps `spec-ready`. `pj-implement` refuses a parent with children.
- A human closes the parent when all children close. Agents do not close issues.

## Steps

1. Run `.pj/scripts/state.sh issue <parent>`. If `spec-ready` is not in `labels`, stop. Suggest grill.
2. If `children` is more than 0, show the children and stop. Do not make duplicates.
3. Run `.pj/scripts/spec.sh hash <parent>`. If `match` is false, stop and suggest grill.
4. Read the parent spec from `issues/<parent>/spec.md` on `attachments`.
5. Split the work into slices. See Slicing rules.
6. Show the plan to the user: one line for each slice, with its acceptance criteria. Wait for approval.
7. For each slice, run `.pj/scripts/issue.sh child <parent> <title> <body-file>`.
8. For each child, run `.pj/scripts/spec.sh hash <child>`. Then run `.pj/scripts/spec.sh snapshot <child> <hash>`.
9. Post a comment on the parent with a task list of the children: `- [ ] #12`.
10. Write one devlog entry.

`issue.sh child` creates the issue, links it to the parent (GitHub: sub-issue, Forgejo: the child blocks the parent), and sets `spec-ready`.
A rerun reuses a child with the same title. The body file holds the full child issue, with the spec block.

## Slicing rules

- Each slice is vertical. It ships behaviour that a user or a test can see.
- A layer such as "backend only" is not a slice.
- Each acceptance criterion of the parent goes to exactly one child.
- Each child fits in one `pj-implement` run. Use Too big in the protocol.
- Make the slices independent when you can. If the order matters, write `Depends on: #x` in the child.

## Child issue

```text
Parent: #<parent>
Depends on: #x                      (if needed)

<!-- pj:spec:start -->
## Spec
Parent spec: <link to issues/<parent>/spec.md>
### Acceptance criteria             (the subset for this slice)
### Edge cases                      (the subset for this slice)
### Data model, Mockup, …           (links to the parts of the parent that apply)
<!-- pj:spec:end -->
```

The parent spec has a sign-off. Each child spec is a subset of it, so the child needs no new sign-off.

## Report

Tell the user:

- The child issues, with their links and dependencies.
- The next step: `pj-next-round`, or `pj-implement` for the first child.
