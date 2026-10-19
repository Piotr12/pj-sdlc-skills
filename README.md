# pj SDLC skills

Agent skills that take a GitHub issue from spec to a merged PR.
The agent works in worktrees and PRs.
A human answers the questions, picks the mockups, and merges.

Version 0.1.0. One skill is ready. The other skills are designs.

## Skills

| Skill | Status | Does |
|---|---|---|
| `pj-prep-the-repo` | Ready | Sets up labels, the `attachments` branch, `AGENTS.md`, and configs through a PR. |
| `pj-grill-for-specs-readiness` | Planned | Checks an issue against the Definition of Ready and builds the spec. |
| `pj-mock-it-up` | Planned | Makes mockup variants for a UI change. |
| `pj-decompose` | Planned | Splits an issue that is too big into child issues. |
| `pj-repro` | Planned | Reproduces a bug with a failing test before the fix. |
| `pj-implement` | Planned | Implements a `spec-ready` issue and opens a PR. |
| `pj-review` | Planned | Reviews a PR adversarially. |
| `pj-address-review` | Planned | Works through the open review threads on a PR. |
| `pj-next-round` | Planned | Suggests the next actions. It changes nothing. |
| `pj-healthcheck` | Planned | Checks the repo setup, `attachments`, and `docs/`. It changes nothing. |

## Install

Claude Code:

```sh
/plugin marketplace add Piotr12/pj-sdlc-skills
/plugin install pj-sdlc-skills@pj-sdlc-skills
```

Other agents that read the Agent Skills format:

```sh
npx skills add Piotr12/pj-sdlc-skills
```

Manual: copy `skills/pj-*` into the skills folder of your agent.

## Use

1. Install `gh` and log in. Use `git` 2.42 or later.
2. Open the target repo. It must have a GitHub remote.
3. Ask the agent to prepare the repo for the pj skills.
4. Review and merge the PR that the agent opens.

## Design

Open `docs/index.html` in a browser.
It shows the issue states, the skills, the worktrees, and the devlog.
`docs/skills/` has one page for each skill.
For a built skill, `SKILL.md` is the source of truth.

## Tests

Run `bash tests/prep-scripts.sh`.
It replays the prep scripts against temporary repos with a fake `gh`.
It needs no network and no GitHub account.

## Writing rules

The Markdown rules use STE-inspired English.
ASD-STE100 is the Simplified Technical English specification of ASD.
This project has no affiliation with ASD and does not claim STE compliance.

## License

MIT. See [LICENSE](LICENSE).
