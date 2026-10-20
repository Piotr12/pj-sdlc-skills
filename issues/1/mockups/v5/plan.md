# Variant 5: minimal

Direction: the five issue states are the only boxes; each skill is a label on the arrow it performs, and every human wait point is an amber arrow or amber line that starts with "human".

Would I make this for any similar brief? A plain state machine, yes. The change: amber is used only for the human. Agent work stays grey ink. A reader sees at a glance where the flow stops for a person. That is the one bold place.

## Colors

| Name | Light | Dark | Use |
|---|---|---|---|
| ink | #1f2328 | #e6edf3 | state names, skill names, box stroke |
| muted | #59636e | #9198a1 | sub text, side notes |
| line | #656d76 | #8b949e | agent arrows, dotted connectors |
| surface | #f6f8fa | #161b22 | box fill |
| human | #9a6700 | #d29922 | human arrows and labels (the bold place) |

Background: transparent, so it sits on GitHub #ffffff and #0d1117.

## Type

- 15 px semibold: state names (sans for forge states, mono for the two labels).
- 12 px mono: skill names. 12 px sans: notes and human labels.
- One step only, 12 to 15 (1.25x). Weight and color carry the rest.

## Wireframe (880 x 216)

```
                 [ needs-input ]                     repo level  pj-prep-the-repo once
       questions   ^        |  human answers,        read-only, any time  pj-next-round  pj-healthcheck
                   |        v  signs off              bug: pj-repro first   human reviews
 [ Fresh ] ----------------------------> [ spec-ready ] ---------> [ Implemented ] ------> [ Done ]
            pj-grill-for-specs-readiness       :       pj-implement     (loop)         and merges
                       :                too big: pj-decompose        pj-review, pj-address-review
           UI change: pj-mock-it-up    child issues start spec-ready     any order, until merge
             human picks a mockup
```
