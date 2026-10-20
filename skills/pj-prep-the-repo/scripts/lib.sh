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
PJ_EXIT_EMPTY=4   # origin has no commits yet

# Commits on attachments never run the target repo's hooks or signing.
PJ_ATT_COMMIT=(-c core.hooksPath=/dev/null -c commit.gpgsign=false commit)

PJ_DONE=""
PJ_LAST=""
pj_die() { # <code> <reason> [detail]
  PJ_DONE=1
  printf '{"ok":false,"reason":%s,"detail":%s}\n' "$(pj_json "$2")" "$(pj_json "${3:-}")"
  exit "$1"
}

# Every exit prints JSON: an unexpected failure reports the command that failed.
pj_on_exit() {
  local rc=$?
  if declare -F pj_cleanup >/dev/null; then pj_cleanup || true; fi
  if [ $rc -ne 0 ] && [ -z "$PJ_DONE" ]; then
    printf '{"ok":false,"reason":"unexpected","detail":%s}\n' "$(pj_json "exit $rc: $PJ_LAST")"
  fi
}
trap pj_on_exit EXIT
trap 'PJ_LAST=$BASH_COMMAND' ERR
set -E

pj_json() { # string -> JSON string literal
  local s=$1
  s=${s//\\/\\\\}; s=${s//\"/\\\"}; s=${s//$'\n'/\\n}; s=${s//$'\t'/\\t}; s=${s//$'\r'/}
  printf '"%s"' "$s"
}

pj_rand() { od -An -N4 -tx1 /dev/urandom | tr -d ' \n'; } # 8 hex chars

# Root of the main checkout, also when called from a linked worktree.
pj_top() { (cd "$(git rev-parse --git-common-dir)/.." && pwd -P); }

pj_has_ref() { git show-ref --verify --quiet "$1"; }

pj_git_ok() { git --version | awk '{split($3, v, "."); exit !(v[1] > 2 || (v[1] == 2 && v[2] >= 42))}'; }

# Default branch of origin, read from the remote (works in shallow and single-branch clones).
# Prints nothing for an empty remote. Fails if origin is unreachable.
pj_default_branch() {
  local out
  out=$(git ls-remote --symref origin HEAD 2>/dev/null) || return 1
  echo "$out" | awk '/^ref:/ {sub("refs/heads/", "", $2); print $2; exit}'
}

# Stop before any change unless origin exists, has commits, and uses main.
pj_require_main() {
  local d
  git remote get-url origin >/dev/null 2>&1 || pj_die $PJ_EXIT_ERROR no-remote "Add a GitHub remote named origin."
  d=$(pj_default_branch) || pj_die $PJ_EXIT_ERROR origin-unreachable "git ls-remote origin failed."
  [ -n "$d" ] || pj_die $PJ_EXIT_EMPTY empty-origin "origin has no commits. Push a first commit to $PJ_MAIN."
  [ "$d" = "$PJ_MAIN" ] || pj_die $PJ_EXIT_ASK default-branch-not-main \
    "pj needs $PJ_MAIN as the default branch. origin uses $d. Rename it on GitHub, or stop."
  [ "$(git rev-parse --is-shallow-repository)" = false ] || pj_die $PJ_EXIT_ASK shallow-clone \
    "Run: git fetch --unshallow origin"
}

# Fetch main and attachments with explicit refspecs, so single-branch clones see both.
pj_fetch() {
  git fetch -q origin "+refs/heads/$PJ_MAIN:refs/remotes/origin/$PJ_MAIN"
  if git ls-remote --exit-code --heads origin "$PJ_ATT" >/dev/null 2>&1; then
    git fetch -q origin "+refs/heads/$PJ_ATT:refs/remotes/origin/$PJ_ATT"
  fi
}

# Prints orphan | not-orphan | no-main. Takes the attachments ref to test.
pj_orphan_state() {
  pj_has_ref "refs/remotes/origin/$PJ_MAIN" || { echo no-main; return; }
  # merge-base exits 1 when there is no common ancestor: that is the good case.
  if git merge-base "origin/$PJ_MAIN" "$1" >/dev/null 2>&1; then echo not-orphan; else echo orphan; fi
}

# A flat string key from .pj/config.json, else the default.
pj_config() { # <key> <default> [config path]
  local f=${3:-"$(pj_top)/.pj/config.json"} v=""
  [ -f "$f" ] && v=$(sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$f" | head -1)
  echo "${v:-$2}"
}
pj_tz() { pj_config timezone UTC "${1:-}"; }

# Branch of the registered worktree at <path>; empty if none; "(detached)" if detached.
wt_branch() {
  git worktree list --porcelain | awk -v p="worktree $1" '
    $0==p {f=1; next} f && /^branch / {sub("branch refs/heads/",""); print; exit}
    f && /^detached/ {print "(detached)"; exit} f && /^$/ {exit}'
}
wt_registered() { git worktree list --porcelain | grep -qxF "worktree $1"; }
pj_wt_free() { [ ! -e "$1" ] || [ -z "$(ls -A "$1")" ]; } # <path> is missing or empty

# Keeps .worktrees/ out of git status before the prep PR merges. Prints added | exists.
pj_exclude_worktrees() {
  local f
  f="$(git rev-parse --git-common-dir)/info/exclude"
  mkdir -p "$(dirname "$f")"
  if grep -qxF '.worktrees/' "$f" 2>/dev/null; then echo exists; else echo '.worktrees/' >> "$f"; echo added; fi
}

# "<number> <state> <branch> <url> <isCrossRepository> <author>" for each PR.
pj_prs() {
  gh pr list --state all --limit 200 --json number,state,headRefName,url,isCrossRepository,author \
    --jq '.[] | "\(.number) \(.state) \(.headRefName) \(.url) \(.isCrossRepository) \(.author.login)"'
}

pj_num() { case "${1:-}" in ""|*[!0-9]*) pj_die $PJ_EXIT_USAGE bad-number "${1:-}" ;; esac; }

pj_sha256() { # stdin -> hex digest
  if command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}'; else shasum -a 256 | awk '{print $1}'; fi
}

