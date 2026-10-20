<!-- pj:spec sha256:ae7ebf1d8d377c5bcd6ad62584949df8b649196772c977f5e2f005a612da2b80 -->
## Spec

### Acceptance criteria

1. In `skills/pj-prep-the-repo/reference/protocol.md`, section "Issue states", "Done" is the last row of the table.
2. The Forgejo note follows the table as a paragraph, with one blank line before it.
3. The table has 5 rows in this order: Fresh, `needs-input`, `spec-ready`, Implemented, Done.
4. The text of each row and of the Forgejo note stays the same.
5. Vale passes on `skills/pj-prep-the-repo/reference`.

Out of scope: other sections of `protocol.md`, the installed copies under `.agents/`, and other wording changes.

### Bug details

- Steps: open `skills/pj-prep-the-repo/reference/protocol.md` on GitHub. Go to "Issue states".
- Expected: one table with the rows Fresh to Done. The Forgejo note is a paragraph after the table.
- Actual: the table ends after "Implemented". The Forgejo note splits it. "Done" shows as plain text with pipes.
- Environment: GitHub Flavored Markdown renderer, `main` at `4d6b177`.

### Data model

N/A, because the change is in one Markdown file and has no persistence.

### Mockup

N/A, because the change has no UI. It changes one Markdown table.

### Edge cases

- The paragraph has no blank line before it: GFM joins it to the table. Keep one blank line between them.
- Another table or list follows: no. The next section is "Skill relations", after the bullet list.

### Performance

N/A, because the change is documentation only.

### Security

N/A, because the change is documentation only.

### Access

N/A, because the change is documentation only.

### Human decisions

- Issue body: "Done" is the last row of the table. The Forgejo note is a paragraph after the table.

### Agent decisions

- Scope: change only the source file in `skills/`. The installed copies refresh from the source.
