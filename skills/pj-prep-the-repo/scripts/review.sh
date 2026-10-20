#!/usr/bin/env bash
# Review writes. A review is always a comment: a human approves and merges.
# Usage:
#   review.sh post <pr> <body-file> [comments.json]   comments: [{"path","line","side"?,"body"}]
#   review.sh reply <pr> <comment-id> <body-file>     reply to the thread of a review comment
#   review.sh resolve <pr> <thread-id>                 resolves a thread that pj-review started
# Bodies start with a marker line from marker.sh: event review for post, reply for reply.
# Prints one JSON line. Exit 3: the thread did not start with a pj review marker.
# A forge without an API to resolve threads (Forgejo) prints "resolved":null and a warning.

. "$(dirname "$0")/lib.sh"

tmp=""
pj_cleanup() { [ -z "$tmp" ] || rm -f "$tmp"; }

cmd_post() {
  local pr=${1:-} body=${2:-} cfile=${3:-} comments='[]' out
  pj_num "$pr"
  [ -f "$body" ] || pj_die $PJ_EXIT_USAGE usage "review.sh post <pr> <body-file> [comments.json]"
  pj_is_marker "$body" review || pj_die $PJ_EXIT_USAGE no-marker "The first line of $body must be a review marker."
  if [ -n "$cfile" ]; then
    [ -f "$cfile" ] || pj_die $PJ_EXIT_USAGE missing-src "$cfile"
    comments=$(cat "$cfile")
    case "$(printf '%s' "$comments" | tr -d ' \n\t\r' | cut -c1)" in "[") ;; *) pj_die $PJ_EXIT_USAGE bad-comments "$cfile must hold a JSON array." ;; esac
  fi
  pj_require_main
  out=$(forge_review_post "$pr" "$body" "$comments")
  printf '{"ok":true,"review":%s,"url":%s}\n' "${out%% *}" "$(pj_json "${out#* }")"
}

cmd_reply() {
  local pr=${1:-} cid=${2:-} body=${3:-} id
  pj_num "$pr"; pj_num "$cid"
  [ -f "$body" ] || pj_die $PJ_EXIT_USAGE usage "review.sh reply <pr> <comment-id> <body-file>"
  pj_is_marker "$body" reply || pj_die $PJ_EXIT_USAGE no-marker "The first line of $body must be a reply marker."
  pj_require_main
  id=$(forge_review_reply "$pr" "$cid" "$body")
  printf '{"ok":true,"comment":%s}\n' "$id"
}

cmd_resolve() {
  local pr=${1:-} tid=${2:-} first
  pj_num "$pr"
  case "$tid" in ""|*[!A-Za-z0-9_=-]*) pj_die $PJ_EXIT_USAGE bad-thread "$tid" ;; esac
  pj_require_main
  tmp=$(mktemp "${TMPDIR:-/tmp}/pj-thread.XXXXXX")
  forge_thread_first_body "$pr" "$tid" > "$tmp"
  pj_is_marker "$tmp" review || pj_die $PJ_EXIT_ASK not-own-thread "pj-review did not start thread $tid."
  if [ "${PJ_FORGE_RESOLVE:-true}" = false ]; then
    printf '{"ok":true,"resolved":null,"warning":%s}\n' \
      "$(pj_json "$PJ_FORGE_NAME has no API to resolve a thread. A human resolves it in the web UI.")"
    return
  fi
  first=$(forge_thread_resolve "$pr" "$tid")
  printf '{"ok":true,"resolved":%s}\n' "$(pj_json "$first")"
}

case "${1:-}" in
  post) shift; cmd_post "$@" ;;
  reply) shift; cmd_reply "$@" ;;
  resolve) shift; cmd_resolve "$@" ;;
  *) pj_die $PJ_EXIT_USAGE usage "review.sh post <pr> <body-file> [comments.json] | reply <pr> <comment-id> <body-file> | resolve <pr> <thread-id>" ;;
esac
