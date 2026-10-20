# v1 plan: the docs/index.html layout at 880 px

Direction: the same diagram as `docs/index.html` (main state row, needs-input loop above,
optional skills and the PR loop below, repo-level skills under a rule), redrawn natively at
880 px so that no text is smaller than 12 px. Faithful, not a redesign.

Bold in one place only: the human wait points. In the original they are muted italic and easy
to miss. Here they are italic in one strong rose color, and each one starts with "human".

Background: an explicit rounded panel in `--bg`. The `<img>` follows the OS color scheme, not
the GitHub theme, so a transparent SVG can put dark text on a dark page. The panel prevents that.

Dropped: the "someday, maybe" group (pj-upgrade, pj-release, pj-fix-ci, pj-resolve-conflict).
These skills are not built, and the README shows built skills only.

## Colors (light / dark)

| Name | Light | Dark | Use |
|---|---|---|---|
| bg | #ffffff | #0d1117 | panel |
| ink | #111827 | #e6edf3 | text, chip fill (light) |
| line | #6b7280 | #8b949e | arrows, links, muted captions |
| human | #be123c | #fb7185 | human wait points (the bold part) |
| suggest | #b45309 | #fbbf24 | "suggests" curves and reasons (as original) |
| states | gray, amber, green, blue, violet tints from docs/style.css | dark tints | state boxes |

## Type roles

- State name: 15 px, 600, system stack.
- Skill name: 12 px, ui-monospace.
- Caption, state detail, reason, human note: 12 px, system stack (human: italic).
- Steps: 12 -> 15 (1.25x).

## Wireframe (880 x ~470)

```
            [ needs-input ]
      questions ^     v human answers, signs off
[Fresh]---(pj-grill-for-specs-readiness)--->[spec-ready]--(pj-implement)-->[Implemented]--human-->[Done]
   :     .  UI change               :   .      (pj-repro bugs) above     :      reviews, merges
(pj-mock-it-up) <.'             (pj-decompose) <.' bite too big   +-PR loop, any order-+
 mockup into attachments     child issues under parent      | pj-review          |
 human picks one                                            | pj-address-review  |
-------------------------------------------------------------------------------------------
Repo level,     (pj-prep-the-repo)      (pj-healthcheck)          (pj-next-round)
not in the flow  once: labels, ...       read-only: setup, ...     read-only: what to run next
```
