#!/usr/bin/env bash
# Writes to a PR that a pj skill opened: an open PR from a pj/* branch of this repo.
# Usage:
#   pr.sh body <pr> <body-file>   replaces the PR body; the first line is the claim marker
#   pr.sh ready <pr>              marks the draft PR as ready for review
# Prints one JSON line. Exit 3: the PR is closed, from a fork, or not on a pj/* branch.

. "$(dirname "$0")/lib.sh"

check_pj() { # <pr>
  local info
  info=$(forge_pr_view "$1" '"\(.state) \(.isCrossRepository) \(.headRefName)"')
  case "$info" in "OPEN false pj/"?*) ;; *) pj_die $PJ_EXIT_ASK not-pj-branch "PR #$1: $info" ;; esac
}

cmd_body() {
  local pr=${1:-} body=${2:-}
  pj_num "$pr"
  [ -f "$body" ] || pj_die $PJ_EXIT_USAGE usage "pr.sh body <pr> <body-file>"
  pj_is_marker "$body" claim || pj_die $PJ_EXIT_USAGE no-marker "The first line of $body must be the claim marker."
  pj_require_main
  check_pj "$pr"
  forge_pr_set_body "$pr" "$body"
  printf '{"ok":true,"pr":%s}\n' "$pr"
}

cmd_ready() {
  local pr=${1:-}
  pj_num "$pr"
  pj_require_main
  check_pj "$pr"
  forge_pr_ready "$pr"
  printf '{"ok":true,"pr":%s}\n' "$pr"
}

case "${1:-}" in
  body) shift; cmd_body "$@" ;;
  ready) shift; cmd_ready "$@" ;;
  *) pj_die $PJ_EXIT_USAGE usage "pr.sh body <pr> <body-file> | ready <pr>" ;;
esac
