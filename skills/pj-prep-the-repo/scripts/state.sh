#!/usr/bin/env bash
# Read-only protocol state of an issue or a PR, from labels, markers, and author associations.
# Usage: state.sh issue <n> | pr <n>
#   issue: labels, assignees, open PRs, markers, trusted answers after the last marker, untrusted
#          comments in the same window, highest Q-number, spec block present, sub-issue count.
#   pr:    draft, fork, author trust, head, size, linked issues, review rounds, actionable threads.
# Prints one JSON line. It never prints comment text.

. "$(dirname "$0")/lib.sh"

cd "$(pj_top)"
pj_need_forge
T=$(pj_trusted_jq)

cmd_issue() {
  local n=${1:-}
  pj_num "$n"
  forge_issue_full "$n" "$PJ_JQ_DEFS $T as \$T | . as \$i | \$i.comments.nodes as \$c
      | [\$c[] | (.body | mk) as \$m | select(\$m != null)
          | {event: \$m.event, skill: (\$m.skill // \"\"), run: (\$m.run // \"\"), round: (\$m.round // null),
             spec: (\$m.spec // \"\"), reason: (\$m.reason // \"\"), author: who, at: .createdAt, url}] as \$mk
      | ((\$mk | last | .at) // \"\") as \$last
      | [\$c[] | select((.body | mk) == null and .createdAt > \$last)] as \$win
      | (\$i.body | gsub(\"\r\"; \"\") | split(\"\n\")) as \$L
      | {ok: true, number: \$i.number, title: \$i.title, state: \$i.state, author: (\$i | who),
         labels: [\$i.labels.nodes[].name], assignees: [\$i.assignees.nodes[].login],
         openPrs: [\$i.closedByPullRequestsReferences.nodes[] | select(.state == \"OPEN\") | {number, isDraft}],
         markers: \$mk, lastMarkerAt: \$last,
         answers: [\$win[] | select(.authorAssociation | IN(\$T[])) | {author: who, at: .createdAt, url}],
         untrusted: [\$win[] | select(.authorAssociation | IN(\$T[]) | not) | {author: who, at: .createdAt, url}],
         maxQ: ([\$c[].body | scan(\"Q-([0-9]{3,})\") | .[0] | tonumber] | max // 0),
         hasSpec: (any(\$L[]; . == \"<!-- pj:spec:start -->\") and any(\$L[]; . == \"<!-- pj:spec:end -->\")),
         children: (\$i.subIssues.totalCount // 0)} | tojson"
}

cmd_pr() {
  local n=${1:-}
  pj_num "$n"
  forge_pr_full "$n" "$PJ_JQ_DEFS $T as \$T | . as \$p
      | [\$p.reviews.nodes[] | select(.body | is(\"review\"))] as \$rv
      | ((\$rv | last | .commit.oid) // \"\") as \$rs
      | {ok: true, number: \$p.number, state: \$p.state, isDraft: \$p.isDraft, fork: \$p.isCrossRepository,
         author: (\$p | who), authorTrusted: (\$p.authorAssociation | IN(\$T[])),
         head: \$p.headRefName, headSha: \$p.headRefOid, additions: \$p.additions, deletions: \$p.deletions,
         issues: [\$p.closingIssuesReferences.nodes[].number],
         rounds: (\$rv | length), lastReviewSha: \$rs, newCommits: (\$p.headRefOid != \$rs),
         threads: [\$p.reviewThreads.nodes[] | select(.isResolved | not)
           | .comments.nodes[0] as \$h | .comments.nodes[-1] as \$t | select(\$t.body | is(\"reply\") | not)
           | {id, commentId: \$h.databaseId, path, line, pj: (\$h.body | is(\"review\")),
              lastAuthor: (\$t | who), lastTrusted: (\$t.authorAssociation | IN(\$T[])), url: \$h.url}]} | tojson"
}

case "${1:-}" in
  issue) shift; cmd_issue "$@" ;;
  pr) shift; cmd_pr "$@" ;;
  *) pj_die $PJ_EXIT_USAGE usage "state.sh issue <n> | pr <n>" ;;
esac
