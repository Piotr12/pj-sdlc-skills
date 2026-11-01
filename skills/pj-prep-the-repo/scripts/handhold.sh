#!/usr/bin/env bash
# pj-handhold driver: takes one issue through the pj flow with no human in the loop.
# Each step is a fresh headless agent session. The state is on the forge: the driver reads it with
# state.sh and picks the next step. It never merges, closes, or approves.
# Usage:
#   handhold.sh next <n>          the next step for issue <n>; changes nothing
#   handhold.sh start <n>         posts the delegate marker, then starts "run" in the background
#   handhold.sh run <n> <run-id>  the loop, in the foreground
# Prints one JSON line. Exit 3: the issue cannot run unattended now (see reason).
# PJ_CLAUDE overrides the agent command (tests use a fake).

. "$(dirname "$0")/lib.sh"

PJ_CLAUDE=${PJ_CLAUDE:-claude}
HH=pj-handhold
SPEC_READY=spec-ready
BUG_LABEL=bug
# Defaults. The "handhold" object in .pj/config.json overrides them.
DEF_MAX_STEPS=30
DEF_STEP_USD=15
DEF_RUN_USD=60
DEF_REPORT_USD=3
DEF_ROUNDS=3
DEF_MODE=auto
NO_PROGRESS_MAX=2 # steps in a row that change nothing on the forge
MODES=" auto acceptEdits dontAsk bypassPermissions "

cd "$(pj_top)"
D="$(cd "$(git rev-parse --git-common-dir)" && pwd -P)/pj-handhold"
mkdir -p "$D"
GUARD_SH="$PJ_DIR/pj-guard.sh"

cfg() { # <key> <default>
  local v=""
  [ -f .pj/config.json ] && v=$(jq -r --arg k "$1" '(.handhold // {})[$k] // empty' .pj/config.json 2>/dev/null || true)
  echo "${v:-$2}"
}
num_cfg() { # <key> <default>: a positive number
  local v
  v=$(cfg "$1" "$2")
  echo "$v" | grep -Eq '^[0-9]+(\.[0-9]+)?$' || pj_die $PJ_EXIT_ASK bad-config "handhold.$1: $v"
  echo "$v"
}

# The next step from the state of the issue and its open PR. $acted: stop markers already acted on.
NEXT_JQ='
def act($a; $t; $why): {ok: true, action: $a, target: $t, reason: $why};
($i.markers | map(select(.skill != "pj-handhold"))) as $own
| ($own | last) as $lm
| ([$i.markers[] | select(.skill == "pj-handhold" and .event == "done")] | last) as $done
| (($i.answers | length) > 0) as $ans
| ($lm != null and $lm.event == "stopped" and ($acted | index($lm.url) | not)) as $stop
| ($i.labels | index($ready) != null) as $isReady
| if $i.state != "OPEN" then act("none"; $i.number; "closed")
  elif $i.children > 0 then act("children"; $i.number; "decomposed")
  elif $stop and $lm.reason == "too-big" then act("pj-decompose"; $i.number; "too-big")
  elif $stop and $ans then
    (if $lm.skill == "pj-repro" then "pj-implement" else $lm.skill end) as $s
    | act($s; if ($s | IN("pj-review", "pj-address-review")) and $p != null then $p.number else $i.number end; "answered-stop")
  elif $stop then act("decide"; $i.number; "stopped")
  elif $p == null then
    if $isReady then act(if ($i.labels | index($bug)) then "pj-repro" else "pj-implement" end; $i.number; "spec-ready")
    elif $lm != null and ($lm.event | IN("questions", "sign-off")) and ($ans | not) then act("decide"; $i.number; $lm.event)
    else act("pj-grill-for-specs-readiness"; $i.number; "spec") end
  elif $p.isDraft then act("pj-implement"; $i.number; "draft")
  elif $p.rounds >= $rounds then act("report"; $i.number; "rounds")
  elif $p.rounds > 0 and ($p.newCommits | not) and $p.lastBlocking == 0 then act("report"; $i.number; "clean")
  elif ($p.asked | length) > 0 then act("decide-pr"; $p.number; "ask")
  elif ([$p.threads[] | select(.lastTrusted)] | length) > 0 then act("pj-address-review"; $p.number; "threads")
  elif $p.newCommits then act("pj-review"; $p.number; "new-commits")
  else act("report"; $i.number; "declined") end
