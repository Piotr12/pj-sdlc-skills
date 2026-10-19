<!-- pj:rules:start -->
## Autonomy
- You may: create branches `pj/*`, push to them and to `attachments`, open PRs, comment,
  set labels, edit the pj spec block of an issue, resolve your own review threads,
  create issues after the user approves.
- You must not: push to `main`, merge, close issues, force-push branches you did not create, delete branches, change CI or secrets.

## Docs
- `docs/` shows the current state of the system only.
- `docs/data-model.md`: one conceptual data model. Mermaid erDiagram.
  Add a stateDiagram for each entity that has a lifecycle.
- Keep each erDiagram to 7 entities or fewer, 9 at most.
  Split a larger model into sub-diagrams.
  Add one overview diagram that shows the sub-diagrams and the relations between them.
- `docs/adr/NNNN-title.md`: one ADR for each decision that is hard to reverse.
  Sections: context, decision, consequences.
- A PR that changes behaviour, the model, or the architecture updates `docs/` in the same PR.

## Writing
- All Markdown follows ASD-STE100.
- One instruction per sentence. Max 20 words for procedures, 25 for descriptions.
- Use the active voice. Use the imperative for procedures.
- Use one term for one thing. Do not use synonyms.
- Show structure with a Mermaid diagram or a table, not prose.

## Code
- No magic strings or numbers. Use named constants or enums.
- Put user-facing text in l10n files (Flutter: ARB; web: i18n catalog). Never inline.
- Do not swallow errors. Handle them at the boundary. Log once, with context.
- Use structured logs. Do not log secrets or personal data.
- If an API contract exists (e.g. OpenAPI), it is the source of truth. Generate clients from it.
- Validate input at boundaries. Check access on the server.
- Use Conventional Commits.

## Tests
- A test must fail when the behaviour it covers breaks. Delete tests that cannot fail.
- Test behaviour, not implementation. Do not test trivial code.
- Key logic (calculations, permissions, state transitions) gets mutation tests.
  TS: StrykerJS. Dart: mutation_test, on changed files only.
- Flutter: unit, widget, golden. integration_test for critical flows.
- Web: unit. Playwright for critical flows.
- A bug fix starts with a failing test.

## UI
- Web: WCAG 2.2 AA.
- Flutter: Semantics on interactive widgets.

## Devlog
- `devlog/` on the `attachments` branch holds notes for the human operator.
  Do not read it. It has no information for your work.
<!-- pj:rules:end -->
