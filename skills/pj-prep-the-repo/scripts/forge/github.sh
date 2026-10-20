# GitHub adapter of the pj scripts, through gh. Sourced by lib.sh; do not run it.
# Each forge adapter defines the same forge_* functions. Reads that end in <jq> take a jq
# program and print its raw output. The input of the program has the shape of the GitHub
# GraphQL objects below: the shared jq in the scripts works on all forges.

PJ_FORGE_NAME=github
PJ_FORGE_CLI=gh

forge_cli_ok() { command -v gh >/dev/null; }
forge_auth_ok() { gh auth status >/dev/null 2>&1; }
forge_me() { gh api user --jq .login; }
# Raw URL of a file on the attachments branch.
forge_raw_url() { gh repo view --json url --jq ".url + \"/blob/$PJ_ATT/$1?raw=true\""; } # <path>

forge_labels() { gh label list --limit 1000 --json name --jq '.[].name'; }
forge_label_create() { gh label create "$1" --color "$2" --description "$3" >/dev/null; } # <name> <hex> <desc>

# Server-side branch rules: rulesets, from templates/rulesets/<name>.json.
forge_protections() { gh api 'repos/{owner}/{repo}/rulesets' --jq '.[].name'; }
forge_protection_create() { gh api -X POST 'repos/{owner}/{repo}/rulesets' --input "$PJ_TEMPLATES/rulesets/$1.json"; } # <pj name>

PJ_GH_ACTOR='author { login } authorAssociation'
PJ_GH_ISSUE="number title state body url createdAt $PJ_GH_ACTOR
  labels(first: 50) { nodes { name } } assignees(first: 20) { nodes { login } }
  closedByPullRequestsReferences(first: 20, includeClosedPrs: false) {
    nodes { number isDraft state headRefName isCrossRepository } }
  subIssues { totalCount }
  comments(last: 100) { nodes { url $PJ_GH_ACTOR createdAt body } }"
PJ_GH_PR="number title state isDraft body url createdAt $PJ_GH_ACTOR
  isCrossRepository headRefName headRefOid additions deletions
  closingIssuesReferences(first: 20) { nodes { number } }
  comments(last: 100) { nodes { url $PJ_GH_ACTOR createdAt body } }
  reviews(last: 100) { nodes { url $PJ_GH_ACTOR createdAt body state commit { oid } } }
  reviewThreads(first: 100) { nodes { id path line isResolved
    comments(first: 100) { nodes { databaseId url $PJ_GH_ACTOR createdAt body } } } }"

forge_issue_full() { # <n> <jq>
  gh api graphql -F owner='{owner}' -F name='{repo}' -F n="$1" -f query="
    query(\$owner: String!, \$name: String!, \$n: Int!) { repository(owner: \$owner, name: \$name) {
      issue(number: \$n) { $PJ_GH_ISSUE } } }" --jq ".data.repository.issue | $2"
}
forge_pr_full() { # <n> <jq>
  gh api graphql -F owner='{owner}' -F name='{repo}' -F n="$1" -f query="
    query(\$owner: String!, \$name: String!, \$n: Int!) { repository(owner: \$owner, name: \$name) {
      pullRequest(number: \$n) { $PJ_GH_PR } } }" --jq ".data.repository.pullRequest | $2"
}

# [{number title state labels[{name}] assignees[{login}] author{login} createdAt body url}]
forge_issue_list() { # <open|all> <limit> <jq>
  gh issue list --state "$1" --limit "$2" --json number,title,state,labels,assignees,author,createdAt,body,url --jq "$3"
}
forge_issue_body() { # <n> <file>: the exact body
  local b
  # gh adds a newline after the body: the "." keeps the real trailing newlines, then goes.
  b=$(gh issue view "$1" --json body --jq '(.body // "") + "."')
  printf '%s' "${b%.}" > "$2"
}
forge_issue_set_body() { gh issue edit "$1" --body-file "$2" >/dev/null; } # <n> <file>
forge_issue_labels() { gh issue view "$1" --json labels --jq '.labels[].name'; } # <n>
forge_issue_relabel() { # <n> <add> [remove]
  if [ -n "${3:-}" ]; then gh issue edit "$1" --add-label "$2" --remove-label "$3" >/dev/null
  else gh issue edit "$1" --add-label "$2" >/dev/null; fi
}
forge_issue_create() { gh issue create --title "$1" --body-file "$2"; } # <title> <body-file> -> url
forge_issue_assign_me() { gh issue edit "$1" --add-assignee @me >/dev/null; } # <n>
forge_issue_link_child() { # <parent> <child>
  local id
  id=$(gh api "repos/{owner}/{repo}/issues/$2" --jq .id 2>/dev/null) \
    && gh api -X POST "repos/{owner}/{repo}/issues/$1/sub_issues" -F sub_issue_id="$id" >/dev/null 2>&1
}
forge_comment() { gh "$1" comment "$2" --body-file "$3"; } # <issue|pr> <n> <body-file> -> url

# [{number state isDraft headRefName url isCrossRepository author{login} createdAt closingIssuesReferences[{number}]}]
# state: OPEN, CLOSED, or MERGED.
forge_pr_list() { # <open|all> <limit> <jq>
  gh pr list --state "$1" --limit "$2" \
    --json number,state,isDraft,headRefName,url,isCrossRepository,author,createdAt,closingIssuesReferences --jq "$3"
}
forge_pr_view() { gh pr view "$1" --json state,isCrossRepository,headRefName,headRefOid --jq "$2"; } # <n> <jq>
forge_pr_create() { # <head> <base> <title> <body-file> [draft] -> url
  if [ "${5:-}" = draft ]; then gh pr create --draft --base "$2" --head "$1" --title "$3" --body-file "$4"
  else gh pr create --base "$2" --head "$1" --title "$3" --body-file "$4"; fi
}
forge_pr_set_body() { gh pr edit "$1" --body-file "$2" >/dev/null; } # <n> <file>
forge_pr_ready() { gh pr ready "$1" >/dev/null; } # <n>
forge_pr_diff() { gh pr diff "$1"; } # <n>

# A COMMENT review on the head commit. comments: [{"path","line","side"?,"body"}]. Prints "<id> <url>".
forge_review_post() { # <pr> <body-file> <comments-json>
  local sha tmp
  sha=$(gh pr view "$1" --json headRefOid --jq .headRefOid)
  tmp=$(mktemp "${TMPDIR:-/tmp}/pj-review.XXXXXX")
  printf '{"event":"COMMENT","commit_id":%s,"body":%s,"comments":%s}\n' \
    "$(pj_json "$sha")" "$(pj_json "$(cat "$2")")" "$3" > "$tmp"
  gh api -X POST "repos/{owner}/{repo}/pulls/$1/reviews" --input "$tmp" --jq '"\(.id) \(.html_url)"'
  rm -f "$tmp"
}
forge_review_reply() { # <pr> <comment-id> <body-file> -> id
  gh api -X POST "repos/{owner}/{repo}/pulls/$1/comments/$2/replies" -F body=@"$3" --jq .id
}
forge_thread_first_body() { # <pr> <thread-id>
  gh api graphql -F id="$2" -f query='query($id: ID!) { node(id: $id) {
      ... on PullRequestReviewThread { comments(first: 1) { nodes { body } } } } }' \
    --jq '.data.node.comments.nodes[0].body // ""'
}
forge_thread_resolve() { # <pr> <thread-id> -> id
  gh api graphql -F id="$2" -f query='mutation($id: ID!) {
      resolveReviewThread(input: {threadId: $id}) { thread { id } } }' --jq .data.resolveReviewThread.thread.id
}