| if .action == "report" and $done != null and $p != null and $done.sha == $p.headSha
  then act("none"; $i.number; "reported") else . end
| tojson'

ISSUE="" PR="" # last state, set by snap
snap() { # <n>: reads the state of the issue and of its open PR
  local p
  ISSUE=$("$PJ_DIR/state.sh" issue "$1") || pj_die $PJ_EXIT_ERROR state-failed "$ISSUE"
  p=$(echo "$ISSUE" | jq -r '.openPrs[0].number // empty')
  PR=null
  if [ -n "$p" ]; then PR=$("$PJ_DIR/state.sh" pr "$p") || pj_die $PJ_EXIT_ERROR state-failed "$PR"; fi
}

next_of() { # <n>: prints the next step for the last snap
  local acted='[]'
  [ -f "$D/$1.acted" ] && acted=$(jq -R . "$D/$1.acted" | jq -cs .)
  jq -nr --argjson i "$ISSUE" --argjson p "$PR" --argjson acted "$acted" \
    --argjson rounds "$(num_cfg maxRounds $DEF_ROUNDS)" --arg ready "$SPEC_READY" --arg bug "$BUG_LABEL" "$NEXT_JQ"
}

lock() { # <n>: one driver for each issue
  local l="$D/$1.lock" pid
  if ! mkdir "$l" 2>/dev/null; then
    pid=$(cat "$l/pid" 2>/dev/null || true)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then return 1; fi
    rm -rf "$l"; mkdir "$l" || return 1
  fi
  echo "${2:-$$}" > "$l/pid"
}
unlock() { rm -rf "$D/$1.lock"; }
running() { local pid; pid=$(cat "$D/$1.lock/pid" 2>/dev/null || true); [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; }

mention() { # @login of the owner: owner from the config, else the issue author
  local o
  o=$(pj_config owner "")
  [ -n "$o" ] || o=$(echo "$ISSUE" | jq -r .author)
  echo "@$o"
}

post() { # <issue> <event> <text> [key=value ...]
  local n=$1 ev=$2 text=$3 f m
  shift 3
  f=$(mktemp "${TMPDIR:-/tmp}/pj-hh.XXXXXX")
  m=$("$PJ_DIR/marker.sh" "$HH" "$ev" "run=$RUN" "$@" | jq -r .marker)
  printf '%s\n%s\n' "$m" "$text" > "$f"
  "$PJ_DIR/comment.sh" issue "$n" "$f" >/dev/null
  rm -f "$f"
}

delegate() { # <n> <by>
  post "$1" delegate "pj-handhold runs this issue with no human in the loop. Started by @$2.
A fresh agent session runs each step. An agent makes the human decisions and logs each one here and in the PR.
A human reviews and merges the PR." "by=$2"
}

STEPS=0 COST=0 FAILS=""
step() { # <n> <prompt> <budget> [model]: one fresh agent session
  local n=$1 prompt=$2 usd=$3 model=${4:-} out rc=0 sys settings
  STEPS=$((STEPS + 1))
  out="$D/$n-$RUN-$STEPS.json"
  sys="pj-handhold run $RUN on issue #$n. No human is present: a trusted user delegated the human decisions. \
Do not wait for answers or approval. When a skill says to ask, stop, or wait, post the comment that the skill describes, then end."
  settings="{\"hooks\":{\"PreToolUse\":[{\"matcher\":\"Bash\",\"hooks\":[{\"type\":\"command\",\"command\":$(pj_json "\"$GUARD_SH\"")}]}]}}"
  "$PJ_CLAUDE" -p "$prompt" --permission-mode "$MODE" --max-budget-usd "$usd" --settings "$settings" \
    --append-system-prompt "$sys" --output-format json ${model:+--model "$model"} < /dev/null > "$out" 2>> "$D/$n.log" || rc=$?
  jq -c --arg run "$RUN" --argjson step "$STEPS" --arg prompt "$prompt" --argjson rc "$rc" \
    --arg at "$(date -u +%FT%TZ)" '{run: $run, step: $step, prompt: $prompt, rc: $rc, at: $at,
      error: (.is_error // ($rc != 0)), subtype, cost: (.total_cost_usd // 0), session: .session_id, turns: .num_turns}' \
    "$out" 2>/dev/null >> "$D/$n.jsonl" \
    || printf '{"run":"%s","step":%s,"prompt":%s,"rc":%s,"error":true,"cost":0}\n' "$RUN" "$STEPS" "$(pj_json "$prompt")" "$rc" >> "$D/$n.jsonl"
  COST=$(awk -v a="$COST" -v b="$(jq -r '.total_cost_usd // 0' "$out" 2>/dev/null || echo 0)" 'BEGIN {print a + b}')
  [ $rc -eq 0 ] && [ "$(jq -r '.is_error // false' "$out" 2>/dev/null)" != true ]
}

