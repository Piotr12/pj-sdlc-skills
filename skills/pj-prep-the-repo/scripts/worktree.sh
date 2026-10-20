#!/usr/bin/env bash
# Worktrees of the protocol. Skills never work in the main checkout.
# Usage:
#   worktree.sh pr <pr>        worktree on the PR branch: .worktrees/<n> for pj/<n>, else .worktrees/pr-<pr>
#   worktree.sh review <pr>    fresh detached worktree .worktrees/review-<pr> at the PR head
#   worktree.sh remove <path>  removes a worktree under .worktrees/
# Prints one JSON line. Exit 3: a fork PR, or the path holds something else.

. "$(dirname "$0")/lib.sh"

top=$(pj_top)
cd "$top"

cmd_pr() {
  local pr=${1:-} info head fork rel wt cur action push=false
  pj_num "$pr"
  pj_need_forge
  info=$(forge_pr_view "$pr" '"\(.headRefName) \(.isCrossRepository)"')
  head=${info% *}; fork=${info##* }
  [ "$fork" = false ] || pj_die $PJ_EXIT_ASK fork-pr "PR #$pr comes from a fork. Review the diff only."
  case "$head" in pj/*[!0-9]*|pj/) rel=".worktrees/pr-$pr" ;; pj/*) rel=".worktrees/${head#pj/}" ;; *) rel=".worktrees/pr-$pr" ;; esac
  case "$head" in pj/*) push=true ;; esac
  wt="$top/$rel"
  pj_exclude_worktrees >/dev/null
  git worktree prune
  git fetch -q origin "+refs/heads/$head:refs/remotes/origin/$head"
  cur=$(wt_branch "$wt")
  if [ "$cur" = "$head" ]; then
    action=reused
  elif wt_registered "$wt" || ! pj_wt_free "$wt"; then
    pj_die $PJ_EXIT_ASK path-in-use "$wt is not a worktree on $head."
  else
    if pj_has_ref "refs/heads/$head"; then git worktree add -q "$wt" "$head"
    else git worktree add -q --track -b "$head" "$wt" "origin/$head"; fi
    action=created
  fi
  git -C "$wt" merge -q --ff-only "origin/$head" >/dev/null 2>&1 || true
  printf '{"ok":true,"action":"%s","worktree":"%s","branch":%s,"push":%s}\n' "$action" "$rel" "$(pj_json "$head")" "$push"
}

cmd_review() {
  local pr=${1:-} rel wt ref
  pj_num "$pr"
  rel=".worktrees/review-$pr"; wt="$top/$rel"; ref="refs/pj/review/$pr"
  pj_exclude_worktrees >/dev/null
  git fetch -q origin "+refs/pull/$pr/head:$ref"
  if wt_registered "$wt"; then git worktree remove --force "$wt"
  elif ! pj_wt_free "$wt"; then pj_die $PJ_EXIT_ASK path-in-use "$wt"; fi
  git worktree prune
  git worktree add -q --detach "$wt" "$ref"
  printf '{"ok":true,"worktree":"%s","sha":"%s"}\n' "$rel" "$(git rev-parse "$ref")"
}

cmd_remove() {
  local p=${1:-} removed="" name
  case "$p" in /*) ;; *) p="$top/${p#./}" ;; esac
  case "$p" in "$top/.worktrees/"?*) ;; *) pj_die $PJ_EXIT_USAGE outside-worktrees "${1:-}" ;; esac
  case "$p" in *..*) pj_die $PJ_EXIT_USAGE outside-worktrees "${1:-}" ;; esac
  p=${p%/}
  name=${p##*/}
  if wt_registered "$p"; then git worktree remove --force "$p"; removed=${p#"$top/"}; fi
  git worktree prune
  case "$name" in review-*) git update-ref -d "refs/pj/review/${name#review-}" 2>/dev/null || true ;; esac
  printf '{"ok":true,"removed":%s}\n' "$(pj_json "$removed")"
}

case "${1:-}" in
  pr) shift; cmd_pr "$@" ;;
  review) shift; cmd_review "$@" ;;
  remove) shift; cmd_remove "$@" ;;
  *) pj_die $PJ_EXIT_USAGE usage "worktree.sh pr <pr> | review <pr> | remove <path>" ;;
esac
