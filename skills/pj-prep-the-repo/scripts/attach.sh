#!/usr/bin/env bash
# Write files to the attachments branch from a temporary detached worktree.
# Usage: attach.sh -m <message> <dest> <src> [<dest> <src> ...]
#   <dest> is a path on the branch, <src> a local file or folder.
# Prints one JSON line. Exit 3: attachments is missing or not an orphan.

. "$(dirname "$0")/lib.sh"

[ "${1:-}" = "-m" ] && [ $# -ge 4 ] && [ $(( ($# - 2) % 2 )) -eq 0 ] \
  || pj_die $PJ_EXIT_USAGE usage "attach.sh -m <message> <dest> <src> [<dest> <src> ...]"
msg=$2; shift 2

top=$(pj_top)
git -C "$top" fetch -q origin "$PJ_ATT" 2>/dev/null || true
pj_has_ref "refs/remotes/origin/$PJ_ATT" || pj_die $PJ_EXIT_ASK attachments-missing "Run pj-prep-the-repo."
[ "$(pj_orphan_state "origin/$PJ_ATT")" = not-orphan ] && pj_die $PJ_EXIT_ASK attachments-not-orphan

scanned=false
if command -v gitleaks >/dev/null 2>&1; then scanned=true; fi

args=("$@")
i=0
while [ $i -lt ${#args[@]} ]; do
  dest=${args[$i]}; src=${args[$((i + 1))]}
  case "$dest" in /*|*..*) pj_die $PJ_EXIT_USAGE bad-dest "$dest" ;; esac
  [ -e "$src" ] || pj_die $PJ_EXIT_USAGE missing-src "$src"
  if $scanned; then
    gitleaks detect --no-git --no-banner --redact -s "$src" >/dev/null 2>&1 \
      || pj_die $PJ_EXIT_ASK secret-found "$src"
  fi
  i=$((i + 2))
done

wt=$(mktemp -d "${TMPDIR:-/tmp}/pj-att.XXXXXX")
cleanup() { git -C "$top" worktree remove --force "$wt" >/dev/null 2>&1 || rm -rf "$wt"; git -C "$top" worktree prune; }
trap cleanup EXIT
git -C "$top" worktree add -q --detach "$wt" "origin/$PJ_ATT"

i=0
while [ $i -lt ${#args[@]} ]; do
  dest=${args[$i]}; src=${args[$((i + 1))]}
  if [ -d "$src" ]; then
    mkdir -p "$wt/$dest"; cp -R "$src/." "$wt/$dest/"
  else
    mkdir -p "$(dirname "$wt/$dest")"; cp "$src" "$wt/$dest"
  fi
  git -C "$wt" add -A -- "$dest"
  i=$((i + 2))
done

if git -C "$wt" diff --cached --quiet; then
  printf '{"ok":true,"pushed":false,"reason":"no-changes","scanned":%s}\n' "$scanned"
  exit 0
fi
git -C "$wt" commit -q -m "$msg"

# Bounded retry with jitter. Paths differ per run, so a rebase only conflicts on a
# real clash. Other fetch or rebase failures (ref locks from parallel runs) are retried.
tries=0
until git -C "$wt" push -q origin "HEAD:$PJ_ATT" 2>/dev/null; do
  tries=$((tries + 1))
  [ $tries -ge 10 ] && pj_die $PJ_EXIT_ERROR push-failed "Gave up after $tries tries."
  sleep "$((RANDOM % 2)).$((RANDOM % 10))"
  git -C "$wt" fetch -q origin "$PJ_ATT" 2>/dev/null || continue
  if ! git -C "$wt" rebase -q "origin/$PJ_ATT" >/dev/null 2>&1; then
    clash=$(git -C "$wt" diff --name-only --diff-filter=U)
    git -C "$wt" rebase --abort >/dev/null 2>&1 || true
    [ -n "$clash" ] && pj_die $PJ_EXIT_ERROR rebase-conflict "Another run wrote $clash."
  fi
done

printf '{"ok":true,"pushed":true,"commit":%s,"retries":%d,"scanned":%s}\n' \
  "$(pj_json "$(git -C "$wt" rev-parse HEAD)")" "$tries" "$scanned"