report() { # <n> <outcome>: the decision log on the issue and the PR. Falls back to a plain stopped comment.
  if ! step "$1" "/$HH report $1 run=$RUN outcome=$2" "$(num_cfg reportBudgetUsd $DEF_REPORT_USD)"; then
    post "$1" stopped "pj-handhold stopped: $2. The report step failed, so the decision log is missing.
$(mention): read the issue and the PR, then run pj-handhold again." "reason=report-failed"
  fi
}

run_issue() { # <n>: the loop for one issue. Returns 0 when it reported, 1 when it stopped.
  local n=$1 before after nx action target reason same=0 kids c
  snap "$n"; before="$ISSUE$PR"
  while :; do
    nx=$(next_of "$n")
    action=$(echo "$nx" | jq -r .action); target=$(echo "$nx" | jq -r .target); reason=$(echo "$nx" | jq -r .reason)
    case "$action" in
      none) return 0 ;;
      report) report "$n" "$reason"; return 0 ;;
      children)
        kids=$("$PJ_DIR/list.sh" issues --all | jq -c --argjson n "$n" '.issues as $all
          | [$all[] | select(.parent == $n and (.state | ascii_upcase) == "OPEN")
             | select([.dependsOn[] as $d | $all[] | select(.number == $d and (.state | ascii_upcase) == "OPEN")] | length == 0)
             | .number] | sort')
        for c in $(echo "$kids" | jq -r '.[]'); do
          lock "$c" || continue
          snap "$c"
          if [ "$(echo "$ISSUE" | jq -r '.delegation.active // false')" != true ]; then delegate "$c" "$BY"; fi
          run_issue "$c" || FAILS="$FAILS #$c"
          unlock "$c"
        done
        snap "$n"; report "$n" children; return 0 ;;
    esac
    if [ "$STEPS" -ge "$MAX_STEPS" ]; then report "$n" stopped-max-steps; return 1; fi
    if awk -v a="$COST" -v b="$RUN_USD" 'BEGIN {exit !(a >= b)}'; then report "$n" stopped-budget; return 1; fi
    # Remember a stop marker that this step acts on, so a later state does not act on it again.
    [ "$reason" = answered-stop ] && echo "$ISSUE" | jq -r '[.markers[] | select(.skill != "pj-handhold")] | last | .url' >> "$D/$n.acted"
    case "$action" in
      decide) step "$n" "/$HH decide $n run=$RUN" "$STEP_USD" "$DECIDER" || true ;;
      decide-pr) step "$n" "/$HH decide-pr $target issue=$n run=$RUN" "$STEP_USD" "$DECIDER" || true ;;
      pj-*) step "$n" "/$action $target" "$STEP_USD" "$MODEL" || true ;;
      *) pj_die $PJ_EXIT_ERROR bad-action "$action" ;;
    esac
    snap "$n"; after="$ISSUE$PR"
    if [ "$after" = "$before" ]; then same=$((same + 1)); else same=0; fi
    before=$after
    if [ $same -ge $NO_PROGRESS_MAX ]; then report "$n" stopped-no-progress; return 1; fi
  done
}

