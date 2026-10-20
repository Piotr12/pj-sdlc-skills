#!/usr/bin/env bash
# Posts a comment on an issue or a PR. The body starts with a marker line from marker.sh.
# Usage: comment.sh issue|pr <n> <body-file>
# Prints one JSON line: {"ok":true,"url":"..."}

. "$(dirname "$0")/lib.sh"

kind=${1:-} n=${2:-} body=${3:-}
case "$kind" in issue|pr) ;; *) pj_die $PJ_EXIT_USAGE usage "comment.sh issue|pr <n> <body-file>" ;; esac
pj_num "$n"
[ -f "$body" ] || pj_die $PJ_EXIT_USAGE usage "comment.sh issue|pr <n> <body-file>"
pj_has_marker "$body" || pj_die $PJ_EXIT_USAGE no-marker "The first line of $body must be a pj marker."
pj_require_main
url=$(gh "$kind" comment "$n" --body-file "$body")
printf '{"ok":true,"url":%s}\n' "$(pj_json "$url")"
