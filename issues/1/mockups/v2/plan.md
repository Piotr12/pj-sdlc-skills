# Plan: variant 2, compact top-down

Direction: one thick vertical spine carries the issue from Fresh to Done; humans wait on the left of it, agent skills act on the right, each beside the step it moves.

Bold in one place: the spine. A 5 px ink line with the five states threaded on it. All other lines are thin and quiet.

Not generic: the three columns are the three actors (human, issue, agent), so a reader on a phone scans one column at a time. The two forge labels look like forge labels (pills in label colors). The forge states are plain boxes.

## Colors

| Name | Light | Dark | Use |
|---|---|---|---|
| ink | #1f2328 | #e6edf3 | spine, state names, skill names |
| muted | #59636e | #9198a1 | notes, thin lines, column heads |
| surface | #ffffff | #161b22 | box and chip fill |
| amber | #9a6700 | #d29922 | human wait points, `needs-input` stroke |
| amber-tint | #fff8c5 | #3b2e05 | `needs-input` fill |
| green | #1a7f37 | #3fb950 | `spec-ready` stroke |
| green-tint | #dafbe1 | #12261e | `spec-ready` fill |

Background is transparent. Text on tints is ink, not the stroke color.

## Type roles (each step 1.25x)

- Note, column head: 15 px sans (head: 600, caps, tracked)
- Skill name: 19 px mono
- State name: 24 px sans 600 (label states in mono 600)

## Wireframe (880 wide)

```
HUMAN            ISSUE              AGENT SKILLS
                   :                [pj-prep-the-repo]  once per repo
               +--------+
               | Fresh  |
               +--------+
(needs-input) <--- | ---------------[pj-grill-for-specs-readiness]
  answers ------>  |                 '-[pj-mock-it-up]  UI change, no mockup
  signs off        v
  picks mockup (spec-ready)
                   |                 .-[pj-repro]  bugs
                   | ---------------[pj-implement]
                   v                 '-[pj-decompose]  too big
               +-----------+
               |Implemented|
               +-----------+
reviews, merges -o-------------------[pj-review]      )
                   v                 [pj-address-review] ) any order
               +--------+
               |  Done  |
               +--------+
------------------------------------------------------------
ANY TIME, READ-ONLY   [pj-next-round]       [pj-healthcheck]
```
