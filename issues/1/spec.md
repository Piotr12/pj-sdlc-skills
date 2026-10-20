<!-- pj:spec sha256:0b7d2422e500da4c76a588b5eae5dc526a0ee039e5ca21dbfbb001c035c6ae7c -->
## Spec

### Acceptance criteria
1. `README.md` shows `docs/flow.svg` as an image, with a relative path. The image is after the intro and before "Skills".
2. The diagram shows the content of the `docs/index.html` diagram: issue states, skills, and human wait points. It shows built skills only.
3. `docs/flow.svg` is the only diagram source. `docs/index.html` loads it with `<object>`, and its links still work.
4. The SVG has a light theme and a dark theme through `prefers-color-scheme` CSS inside the file.
5. The diagram is 880 px wide or less. All text is 12 px or larger at that width.
6. The image has alt text. The alt text names the states and the skills in flow order.
7. The diagram agrees with "Issue states" and "Skill relations" in `protocol.md`. CI passes, including Vale on `README.md`.

Out of scope: changes to the skills, the protocol, or the flow.

### Bug details
N/A, because the issue is not a bug.

### Data model
N/A, because the change has no persistence.

### Mockup
Six variants on `attachments` in `issues/1/mockups/v1` to `v6`, shown in https://github.com/Piotr12/pj-sdlc-skills/issues/1#issuecomment-6298491092. Picked variant: v1, the `docs/index.html` layout. Q-009.

The implementation starts from `issues/1/mockups/v1/flow.svg`.

| Variant | Objective |
|---|---|
| 1 | The `docs/index.html` layout |
| 2 | Compact and top-down, for the README column |
| 3 | Swimlanes for human and agent |
| 4 | Subway map: one line for each path (feature, bug, too big, PR loop) |
| 5 | Minimal: the states as boxes, the skills as labels on the arrows |
| 6 | Cards: one card for each skill, with its input and output state, in flow order |

### Edge cases
- The README column on GitHub is about 880 px wide, and less on a phone. The SVG scales down. At 880 px, all text is 12 px or larger.
- Other sites show the README with a broken image: skills.sh and the plugin marketplace. The alt text gives the flow.
- A later flow change updates `docs/flow.svg` only. `docs/index.html` and `README.md` show the same file.
- The `docs/index.html` diagram has a "someday, maybe" group of skills that are not built. The group goes away from `docs/index.html` and `flow.svg`. Q-010.
- An image in `README.md` has no links. The "Skills" table below it names each skill.

### Performance
The image file is 100 KB or smaller.

### Security
The SVG has no script. It loads no external resources, such as fonts or images. Links to the `SKILL.md` files are allowed.

### Access
N/A, because the diagram is public, read-only content.

### Human decisions
- Issue body: give alternative renders. The human picks one.
- Q-001: an SVG file in `docs/`, shown as an image.
- Q-002: the same content as the `docs/index.html` diagram.
- Q-003: one SVG file. `docs/index.html` loads it with `<object>`.
- Q-004: one SVG with `prefers-color-scheme` CSS.
- Q-005: a relative path.
- Q-006: after the intro, before "Skills".
- Q-007: variants 1 to 3 have the objectives from option a. Make six variants, not three.
- Q-008: 880 px wide or less, text 12 px or larger.
- Q-009: variant v1.
- Q-010: remove the "someday, maybe" group. `docs/` shows the current state only.

### Agent decisions
- Q-007: the objectives of variants 4 to 6. The human asked for six variants and named three.
