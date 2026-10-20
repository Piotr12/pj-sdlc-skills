# Variant 6 plan: skill cards

Direction: one card per skill, each card reads "in state -> out state"; the skill is the unit, the states are small chips inside the cards; role sets the card weight.

Bold in one place only: the main-path cards (grill, implement, review, address-review) have a solid ink header band. Side skills are thin dashed cards. Read-only skills have no box at all. Setup is one text line above a rule.

## Colors (light / dark)

| Name | Light | Dark | Use |
|---|---|---|---|
| ink | #1f2328 | #e6edf3 | text, main card header band and outline |
| paper | #ffffff | #0d1117 | background, text on the header band |
| quiet | #59636e | #9198a1 | secondary text, arrows, dashed cards |
| amber | #9a6700 | #d29922 | human wait points, needs-input chip |
| green | #1a7f37 | #3fb950 | spec-ready chip |
| blue | #0969da | #4493f8 | Implemented chip |

Chips: state color as the stroke, a light tint as the fill, ink text (no colored text on colored fills).

## Type roles

- 15 px mono bold: main-path skill names (on the ink band).
- 12 px mono bold: side, setup, and read-only skill names.
- 12 px sans: chips, "does" lines, labels. Section labels 12 px bold caps, letter-spaced, quiet.
- Human actions: 12 px sans semibold, amber, with an amber dot.

## Wireframe (880 wide)

```
ONCE PER REPO  pj-prep-the-repo  labels, attachments, .pj/scripts, AGENTS.md
------------------------------------------------------------------------------
EACH ISSUE        .--.  o answers questions
┏━pj-grill-for-specs━━━━┓ o sign-off ┏━pj-implement━━━━┓     ┏━pj-review━━━━━━━━┓
┃ in        out         ┃ ─────────▶ ┃ in        out   ┃ ──▶ ┃ [Impl] ▶ [Impl]  ┃
┃ [Fresh]   [needs-in]  ┃     │      ┃ [spec] ▶ [Impl] ┃     ┗━━━━━━━━━━━━━━━━━━┛
┃ [needs-in][spec-rdy]  ┃     │bugs  ┗━━━━━━━━━━━━━━━━━┛       ↓↑ any order
┗━━━━━━━━━━━━━━━━━━━━━━━┛     │       ↑      ↓too big ↑       ┏━pj-address-review┓
      ┆ UI change, no mockup  │       │      │        │       ┗━━━━━━━━━━━━━━━━━━┛
┌╌pj-mock-it-up╌╌╌┐  ┌╌pj-repro╌╌╌╌╌╌┐  ┌╌pj-decompose╌╌╌╌╌┐      │ o reviews, merges
│[Fresh] ▶ unchgd │  │[spec] ▶ fails │  │[spec] ▶ [spec]   │    [Done] issue closed
│o picks a mockup │  └╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┘  └╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┘
└╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┘
------------------------------------------------------------------------------
ANY TIME, READ-ONLY  pj-next-round ...   pj-healthcheck ...
legend: o a human acts   ▬ main path   ┆ side skill   ┄▶ suggested
```

Would I make this for any similar brief? A plain card grid, yes. What makes it specific: the in/out chip pair inside each card, and the three card weights that map to the pj roles (main, on demand, read-only).
