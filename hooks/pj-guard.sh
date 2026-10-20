#!/usr/bin/env bash
# PreToolUse hook (Claude Code). Reads the tool call as JSON on stdin.
# Exit 2 blocks the call and shows the reason to the agent. Exit 0 allows it.
# Active only in a repo with .pj/config.json. It matches the raw JSON, so it errs on the side of blocking.

top=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -f "$top/.pj/config.json" ] || exit 0
in=$(cat)

deny() { echo "pj guard: $1. This is a human action (AGENTS.md, Autonomy)." >&2; exit 2; }
raw() { echo "pj guard: raw gh write ($1). Use the pj scripts in pj-prep-the-repo/scripts." >&2; exit 2; }
has() { printf '%s' "$in" | grep -Eq -- "$1"; }
# gh as a command word: at the start, after a separator or quote, or as the last part of a path.
GH='(^|[^[:alnum:]_.-])gh[[:space:]]+'
END='([[:space:]]|"|$)'

if has 'git[^"]*[[:space:]]push'; then
  has 'push[^"]*[[:space:]](-f|--force|--force-with-lease|--force-if-includes|--mirror)([[:space:]=]|")' && deny "force push"
  has 'push[^"]*[[:space:]]\+[^[:space:]"]+' && deny "force push (+refspec)"
  has 'push[^"]*[[:space:]](-d|--delete)([[:space:]]|")' && deny "branch deletion"
  has 'push[^"]*[[:space:]]:[^[:space:]"]+' && deny "branch deletion (:refspec)"
  has 'push[^"]*[[:space:]]([^[:space:]":]*:)?(refs/heads/)?main([[:space:]]|")' && deny "push to main"
fi
has 'gh[[:space:]]+pr[[:space:]]+merge' && deny "merging a PR"
has 'gh[[:space:]]+issue[[:space:]]+close' && deny "closing an issue"
has 'gh[[:space:]]+pr[[:space:]]+review[^"]*[[:space:]](-a|--approve|-r|--request-changes)([[:space:]=]|")' \
  && deny "approving or requesting changes on a PR"
has 'gh[[:space:]]+(secret|variable)[[:space:]]+(set|delete|remove)' && deny "changing secrets or variables"
has 'gh[[:space:]]+(repo|release)[[:space:]]+delete' && deny "deleting a repo or release"
has 'gh[[:space:]]+api[^"]*(-X|--method)[[:space:]]*(DELETE|delete)' && deny "a DELETE call to the GitHub API"
has 'gh[[:space:]]+api[^"]*rulesets[^"]*(-X|--method)[[:space:]]*(POST|PUT|PATCH)' && deny "changing rulesets (use prep.sh rulesets)"
has '\.github/workflows/' && has '(>|tee|cp|mv|rm|sed -i|git add)' && deny "changing CI workflows"
# The pj scripts call gh themselves. The hook sees only the command line of the agent.
has "${GH}(issue|pr)[[:space:]]+(create|edit|comment|ready|review|close|reopen|lock|unlock|delete|merge|transfer|pin|unpin)$END" \
  && raw "gh issue or gh pr"
has "${GH}label[[:space:]]+(create|edit|delete|clone)$END" && raw "gh label"
if has "${GH}api$END"; then
  has 'api[^"]*[[:space:]](-X|--method)[[:space:]=]*(POST|PATCH|PUT|DELETE|post|patch|put|delete)' && raw "gh api with a write method"
  has 'api[^"]*[[:space:]](-f|-F|--field|--raw-field|--input)([[:space:]=]|")' && raw "gh api with fields"
fi
exit 0
