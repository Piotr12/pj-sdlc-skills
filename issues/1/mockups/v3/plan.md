# Variant 3: swimlanes for human and agent

Direction: three horizontal lanes on one time axis (Human, Forge, Agent). Each hand-off is a thick amber band
that climbs from an agent skill, cuts through the forge state track, and ends in a solid amber "you act" box.
The amber hand-offs are the only bold element. Everything else is neutral grey.

## Colors

| Name | Use | Light | Dark |
|---|---|---|---|
| bg | page | #ffffff | #0d1117 |
| ink | text | #1f2328 | #e6edf3 |
| muted | notes, sublabels | #59636e | #9198a1 |
| line | arrows, strokes | #6e7781 | #8b949e |
| lane | lane fill, chips | #f6f8fa / #eaeef2 | #151b23 / #262c36 |
| wait | hand-off band, box | band #bf8700, box #ffd33d | band and box #d29922 |

## Type roles

- 15px bold sans: lane names, human actions (1.25x of 12).
- 12px mono: skill names, label states. 12px sans: notes, sublabels, prose states.

## Wireframe

```
        | Fresh  needs-input ................. spec-ready   Implemented   Done
--------+-------------------------------------------------------------------------
HUMAN   |  [1 Answer ]  [2 Pick    ]  [3 Sign off]               [4 Review and ]
        |  [questions]  [a mockup  ]  [the spec  ]               [merge the PR ]--+
        |   ^   |          ^   |         ^   |                     ^   |          |
FORGE   | Fresh |needs-input   |         |   |  spec-ready   Implemented |    Done<+
        |   |   |          |   |         |   |                     |   |
AGENT   |   |   |    [pj-mock-it-up]     |   |   [pj-repro (bugs)] |   v
        |   |   v      UI change, no mockup  |         v       [PR loop, any order]
        | [pj-grill-for-specs-readiness ======]-->[pj-implement]-->[pj-review        ]
        |                                          | bite too big  [pj-address-review]
        |                                        [pj-decompose]
--------+-------------------------------------------------------------------------
REPO    | pj-prep-the-repo (once)   pj-next-round (read-only)   pj-healthcheck (read-only)
```

Thick bars marked `^` are amber hand-offs: the agent stops there. Thin `v` arrows return the answer to the agent.