# Marker line: the first line of each body that an agent writes.
PJ_MARK='<!-- pj:v1 '
pj_is_marker() { # <file> <event>: the first line is a pj:v1 marker for <event>
  local l
  l=$(head -1 "$1" | tr -d '\r')
  case "$l" in "$PJ_MARK{"*"\"event\":\"$2\""*"} -->") return 0 ;; esac
  return 1
}
pj_has_marker() { # <file>: the first line is a pj:v1 marker for any event
  local l
  l=$(head -1 "$1" | tr -d '\r')
  case "$l" in "$PJ_MARK{"*"} -->") return 0 ;; esac
  return 1
}

# jq helpers for --jq programs: the marker of a body (null if none), the test for one event,
# the login of an author, a body quoted line by line, and a comment header with its trust.
PJ_JQ_DEFS='def mk: (split("\n")[0] | rtrimstr("\r")) as $l
    | if ($l | startswith("<!-- pj:v1 ")) and ($l | endswith(" -->"))
      then (try ($l | ltrimstr("<!-- pj:v1 ") | rtrimstr(" -->") | fromjson) catch null) else null end;
  def is($e): (mk | . != null and .event == $e);
  def who: (.author.login // "ghost");
  def quote: gsub("\r"; "") | split("\n") | map("> " + .) | join("\n");
  def trusted($T): (.authorAssociation | IN($T[]));
  def entry($kind; $T; $extra): trusted($T) as $ok | (.body // "") as $b
    | "--- \($kind) \(.url // "") · @\(who) · \(.authorAssociation) · \(if $ok then "trusted" else "untrusted" end)"
      + " · \(($b | mk) as $m | if $m then "marker:\($m.event)" else "human" end) · \(.createdAt)\($extra)\n"
      + (if $ok then ($b | gsub("\r"; "")) else ($b | quote) end) + "\n";'


# jq array literal of the trusted author associations, for --jq programs.
# Read from origin/main first, so a local branch cannot widen the list.
pj_trusted_jq() {
  local cfg raw out="" a
  cfg=$(git show "origin/$PJ_MAIN:.pj/config.json" 2>/dev/null || cat "$(pj_top)/.pj/config.json" 2>/dev/null || true)
  if echo "$cfg" | grep -q '"trustedAssociations"'; then
    raw=$(echo "$cfg" | sed -n 's/.*"trustedAssociations"[[:space:]]*:[[:space:]]*\[\([^]]*\)\].*/\1/p' | head -1)
  else raw='"OWNER","MEMBER","COLLABORATOR"'; fi
  while read -r a; do
    [ -z "$a" ] && continue
    case "$a" in *[!A-Z_]*) pj_die $PJ_EXIT_ASK bad-config "trustedAssociations: $a" ;; esac
    out="$out,\"$a\""
  done <<< "$(echo "$raw" | tr ',' '\n' | tr -d '" ')"
  echo "[${out#,}]"
}