load_cfg() {
  MAX_STEPS=$(num_cfg maxSteps $DEF_MAX_STEPS)
  STEP_USD=$(num_cfg stepBudgetUsd $DEF_STEP_USD)
  RUN_USD=$(num_cfg runBudgetUsd $DEF_RUN_USD)
  MODE=$(cfg permissionMode $DEF_MODE)
  case "$MODES" in *" $MODE "*) ;; *) pj_die $PJ_EXIT_ASK bad-config "handhold.permissionMode: $MODE" ;; esac
  MODEL=$(cfg model "")
  DECIDER=$(cfg deciderModel "$MODEL")
}

cmd_next() {
  local n=${1:-}
  pj_num "$n"
  snap "$n"
  next_of "$n"
}

cmd_start() {
  local n=${1:-} nx m
  pj_num "$n"
  [ -x "$GUARD_SH" ] || pj_die $PJ_EXIT_ASK no-guard "$GUARD_SH is missing. Run pj-prep-the-repo."
  load_cfg
  snap "$n"
  if [ "$(echo "$ISSUE" | jq -r .state)" != OPEN ]; then echo '{"ok":true,"action":"none","reason":"closed"}'; return; fi
  [ "$(echo "$ISSUE" | jq -r .authorTrusted)" = true ] || pj_die $PJ_EXIT_ASK untrusted-author \
    "The issue author has no write access. pj-handhold runs only trusted issues."
  running "$n" && pj_die $PJ_EXIT_ASK running "A pj-handhold driver runs #$n. Log: $D/$n.log"
  nx=$(next_of "$n")
  if [ "$(echo "$nx" | jq -r .action)" = none ]; then echo "$nx"; return; fi
  pj_require_main
  BY=$(forge_me)
  RUN=$("$PJ_DIR/marker.sh" "$HH" delegate | jq -r .run)
  delegate "$n" "$BY"
  nohup "$PJ_DIR/handhold.sh" run "$n" "$RUN" >> "$D/$n.log" 2>&1 < /dev/null &
  printf '{"ok":true,"action":"started","run":"%s","pid":%s,"next":%s,"log":%s,"steps":%s}\n' \
    "$RUN" "$!" "$(echo "$nx" | jq -c .action)" "$(pj_json "$D/$n.log")" "$(pj_json "$D/$n.jsonl")"
}

cmd_run() {
  local n=${1:-} rc=0
  RUN=${2:-}
  pj_num "$n"
  case "$RUN" in ""|*[!a-z0-9-]*) pj_die $PJ_EXIT_USAGE bad-run "$RUN" ;; esac
  [ -x "$GUARD_SH" ] || pj_die $PJ_EXIT_ASK no-guard "$GUARD_SH is missing. Run pj-prep-the-repo."
  load_cfg
  lock "$n" || pj_die $PJ_EXIT_ASK running "A pj-handhold driver runs #$n."
  LOCKED=$n
  pj_cleanup() { unlock "$LOCKED"; }
  BY=$(forge_me)
  run_issue "$n" || rc=1
  printf '{"ok":true,"action":"%s","run":"%s","steps":%s,"cost":%s,"failedChildren":%s}\n' \
    "$([ $rc -eq 0 ] && echo reported || echo stopped)" "$RUN" "$STEPS" "$COST" "$(pj_json "${FAILS# }")"
  PJ_DONE=1
  [ $rc -eq 0 ] || exit $PJ_EXIT_ASK
}

case "${1:-}" in
  next) shift; cmd_next "$@" ;;
  start) shift; cmd_start "$@" ;;
  run) shift; cmd_run "$@" ;;
  *) pj_die $PJ_EXIT_USAGE usage "handhold.sh next <n> | start <n> | run <n> <run-id>" ;;
esac
