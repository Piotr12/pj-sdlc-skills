---
name: pj-mock-it-up
description: Make mid-fidelity HTML mockup variants for a UI change in a GitHub issue, render them to PNG sheets for each viewport, store them on the attachments branch, and show them in an issue comment. Supports a variant count, a creative objective per variant, and mutations of a variant. Use when the user asks for a mockup, wireframe, UI variants, or design options for an issue.
license: MIT
metadata:
  version: "0.2.0"
---

# pj-mock-it-up

Make mockup variants for a UI change in an issue.

| Input | Requires | Result |
|---|---|---|
| `#issue`. Optional: the number of variants, an objective for each variant, or `mutate vN` with guidance. | An open issue in any state. A headless browser. | New variants on `attachments`, and a comment on the issue. The state stays the same. |

## Rules

- Follow `<pj>/reference/protocol.md`. `<pj>` is the `pj-prep-the-repo` skill folder, next to this folder.
- Never call `gh` directly. Use the scripts in `<pj>/scripts/`. Post each comment with `comment.sh`.
- Make 2 variants by default. Make a different number if the user asks.
- Each run adds new variants: `v1`, `v2`, then `v3`, and so on. Never overwrite a variant.
- To mutate, the user names a variant and gives guidance. The result is a new variant.
- A mutation does not change the base variant.
- The human picks a variant. Grill records the pick as a human decision in the spec.
- Never change the labels.

## Steps

1. Run `<pj>/scripts/state.sh issue <n>`. Read the issue, the spec block, and the existing mockups on `attachments`.
2. Find the screens. For each screen, find the states that matter: empty, loading, error, filled.
3. Find the next free variant number in `issues/<n>/mockups/` on `attachments`.
4. Start one subagent for each variant. Give it the spec, the screens and states, and its objective.
5. Each subagent writes one responsive HTML file for each screen and state. See Design direction.
6. Check each HTML file against the anti-patterns. Fix each hit.
7. Render each HTML file to one PNG for each viewport. See Render.
8. For each screen and state, make one sheet PNG with all viewports side by side.
9. Write the files: `<pj>/scripts/attach.sh -m "docs(mockup): #<n> vN" issues/<n>/mockups/vN <folder>`.
10. Post one comment on the issue. For each variant, show the sheets inline and link the HTML files.
11. Write one devlog entry.

## Viewports

| Platform | Viewports (width × height) |
|---|---|
| Web | mobile 390×844, desktop 1440×900 |
| Flutter | phone 390×844 and 844×390, tablet 820×1180 and 1180×820 |

## Render

Use Playwright if `npx --no-install playwright --version` works. Else use Chrome or Chromium:

```sh
chrome --headless=new --hide-scrollbars --window-size=390,844 --screenshot=<out>.png <file>.html
```

To make a sheet, write one HTML page with an `iframe` for each viewport, side by side. Render that page.
If no headless browser is available, stop. Tell the user to install one. See the tools list in `<pj>/SKILL.md`.

## Fidelity

- Mid fidelity. The goal is to agree on the structure, not to finish the visuals.
- Use the existing look of the app if the repo makes it clear. If not, use a neutral wireframe style.

## Design direction

- Before it writes HTML, each subagent selects one direction.
- With an objective: follow the objective. You can use a bold visual direction.
- With no objective: keep the look of the app. The variants differ in layout, flow, or interaction.
- Before the HTML, write a short plan: 4 to 6 named colors, the type roles, and an ASCII wireframe.
- Ask: "Would I make this for any similar brief?" If yes, change the plan.
- Be bold in one place only. Keep the rest quiet.

## Anti-patterns

The look of the app has priority. If the app already uses a pattern, keep it.

1. Do not use Inter, Roboto, Geist, or Space Grotesk as the only typeface by default.
2. Do not use purple or violet gradients, cyan on dark, or glowing colored shadows.
3. Do not use a cream background by default, or a near-black background with one neon accent.
4. Do not use gradient text. Do not color or italicize one word in a headline.
5. Do not put a small uppercase label above each heading.
6. Do not number sections (01, 02, 03) unless the content is a real sequence.
7. Do not build the screen from identical rounded cards with the same radius and shadow.
8. Do not put cards inside cards.
9. Do not put a thick colored border on one side of cards, alerts, or list items.
10. Do not use the feature card with an icon in a rounded tile above the heading.
11. Do not open with a big number, a label, and a stats row, unless the spec asks for metrics.
12. Do not use the same spacing everywhere. Group related items. Put more space above a heading than below it.
13. Make the type hierarchy clear. Each size step is at least 1.25 times the previous step.
14. Do not use emoji or Unicode symbols as icons. Use one icon set.
15. Do not use lorem ipsum, buzzwords, or slogans. Write real content in the words of the product.
16. Do not use vague button labels such as "Submit" or "Learn more". Name the action.
17. Do not add decorative grids, stripes, blobs, glows, or clip-art scenes.
18. Do not use grey text on colored surfaces, or text with low contrast.
19. Keep padding at screen edges and in containers: 16 px minimum on mobile.

Sources of ideas: Anthropic `frontend-design` and `pbakaus/impeccable`, both Apache 2.0. The text here is our own.

## Layout

```text
issues/<n>/mockups/
├── v1/
│   ├── <screen>-<state>.html
│   ├── <screen>-<state>-<viewport>.png
│   └── <screen>-<state>-sheet.png
└── v2/…
```

## Report

Tell the user:

- The link to the comment.
- The variants, with one line about the direction of each.
- The next step: pick a variant in a reply, then run `pj-grill-for-specs-readiness`.
