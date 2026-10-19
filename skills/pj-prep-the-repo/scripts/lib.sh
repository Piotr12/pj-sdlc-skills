# Shared helpers for the pj scripts. Source it; do not run it.
# Bash 3.2 compatible (macOS default).

set -euo pipefail

# Bash seeds RANDOM from the clock: runs started in the same second would match.
RANDOM=$$

PJ_MAIN=main
PJ_ATT=attachments

# Exit codes. SKILL.md maps each one to an action.
PJ_EXIT_ERROR=1
PJ_EXIT_USAGE=2
PJ_EXIT_ASK=3     # state the script must not resolve alone: stop and ask the user
PJ_EXIT_EMPTY=4   # origin has no main branch yet

pj_die() { # <code> <reason> [detail]
  printf '{"ok":false,"reason":%s,"detail":%s}\n' "$(pj_json "$2")" "$(pj_json "${3:-}")"
  exit "$1"
}

pj_json() { # string -> JSON string literal
  local s=$1
  s=${s//\\/\\\\}; s=${s//\"/\\\"}; s=${s//$'\n'/\\n}; s=${s//$'\t'/\\t}; s=${s//$'\r'/}
  printf '"%s"' "$s"
}

# Root of the main checkout, also when called from a linked worktree.
pj_top() { (cd "$(git rev-parse --git-common-dir)/.." && pwd -P); }

pj_rand() { od -An -N4 -tx1 /dev/urandom | tr -d ' \n'; } # 8 hex chars

pj_has_ref() { git show-ref --verify --quiet "$1"; }

# Prints orphan | not-orphan | no-main. Takes the attachments ref to test.
pj_orphan_state() {
  pj_has_ref "refs/remotes/origin/$PJ_MAIN" || { echo no-main; return; }
  # merge-base exits 1 when there is no common ancestor: that is the good case.
  if git merge-base "origin/$PJ_MAIN" "$1" >/dev/null 2>&1; then echo not-orphan; else echo orphan; fi
}

# timezone from a config file, else UTC. Flat JSON only.
pj_tz() { # [config path]
  local f=${1:-"$(pj_top)/.pj/config.json"} tz=""
  [ -f "$f" ] && tz=$(sed -n 's/.*"timezone"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$f" | head -1)
  echo "${tz:-UTC}"
}
