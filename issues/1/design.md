# Design: #1 README flow diagram

## Approach

Start from the picked mockup `issues/1/mockups/v1/flow.svg` and commit it as `docs/flow.svg`, the only diagram source.
`README.md` shows it with `<img>`. `docs/index.html` loads it with `<object>`, so its links work. In an `<img>`, the links have no effect.
A new section in `tests/prep-scripts.sh` checks the files. CI already runs that file.

## Changes

| File | Change |
|---|---|
| `docs/flow.svg` | New. v1 mockup, plus: an `<a href="../skills/<skill>/SKILL.md" target="_top">` around each skill chip, a hover style, and "PR ready" instead of "PR linked" under Implemented (protocol: a PR ready for review). |
| `docs/index.html` | Remove the inline SVG, its CSS, and the "someday, maybe" group. Add `<object data="flow.svg" type="image/svg+xml">` with an `aspect-ratio: 880 / 470` style. The fallback content is an `<img>` with the alt text. |
| `README.md` | After the intro paragraph, before "## Skills": `![<alt>](docs/flow.svg)`. The alt is short STE sentences, states and skills in flow order. Update "## Design" to name `docs/flow.svg`. |
| `AGENTS.md` | Layout: `docs/flow.svg` is the only flow diagram. `docs/index.html` and `README.md` show it. |
| `tests/prep-scripts.sh` | New section "docs flow diagram", one check for each acceptance criterion. |

## Data model

None.

## Test plan

| AC | Check in `tests/prep-scripts.sh` |
|---|---|
| 1 | `README.md` has `](docs/flow.svg)`, and it is after the first paragraph and before `## Skills`. |
| 2 | Each folder `skills/pj-*` has a link `href="../skills/<skill>/SKILL.md"` in `flow.svg`. The unbuilt names (`pj-upgrade`, `pj-release`, `pj-fix-ci`, `pj-resolve-conflict`) and "someday" are not in `flow.svg` or `docs/index.html`. The five states are in `flow.svg`. |
| 3 | `docs/index.html` has no `<svg` and has `<object data="flow.svg"`. Each `href` in `flow.svg` resolves to a file, relative to `docs/`. The count of `<a ` equals the count of `target="_top"`. |
| 4 | `flow.svg` has `@media (prefers-color-scheme: dark)`. |
| 5 | The `viewBox` and `width` are 880 or less and equal. Each `font-size`, in CSS and in attributes, is 12 or larger. |
| 6 | The alt in `README.md` names Fresh, needs-input, spec-ready, Implemented, Done, and pj-grill-for-specs-readiness, pj-implement, pj-review, at increasing offsets. `flow.svg` has `<title>` and `<desc>`. |
| 7 | "PR ready" is in `flow.svg`, "PR linked" is not. Also covered by the checks for 2 and 3, and by CI (Vale on `README.md`). Manual check of the flow against "Issue states" and "Skill relations": recorded in the PR. |
| Perf | `flow.svg` is 102400 bytes or less. |
| Sec | `flow.svg` has no `<script`, no `[[:space:]]on[a-z]+=` attributes, no `@import`, no `url(http`, and no `href="http`. |

The checks use `grep -E` and `grep -F` only (BSD and GNU), and paths from `$(dirname "$0")/..`.
Each check fails on a real break: an edited path, a removed skill, a smaller font, an inline SVG put back.
Mutation tests: N/A, because the change has no program logic. The checks are the tests.
Screenshots: the README frame and `docs/index.html`, light and dark, at 390×844 and 1440×900. The same viewports as the mockup.

Link click in `<object>`: a manual check in headless Chrome, recorded in the evidence.

## Docs

`docs/index.html` and `docs/flow.svg` are the docs change. No ADR: one shared file is easy to reverse.

## Risks

- Theme: `prefers-color-scheme` follows the OS, not the GitHub theme. The SVG draws its own background panel, so it stays readable. Accepted in the spec (Q-004).
- `<object>` links: without `target="_top"`, a click opens the file inside the object frame. The test checks `target="_top"`.
- `<object>` sizing: an object has no intrinsic height in some browsers. Use `width: 100%` and `aspect-ratio`.
- GitHub sanitizes SVG in `<img>`: no scripts, so nothing is lost. Links are inert in the README. The Skills table below the image names each skill.
- Font fallback: the mono chips are sized for SF Mono and Menlo. A wider font can crowd a chip. Low risk: a 12 px mono font has about the same width on all platforms.

## Design review

Round 1: no blocking findings. Took 1 (AGENTS.md), 2 (alt order), 3 (links per skill), 4 (target count, font sizes, width), 5 (portable grep), 6 (Markdown image), 7 (click check), 8 ("PR ready").
