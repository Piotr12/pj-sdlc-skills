# pj SDLC skills

Agent skills that take a GitHub or Forgejo issue from spec to a merged PR.
Version 0.2.0 has ten skills. All of them follow one protocol: `skills/pj-prep-the-repo/reference/protocol.md`.

![pj issue flow. A Fresh issue goes to pj-grill-for-specs-readiness. Grill asks questions with the needs-input label. A human answers and signs off the spec. For a UI change, pj-mock-it-up makes mockups, and a human picks one. Then the issue is spec-ready. pj-implement opens a PR, after pj-repro for a bug. pj-decompose splits an issue that is too big. With a PR ready for review, the issue has the Implemented state. pj-review and pj-address-review loop on the PR. A human merges the PR, and the issue gets the Done state. pj-prep-the-repo runs once for each repo. pj-next-round and pj-healthcheck change nothing.](docs/flow.svg)

## Skills

| Skill | Does |
|---|---|
| `pj-prep-the-repo` | Sets up labels, the `attachments` branch, rulesets, the scripts, `AGENTS.md`, and configs through a PR. |
| `pj-grill-for-specs-readiness` | Checks an issue against the Definition of Ready and builds the spec. |
| `pj-implement` | Implements a `spec-ready` issue and opens a PR. |
| `pj-review` | Reviews a PR adversarially. |
| `pj-address-review` | Works through the open review threads on a PR. |
| `pj-next-round` | Suggests the next actions. It changes nothing. |
| `pj-mock-it-up` | Makes mockup variants for a UI change. |
| `pj-decompose` | Splits an issue that is too big into child issues. |
| `pj-repro` | Reproduces a bug with a failing test before the fix. |
| `pj-healthcheck` | Checks the repo setup, `attachments`, and `docs/`. It changes nothing. |

The scripts are in `skills/pj-prep-the-repo/scripts/`. `forge/` holds one adapter for each forge: GitHub and Forgejo.
`pj-prep-the-repo` copies the scripts and the adapter for the repo to `.pj/scripts/`. The other skills use that copy.
Install all skills together.

The Claude Code plugin also adds a guard hook. It blocks pushes to `main`, force-pushes, merges, approvals, issue closes, and `gh`, `fj`, or API writes outside the scripts.

## Requirements

- A GitHub or Forgejo repo with `main` as the default branch.
- GitHub: `gh`, logged in.
- Forgejo: `curl`, `jq`, and a token with write access to the repo. Put it in `FORGEJO_TOKEN`, or run `fj auth add-key <host>`.
- git 2.42 or later. Also install `gitleaks`: it scans attachments for secrets.
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

Manual: copy all `skills/pj-*` folders into the skills folder of your agent.

## Use

1. Install the tools for the forge and log in. Use `git` 2.42 or later.
2. Open the target repo. It must have a GitHub or Forgejo remote named `origin`.
3. Ask the agent to prepare the repo for the pj skills.
4. Review and merge the PR that the agent opens.

For a team, give the agent its own identity on the forge. See Identity in the protocol.
The protocol also lists what differs on Forgejo. See Forges.

## Design

The diagram above is `docs/flow.svg`. It shows the issue states, the skills, and the human steps.
Open `docs/index.html` in a browser for the same diagram, with a link to each `SKILL.md`.
Each skill has its `SKILL.md`. The shared rules are in the protocol.

## Tests

Run `bash tests/prep-scripts.sh`.
It replays the scripts against temporary repos with a fake `gh` and a fake Forgejo API.
It needs no network and no account.

## Writing rules

The Markdown rules use STE-inspired English.
ASD-STE100 is the Simplified Technical English specification of ASD.
This project has no affiliation with ASD and does not claim STE compliance.

## License

MIT. See [LICENSE](LICENSE).
