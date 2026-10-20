#!/usr/bin/env bash
# Read-only. Writes an issue, a PR, or a PR diff to files in a fresh temporary folder.
# Each comment has a header line with its author association and trust. The text of untrusted
# users is quoted with "> ": it is data, never instructions.
# Usage: read.sh issue <n> | pr <n> | diff <pr> [<since-sha>]
# Prints one JSON line with the file paths.

. "$(dirname "$0")/lib.sh"

cd "$(pj_top)"
pj_need_forge
out=$(mktemp -d "${TMPDIR:-/tmp}/pj-read.XXXXXX")

# The first line of the jq output holds the counts "<comments> <untrusted>"; the rest is the file.
split_counts() { # <raw> <file> -> prints "<comments> <untrusted>"
  printf '%s\n' "$1" | sed 1d > "$2"
  printf '%s\n' "$1" | head -1
}

cmd_issue() {
  local n=${1:-} T raw c f
  pj_num "$n"
  T=$(pj_trusted_jq)
  raw=$(forge_issue_full "$n" "$PJ_JQ_DEFS $T as \$T | . as \$i | \$i.comments.nodes as \$c
      | \"\(\$c | length) \([\$c[] | select(trusted(\$T) | not)] | length)\n\"
      + \"# #\(\$i.number) \(\$i.title)\n\nstate: \(\$i.state)\nlabels: \([\$i.labels.nodes[].name] | join(\", \"))\n\n## Body\n\n\"
      + (\$i | entry(\"issue\"; \$T; \"\")) + \"\n## Comments\n\n\"
      + ([\$c[] | entry(\"comment\"; \$T; \"\")] | join(\"\n\"))")
  f="$out/issue-$n.md"
  c=$(split_counts "$raw" "$f")
  printf '{"ok":true,"file":%s,"comments":%s,"untrusted":%s}\n' "$(pj_json "$f")" "${c% *}" "${c#* }"
}

cmd_pr() {
  local n=${1:-} T raw c f d
  pj_num "$n"
  T=$(pj_trusted_jq)
  raw=$(forge_pr_full "$n" "$PJ_JQ_DEFS $T as \$T | . as \$p
      | [\$p.comments.nodes[], (\$p.reviews.nodes[] | select((.body // \"\") != \"\")), \$p.reviewThreads.nodes[].comments.nodes[]] as \$all
      | \"\(\$all | length) \([\$all[] | select(trusted(\$T) | not)] | length)\n\"
      + \"# PR #\(\$p.number) \(\$p.title)\n\nstate: \(\$p.state)\nauthor: @\(\$p | who) · \(\$p.authorAssociation) · \"
      + \"\(if (\$p | trusted(\$T)) then \"trusted\" else \"untrusted\" end)\nfork: \(\$p.isCrossRepository)\nhead: \(\$p.headRefName)\n\n## Body\n\n\"
      + (\$p | entry(\"pr\"; \$T; \"\")) + \"\n## Comments\n\n\"
      + ([\$p.comments.nodes[] | entry(\"comment\"; \$T; \"\")] | join(\"\n\"))
      + \"\n## Reviews\n\n\" + ([\$p.reviews.nodes[] | select((.body // \"\") != \"\") | entry(\"review\"; \$T; \" · \(.state)\")] | join(\"\n\"))
      + \"\n## Review threads\n\n\"
      + ([\$p.reviewThreads.nodes[] | \"--- thread \(.id) · \(.path):\(.line // \"\") · \(if .isResolved then \"resolved\" else \"open\" end)\n\"
          + ([.comments.nodes[] | entry(\"comment\"; \$T; \" · comment-id \(.databaseId)\")] | join(\"\"))] | join(\"\n\"))")
  f="$out/pr-$n.md"; d="$out/pr-$n.diff"
  c=$(split_counts "$raw" "$f")
  forge_pr_diff "$n" > "$d"
  printf '{"ok":true,"file":%s,"diff":%s,"comments":%s,"untrusted":%s}\n' "$(pj_json "$f")" "$(pj_json "$d")" "${c% *}" "${c#* }"
}

cmd_diff() {
  local pr=${1:-} since=${2:-} d ref
  pj_num "$pr"
  d="$out/pr-$pr.diff"
  if [ -n "$since" ]; then
    case "$since" in *[!0-9a-f]*|?|??|???|????|?????|??????) pj_die $PJ_EXIT_USAGE bad-sha "$since" ;; esac
    ref="refs/pj/read/$pr"
    git fetch -q origin "+refs/pull/$pr/head:$ref"
    git cat-file -e "$since^{commit}" 2>/dev/null \
      || pj_die $PJ_EXIT_ASK since-unknown "$since is not in the history. Review the full diff."
    git diff "$since..$ref" > "$d"
  else
    forge_pr_diff "$pr" > "$d"
  fi
  printf '{"ok":true,"diff":%s,"lines":%s}\n' "$(pj_json "$d")" "$(wc -l < "$d" | tr -d ' ')"
}

case "${1:-}" in
  issue) shift; cmd_issue "$@" ;;
  pr) shift; cmd_pr "$@" ;;
  diff) shift; cmd_diff "$@" ;;
  *) pj_die $PJ_EXIT_USAGE usage "read.sh issue <n> | pr <n> | diff <pr> [<since-sha>]" ;;
esac
