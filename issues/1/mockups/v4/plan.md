# Variant 4: subway map

Direction: the issue is a passenger. The feature line runs left to right through the states; bug, too big, and the PR loop are their own colored lines that leave and rejoin at interchange stations.

Bold in one place: the thick, colored 8 px lines. All else is ink on paper, thin, and quiet.

## Colors (light / dark): 3 neutrals, 4 line colors

| Name | Light | Dark | Use |
|---|---|---|---|
| paper | #ffffff | #0d1117 | background, station fill, direction chevrons |
| ink | #1f2328 | #e6edf3 | state rings, human squares, names |
| muted | #57606a | #9198a1 | captions, depot track |
| feature | #1f5fbf | #5b9cf5 | feature line (main) |
| bug | #c62828 | #f26b63 | bug line (pj-repro) |
| big | #9a6700 | #d4a23a | too big line (pj-decompose) |
| pr | #1a7f37 | #46c35a | PR loop line |

## Type roles

- Title: 19 px, 600, sans.
- State names: 15 px, 700, sans (1.27x).
- Skill names: 12 px, mono. Captions and human actions: 12 px, sans, italic for human.

## Stations

- State = paper circle with a thick ink ring (interchange).
- Skill = a tick on the line, in the line color.
- Human wait = a filled ink square.

## Wireframe

```
How an issue rides the pj skills
[== Feature] [== Bug] [== Too big] [== PR loop]   (o) state  |- skill  [#] human acts

        answer, sign off   needs-input
          [#]---------------(o)
          |                  |      failing test first
          |  pj-grill-...    |        pj-repro
 Fresh    |       |          |      /----|----\        pj-review
  (o)=====+=======|==========+==(o)=           =|=(o)===/--|--\===[#]=====(o) Done
  :       |                  | spec-ready\        /pj-   \  PR  /  review,
  :       |   UI change, no  |            \---|--/ implement\--|-/   merge
  :       [#]------------|---/         pj-decompose      pj-address-review
  :     pick a       pj-mock-it-up
  :     mockup
  [] pj-prep-the-repo, once           read-only: pj-next-round, pj-healthcheck
```
