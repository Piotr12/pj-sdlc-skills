#!/usr/bin/env bash
# Write files to the attachments branch from a temporary detached worktree.
# Usage: attach.sh -m <message> <dest> <src> [<dest> <src> ...]
#   <dest> is a path on the branch under issues/, prs/ or devlog/. <src> is a local file or folder.
# Prints one JSON line, with the raw URL of each <dest> in "urls". Exit 3: attachments is missing or not an orphan, a destination or source
# is not allowed, or the secret scan found something.
# Secret scan: gitleaks, if installed. "secretScan": "required" in .pj/config.json makes it mandatory.

. "$(dirname "$0")/lib.sh"

[ "${1:-}" = "-m" ] && [ $# -ge 4 ] && [ $(( ($# - 2) % 2 )) -eq 0 ] \
  || pj_die $PJ_EXIT_USAGE usage "attach.sh -m <message> <dest> <src> [<dest> <src> ...]"
msg=$2; shift 2

top=$(pj_top)
cd "$top"
pj_fetch 2>/dev/null || true
pj_has_ref "refs/remotes/origin/$PJ_ATT" || pj_die $PJ_EXIT_ASK attachments-missing "Run pj-prep-the-repo."
case "$(pj_orphan_state "origin/$PJ_ATT")" in
  orphan) ;;
  no-main) pj_die $PJ_EXIT_ASK main-missing "Cannot check that $PJ_ATT is an orphan." ;;
  *) pj_die $PJ_EXIT_ASK attachments-not-orphan ;;
esac

scanned=false warning=""
if command -v gitleaks >/dev/null 2>&1; then scanned=true
elif [ "$(pj_config secretScan warn)" = required ]; then
  pj_die $PJ_EXIT_ASK gitleaks-missing "secretScan is required. Install gitleaks."
else warning="gitleaks is not installed: the files were not scanned for secrets."; fi

scan() { # <path>
  if gitleaks dir --help >/dev/null 2>&1; then gitleaks dir --no-banner --redact "$1" >/dev/null 2>&1
  else gitleaks detect --no-git --no-banner --redact -s "$1" >/dev/null 2>&1; fi
}

args=("$@")
i=0
while [ $i -lt ${#args[@]} ]; do
  dest=${args[$i]}; src=${args[$((i + 1))]}
  case "$dest" in
    /*|*..*|*/.github/*|.github/*) pj_die $PJ_EXIT_ASK bad-dest "$dest" ;;
    issues/*|prs/*|devlog/*) ;;
    *) pj_die $PJ_EXIT_ASK bad-dest "$dest is not under issues/, prs/ or devlog/." ;;
  esac
  [ -e "$src" ] || pj_die $PJ_EXIT_USAGE missing-src "$src"
  [ -z "$(find "$src" -type l | head -1)" ] || pj_die $PJ_EXIT_ASK symlink-in-src "$src"
  if $scanned; then scan "$src" || pj_die $PJ_EXIT_ASK secret-found "$src"; fi
  i=$((i + 2))
done

wt=$(mktemp -d "${TMPDIR:-/tmp}/pj-att.XXXXXX")
pj_cleanup() { git -C "$top" worktree remove --force "$wt" >/dev/null 2>&1 || rm -rf "$wt"; git -C "$top" worktree prune; }
git worktree add -q --detach "$wt" "origin/$PJ_ATT"

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
  printf '{"ok":true,"pushed":false,"reason":"no-changes","scanned":%s,"warning":%s}\n' "$scanned" "$(pj_json "$warning")"
  exit 0
fi
git -C "$wt" "${PJ_ATT_COMMIT[@]}" -q -m "$msg"

# Bounded retry with jitter. Paths differ per run, so a rebase only conflicts on a
# real clash. Other fetch or rebase failures (ref locks from parallel runs) are retried.
tries=0
until git -C "$wt" push -q --no-verify origin "HEAD:$PJ_ATT" 2>/dev/null; do
  tries=$((tries + 1))
  [ $tries -ge 10 ] && pj_die $PJ_EXIT_ERROR push-failed "Gave up after $tries tries."
  sleep "$((RANDOM % 2)).$((RANDOM % 10))"
  git -C "$wt" fetch -q origin "+refs/heads/$PJ_ATT:refs/remotes/origin/$PJ_ATT" 2>/dev/null || continue
  if ! git -C "$wt" -c core.hooksPath=/dev/null -c commit.gpgsign=false rebase -q "origin/$PJ_ATT" >/dev/null 2>&1; then
    clash=$(git -C "$wt" diff --name-only --diff-filter=U)
    git -C "$wt" rebase --abort >/dev/null 2>&1 || true
    [ -n "$clash" ] && pj_die $PJ_EXIT_ERROR rebase-conflict "Another run wrote $clash."
  fi
done

# Links by branch path, so they work after a squash of the branch.
urls="" base=""
declare -F forge_raw_url >/dev/null && base=$(forge_raw_url @PATH@ 2>/dev/null || true)
if [ -n "$base" ]; then
  i=0
  while [ $i -lt ${#args[@]} ]; do urls="$urls,$(pj_json "${base/@PATH@/${args[$i]}}")"; i=$((i + 2)); done
fi
printf '{"ok":true,"pushed":true,"commit":%s,"retries":%d,"urls":[%s],"scanned":%s,"warning":%s}\n' \
  "$(pj_json "$(git -C "$wt" rev-parse HEAD)")" "$tries" "${urls#,}" "$scanned" "$(pj_json "$warning")"
