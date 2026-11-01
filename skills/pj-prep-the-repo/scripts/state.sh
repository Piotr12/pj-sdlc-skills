#!/usr/bin/env bash
# Read-only protocol state of an issue or a PR, from labels, markers, and author associations.
# Usage: state.sh issue <n> | pr <n>
#   issue: labels, assignees, open PRs, markers, trusted answers after the last marker, untrusted
#          comments in the same window, highest Q-number, spec block present, sub-issue count,
#          the pj-handhold delegation. The window ignores delegate and answer markers. Under a
#          delegation, answer comments after the delegate marker count as answers (delegated: true).
#   pr:    draft, fork, author trust, head, size, linked issues, review rounds, actionable threads,
#          blocking count of the last review, threads that wait for an answer to an ask reply.
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
             spec: (\$m.spec // \"\"), reason: (\$m.reason // \"\"), sha: (\$m.sha // \"\"), author: who, at: .createdAt, url}] as \$mk
      | ([\$c[] | select((.body | is(\"delegate\")) and trusted(\$T))] | last) as \$dg
      | ((\$dg // {}).createdAt // \"\") as \$dgAt
      | ([\$mk[] | select(.event | IN(\"delegate\", \"answer\") | not)] | last | .at // \"\") as \$last
      | [\$c[] | select(.createdAt > \$last) | (.body | mk) as \$m
          | select(\$m == null or (\$m.event == \"answer\" and \$dg != null and .createdAt > \$dgAt))
          | . + {delegated: (\$m != null)}] as \$win
      | (\$i.body | gsub(\"\r\"; \"\") | split(\"\n\")) as \$L
      | {ok: true, number: \$i.number, title: \$i.title, state: \$i.state, author: (\$i | who),
         authorTrusted: (\$i | trusted(\$T)),
         labels: [\$i.labels.nodes[].name], assignees: [\$i.assignees.nodes[].login],
         openPrs: [\$i.closedByPullRequestsReferences.nodes[] | select(.state == \"OPEN\") | {number, isDraft}],
         markers: \$mk, lastMarkerAt: \$last,
         delegation: (if \$dg == null then null else (\$dg.body | mk) as \$d | {by: (\$d.by // \"\"), run: (\$d.run // \"\"), at: \$dgAt,
           active: ([\$mk[] | select(.skill == \"pj-handhold\" and (.event | IN(\"done\", \"stopped\")) and .at > \$dgAt)] | length == 0)} end),
         answers: [\$win[] | select(trusted(\$T)) | {author: who, at: .createdAt, url, delegated}],
         untrusted: [\$win[] | select(trusted(\$T) | not) | {author: who, at: .createdAt, url}],
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
         lastBlocking: ((\$rv | last | (.body // \"\") | mk | .blocking) // null),
         asked: [\$p.reviewThreads.nodes[] | select(.isResolved | not) | .comments.nodes[0] as \$h
           | (.comments.nodes[-1].body // \"\" | mk) as \$m | select(\$m != null and \$m.event == \"reply\" and \$m.kind == \"ask\")
           | {id, commentId: \$h.databaseId, path, line, url: \$h.url}],
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
