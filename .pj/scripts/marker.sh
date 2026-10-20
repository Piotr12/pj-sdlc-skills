#!/usr/bin/env bash
# Builds the hidden marker line that starts each body an agent writes.
# Usage: marker.sh <skill> <event> [key=value ...]
#   Events: questions sign-off ready claim review reply stopped. run=<id> reuses a run id.
#   Values of digits only become JSON numbers.
# Prints one JSON line: {"ok":true,"marker":"<!-- pj:v1 {...} -->","run":"..."}

. "$(dirname "$0")/lib.sh"

[ $# -ge 2 ] || pj_die $PJ_EXIT_USAGE usage "marker.sh <skill> <event> [key=value ...]"
skill=$1 event=$2; shift 2
case "$skill" in pj-*[!a-z-]*|pj-) pj_die $PJ_EXIT_USAGE bad-skill "$skill" ;; pj-*) ;; *) pj_die $PJ_EXIT_USAGE bad-skill "$skill" ;; esac
case "$event" in questions|sign-off|ready|claim|review|reply|stopped) ;; *) pj_die $PJ_EXIT_USAGE bad-event "$event" ;; esac

run="" extra=""
for kv in "$@"; do
  k=${kv%%=*} v=${kv#*=}
  [ "$k" != "$kv" ] || pj_die $PJ_EXIT_USAGE bad-arg "$kv"
  case "$k" in ""|*[!a-zA-Z]*|skill|event) pj_die $PJ_EXIT_USAGE bad-key "$k" ;; esac
  case "$v" in *"-->"*|*$'\n'*) pj_die $PJ_EXIT_USAGE bad-value "$k" ;; esac
  if [ "$k" = run ]; then
    case "$v" in ""|*[!a-z0-9-]*) pj_die $PJ_EXIT_USAGE bad-run "$v" ;; esac
    run=$v; continue
  fi
  case "$v" in 0|[1-9]|[1-9]*[0-9]) case "$v" in *[!0-9]*) v=$(pj_json "$v") ;; esac ;; *) v=$(pj_json "$v") ;; esac
  extra="$extra,\"$k\":$v"
done
run=${run:-"$(date -u +%Y%m%d-%H%M)-$(pj_rand | cut -c1-4)"}

marker="$PJ_MARK{\"skill\":\"$skill\",\"event\":\"$event\",\"run\":\"$run\"$extra} -->"
printf '{"ok":true,"marker":%s,"run":"%s"}\n' "$(pj_json "$marker")" "$run"
