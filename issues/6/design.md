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
| 1. "Done" is the last row | "issue states in order, Done last": reads the rows up to the first blank line. |
| 2. Note is a paragraph after the table, one blank line | "no split tables": no table row after a paragraph line, outside code fences. A header row with a delimiter row passes. |
| 3. 5 rows in order | "issue states in order, Done last": expects Fresh, `needs-input`, `spec-ready`, Implemented, Done. |
| 4. Text stays the same | `git diff --word-diff` shows only moved lines. |
| 5. Vale passes | `vale skills/pj-prep-the-repo/reference`. |

No key logic, so no mutation tests.

## Docs
No change in `docs/`. The fix is in the protocol reference. No ADR.

## Risks
- The check gives a false positive on a valid file. Checked: on `main` it flags only line 21 of `protocol.md`.
- Installed copies under `.agents/` keep the bug until they refresh. Out of scope.

## Review
Round 1: no blocking findings. Adopted: assert the row order, skip code fences, allow a table header after a paragraph.
