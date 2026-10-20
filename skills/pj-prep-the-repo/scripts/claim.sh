#!/usr/bin/env bash
# Claims an issue for pj-implement and pj-repro: assignee, branch pj/<n>, worktree .worktrees/<n>,
# and a draft PR with a claim marker. A rerun by the same user resumes the claim.
# Usage: claim.sh <n> [skill]   skill: pj-implement (default) or pj-repro, for the claim marker
# Prints one JSON line. Exit 3: someone else has the claim, or another open PR closes the issue.

. "$(dirname "$0")/lib.sh"

n=${1:-} skill=${2:-pj-implement}
pj_num "$n"
case "$skill" in pj-implement|pj-repro) ;; *) pj_die $PJ_EXIT_USAGE bad-skill "$skill" ;; esac
top=$(pj_top)
cd "$top"
b="pj/$n"
wt="$top/.worktrees/$n"

pj_require_main
pj_fetch
pj_exclude_worktrees >/dev/null
git worktree prune

me=$(gh api user --jq .login)
# Three lines: title, assignees, and "<number>:<head>:<fork>" of each open PR that closes the issue.
info=$(gh api graphql -F owner='{owner}' -F name='{repo}' -F n="$n" -f query='
  query($owner: String!, $name: String!, $n: Int!) { repository(owner: $owner, name: $name) { issue(number: $n) {
    title assignees(first: 20) { nodes { login } }
    closedByPullRequestsReferences(first: 20, includeClosedPrs: false) {
      nodes { number state headRefName isCrossRepository } } } } }' \
  --jq '.data.repository.issue | .title, ([.assignees.nodes[].login] | join(" ")),
    ([.closedByPullRequestsReferences.nodes[] | select(.state == "OPEN")
      | "\(.number):\(.headRefName):\(.isCrossRepository)"] | join(" "))')
title=$(echo "$info" | sed -n 1p)
assignees=$(echo "$info" | sed -n 2p)
closers=$(echo "$info" | sed -n 3p)

for a in $assignees; do
  [ "$a" = "$me" ] || pj_die $PJ_EXIT_ASK claimed-by-other "#$n is assigned to $a."
done
for p in $closers; do
  [ "$p" = "${p%%:*}:$b:false" ] || pj_die $PJ_EXIT_ASK other-pr "PR #${p%%:*} already closes #$n."
done

ours() { pj_prs | awk -v b="$b" -v me="$me" '$2 == "OPEN" && $3 == b && $5 != "true" && $6 == me {print; exit}'; }

cur=$(wt_branch "$wt")
if [ "$cur" = "$b" ]; then
  action=resumed
elif wt_registered "$wt" || ! pj_wt_free "$wt"; then
  pj_die $PJ_EXIT_ASK path-in-use "$wt is not a worktree on $b."
elif git ls-remote --exit-code --heads origin "$b" >/dev/null 2>&1; then
  [ -n "$(ours)" ] || pj_die $PJ_EXIT_ASK claimed-by-other "origin has $b, and it has no open PR by $me."
  git fetch -q origin "+refs/heads/$b:refs/remotes/origin/$b"
  if pj_has_ref "refs/heads/$b"; then git worktree add -q "$wt" "$b"
  else git worktree add -q --track -b "$b" "$wt" "origin/$b"; fi
  git -C "$wt" merge -q --ff-only "origin/$b" >/dev/null 2>&1 || true
  action=resumed
else
  # A local pj/<n> without a remote branch is a crash leftover of this user: push it.
  if pj_has_ref "refs/heads/$b"; then git worktree add -q "$wt" "$b"
  else git worktree add -q -b "$b" "$wt" "origin/$PJ_MAIN"; fi
  if [ "$(git -C "$wt" rev-list --count "origin/$PJ_MAIN..HEAD")" -eq 0 ]; then
    git -C "$wt" -c core.hooksPath=/dev/null -c commit.gpgsign=false commit -q --allow-empty -m "chore: claim #$n"
  fi
  git -C "$wt" push -q -u origin "$b" 2>/dev/null || pj_die $PJ_EXIT_ASK claimed-by-other "origin rejected the push of $b."
  action=created
fi

case " $assignees " in *" $me "*) ;; *) gh issue edit "$n" --add-assignee @me >/dev/null ;; esac

mk=$("$(dirname "$0")/marker.sh" "$skill" claim "issue=$n")
run=$(echo "$mk" | sed -n 's/.*"run":"\([^"]*\)".*/\1/p')
pr=$(ours | awk '{print $4}')
if [ -z "$pr" ]; then
  tmp=$(mktemp "${TMPDIR:-/tmp}/pj-claim.XXXXXX")
  pj_cleanup() { rm -f "$tmp"; }
  # The marker holds only plain values here, so unescaping the quotes is enough.
  m=$(echo "$mk" | sed -n 's/.*"marker":"\(.*\)","run".*/\1/p' | sed 's/\\"/"/g')
  printf '%s\n\nCloses #%s\n\nWork in progress.\n' "$m" "$n" > "$tmp"
  pr=$(gh pr create --draft --base "$PJ_MAIN" --head "$b" --title "$title" --body-file "$tmp")
fi

printf '{"ok":true,"action":"%s","worktree":".worktrees/%s","branch":"%s","pr":%s,"run":"%s"}\n' \
  "$action" "$n" "$b" "$(pj_json "$pr")" "$run"
