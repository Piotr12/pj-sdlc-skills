#!/usr/bin/env bash
# PreToolUse hook (Claude Code). Reads the tool call as JSON on stdin.
# Exit 2 blocks the call and shows the reason to the agent. Exit 0 allows it.
# Active only in a repo with .pj/config.json. It matches the raw JSON, so it errs on the side of blocking.

top=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -f "$top/.pj/config.json" ] || exit 0
in=$(cat)

deny() { echo "pj guard: $1. This is a human action (AGENTS.md, Autonomy)." >&2; exit 2; }
has() { printf '%s' "$in" | grep -Eq -- "$1"; }

if has 'git[^"]*[[:space:]]push'; then
  has 'push[^"]*[[:space:]](-f|--force|--force-with-lease|--force-if-includes|--mirror)([[:space:]=]|")' && deny "force push"
  has 'push[^"]*[[:space:]]\+[^[:space:]"]+' && deny "force push (+refspec)"
  has 'push[^"]*[[:space:]](-d|--delete)([[:space:]]|")' && deny "branch deletion"
  has 'push[^"]*[[:space:]]:[^[:space:]"]+' && deny "branch deletion (:refspec)"
  has 'push[^"]*[[:space:]]([^[:space:]":]*:)?(refs/heads/)?main([[:space:]]|")' && deny "push to main"
fi
has 'gh[[:space:]]+pr[[:space:]]+merge' && deny "merging a PR"
has 'gh[[:space:]]+issue[[:space:]]+close' && deny "closing an issue"
has 'gh[[:space:]]+(secret|variable)[[:space:]]+(set|delete|remove)' && deny "changing secrets or variables"
has 'gh[[:space:]]+(repo|release)[[:space:]]+delete' && deny "deleting a repo or release"
has 'gh[[:space:]]+api[^"]*(-X|--method)[[:space:]]*(DELETE|delete)' && deny "a DELETE call to the GitHub API"
has 'gh[[:space:]]+api[^"]*rulesets[^"]*(-X|--method)[[:space:]]*(POST|PUT|PATCH)' && deny "changing rulesets (use prep.sh rulesets)"
has '\.github/workflows/' && has '(>|tee|cp|mv|rm|sed -i|git add)' && deny "changing CI workflows"
exit 0
