# pj SDLC skills

A design for agent skills that take a GitHub issue from spec to a merged PR, and its first skill.
Version 0.1.0 ships one skill: `pj-prep-the-repo`. It prepares a repo for the flow.
The other skills are designs in `docs/`. They are not built yet.

## Shipped

| Skill | Does |
|---|---|
| `pj-prep-the-repo` | Sets up labels, the `attachments` branch, rulesets, `AGENTS.md`, and configs through a PR. |

The Claude Code plugin also adds a guard hook. It blocks pushes to `main`, force-pushes, merges, and issue closes by the agent.

## Roadmap

| Skill | Does |
|---|---|
| `pj-grill-for-specs-readiness` | Checks an issue against the Definition of Ready and builds the spec. |
| `pj-implement` | Implements a `spec-ready` issue and opens a PR. |
| `pj-review` | Reviews a PR adversarially. |
| `pj-address-review` | Works through the open review threads on a PR. |
| `pj-next-round` | Suggests the next actions. It changes nothing. |
| `pj-mock-it-up` | Makes mockup variants for a UI change. |
| `pj-decompose` | Splits an issue that is too big into child issues. |
| `pj-repro` | Reproduces a bug with a failing test before the fix. |
| `pj-healthcheck` | Checks the repo setup, `attachments`, and `docs/`. It changes nothing. |

## Requirements

- A GitHub repo with `main` as the default branch.
- `gh`, logged in, and git 2.42 or later. Also install `gitleaks`: it scans attachments for secrets.
- Bash 3.2 or later. The scripts run on macOS and Linux.
- The rules block targets Web (TypeScript) and Flutter projects.

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

For a team, give the agent its own GitHub identity. See Identity in `docs/index.html`.

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
