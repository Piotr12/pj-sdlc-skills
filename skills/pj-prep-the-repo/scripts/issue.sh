#!/usr/bin/env bash
# Issue writes with protocol rules.
# Usage:
#   issue.sh label <n> needs-input|spec-ready     sets one label and removes the other one
#   issue.sh child <parent> <title> <body-file>   creates or reuses a child issue, links it to the
#                                                 parent (GitHub: sub-issue), and sets spec-ready
# Prints one JSON line.

. "$(dirname "$0")/lib.sh"

set_label() { # <n> <label> -> removed label or empty
  local n=$1 label=$2 other have
  case "$label" in needs-input) other=spec-ready ;; spec-ready) other=needs-input ;;
    *) pj_die $PJ_EXIT_USAGE bad-label "$label" ;; esac
  have=$(forge_issue_labels "$n")
  if echo "$have" | grep -qxF "$other"; then
    forge_issue_relabel "$n" "$label" "$other"; echo "$other"
  else
    forge_issue_relabel "$n" "$label"
  fi
}

cmd_label() {
  local n=${1:-} label=${2:-} removed
  pj_num "$n"
  case "$label" in needs-input|spec-ready) ;; *) pj_die $PJ_EXIT_USAGE bad-label "$label" ;; esac
  pj_require_main
  removed=$(set_label "$n" "$label")
  printf '{"ok":true,"label":"%s","removed":"%s"}\n' "$label" "$removed"
}

cmd_child() {
  local parent=${1:-} title=${2:-} body=${3:-} found num url action linked=false warning=""
  pj_num "$parent"
  [ -n "$title" ] && [ -f "$body" ] || pj_die $PJ_EXIT_USAGE usage "issue.sh child <parent> <title> <body-file>"
  grep -qx "Parent: #$parent" "$body" || pj_die $PJ_EXIT_USAGE no-parent-line "The body needs the line: Parent: #$parent"
  pj_require_main
  # A rerun after a crash finds the child that it created before.
  found=$(forge_issue_list open 200 ".[] | select(.title == $(pj_json "$title") and (.body | gsub(\"\r\"; \"\") | split(\"\n\") | any(. == \"Parent: #$parent\"))) | \"\(.number) \(.url)\"" \
    | head -1)
  if [ -n "$found" ]; then
    num=${found%% *}; url=${found#* }; action=reused
  else
    url=$(forge_issue_create "$title" "$body"); num=${url##*/}; action=created
  fi
  pj_num "$num"
  if forge_issue_link_child "$parent" "$num"; then
    linked=true
  else
    warning="Could not link #$num to #$parent. It can be linked already."
  fi
  set_label "$num" spec-ready >/dev/null
  printf '{"ok":true,"action":"%s","number":%s,"url":%s,"linked":%s,"warning":%s}\n' \
    "$action" "$num" "$(pj_json "$url")" "$linked" "$(pj_json "$warning")"
}

case "${1:-}" in
  label) shift; cmd_label "$@" ;;
  child) shift; cmd_child "$@" ;;
  *) pj_die $PJ_EXIT_USAGE usage "issue.sh label <n> needs-input|spec-ready | child <parent> <title> <body-file>" ;;
esac
