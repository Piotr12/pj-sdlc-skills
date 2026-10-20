# Design: #6 Done row outside the Issue states table

## Approach
Move the "Done" row up, directly after the "Implemented" row.
Put one blank line after the table, then the Forgejo note as a paragraph.
Add a regression check: a table row must not follow a paragraph line.

## Changes
- `skills/pj-prep-the-repo/reference/protocol.md`: reorder lines 17 to 21. No text changes.
- `tests/prep-scripts.sh`: add one check in a new "markdown" section. It scans the Markdown files that Vale lints.

## Data model
None.

## Test plan
| Criterion | Test |
|---|---|
| 1. "Done" is the last row | Markdown check: no `|` line after a non-blank, non-`|` line outside code fences. It fails on `main` today. |
| 2. Note is a paragraph after the table, one blank line | Same check. Manual review of the diff. |
| 3. 5 rows in order | Diff review: the rows keep their order, "Done" moves up by 2 lines. |
| 4. Text stays the same | `git diff --word-diff` shows only moved lines. |
| 5. Vale passes | `vale skills/pj-prep-the-repo/reference`. |

No key logic, so no mutation tests.

## Docs
No change in `docs/`. The fix is in the protocol reference. No ADR.

## Risks
- The check gives a false positive on a valid file. Checked: on `main` it flags only line 21 of `protocol.md`.
- Installed copies under `.agents/` keep the bug until they refresh. Out of scope.
