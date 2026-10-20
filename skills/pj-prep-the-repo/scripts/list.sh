#!/usr/bin/env bash
# Read-only lists for the skills: open issues, open PRs, and labels. --all adds closed items.
# Usage: list.sh issues [--all] | prs [--all] | labels
# Prints one JSON line.

. "$(dirname "$0")/lib.sh"

state=open
[ "${2:-}" = --all ] && state=all

cmd_issues() {
  pj_need_forge
  forge_issue_list "$state" 500 '{ok: true, issues: [.[] | ((.body // "") | gsub("\r"; "") | split("\n")) as $L | {number, title, state,
      labels: [.labels[].name], assignees: [.assignees[].login], author: (.author.login // "ghost"), createdAt,
      dependsOn: [$L[] | select(test("^Depends on:?\\s")) | scan("#([0-9]+)") | .[0] | tonumber],
      parent: ([$L[] | select(test("^Parent: #[0-9]+")) | capture("^Parent: #(?<n>[0-9]+)").n | tonumber] | first)}]} | tojson'
}

cmd_prs() {
  pj_need_forge
  forge_pr_list "$state" 500 '{ok: true, prs: [.[] | {number, state, isDraft, head: .headRefName, fork: .isCrossRepository,
      author: (.author.login // "ghost"), createdAt, issues: [.closingIssuesReferences[].number]}]} | tojson'
}

cmd_labels() {
  local have names="" missing="" l
  pj_need_forge
  have=$(forge_labels)
  while read -r l; do [ -n "$l" ] && names="$names,$(pj_json "$l")"; done <<< "$have"
  for l in needs-input spec-ready; do echo "$have" | grep -qxF "$l" || missing="$missing,\"$l\""; done
  printf '{"ok":true,"labels":[%s],"missing":[%s]}\n' "${names#,}" "${missing#,}"
}

case "${1:-}" in
  issues) cmd_issues ;;
  prs) cmd_prs ;;
  labels) cmd_labels ;;
  *) pj_die $PJ_EXIT_USAGE usage "list.sh issues [--all] | prs [--all] | labels" ;;
esac
