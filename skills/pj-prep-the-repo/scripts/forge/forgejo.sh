# Forgejo adapter of the pj scripts, through the REST API (/api/v1) with curl and jq.
# Sourced by lib.sh; do not run it. It defines the same forge_* functions as github.sh and
# builds the same GitHub-shaped objects, so the shared jq in the scripts works unchanged.
#
# fj (forgejo-cli) has no raw API command and no JSON output, so it only supplies the login.
# Token: FORGEJO_TOKEN, else the fj key of the host (fj auth add-key).
# Repo: the https URL of the repo in PJ_FORGE_URL, else git config pj.forgeUrl, else the origin
# URL. An ssh origin maps to https://<host>: set pj.forgeUrl for another port or a sub-path.
#
# Differences to GitHub:
# - No author associations. OWNER: the repo owner, or permission owner. COLLABORATOR: permission
#   write or admin, or a collaborator. MEMBER: a member of the owner org. Else NONE.
# - A draft PR is a PR with a "WIP:" title prefix.
# - A review thread is the review comments on one path and line. Its id is the first comment id.
#   The API cannot resolve a thread: PJ_FORGE_RESOLVE=false.
# - Closing references come from the PR body: close, fix, or resolve keywords before #<n>.
# - A child issue blocks its parent (issue dependencies). No sub-issues.

PJ_FORGE_NAME=forgejo
PJ_FORGE_CLI=curl
PJ_FORGE_RESOLVE=false
PJ_FJ_PAGE=50
PJ_FJ_BASE="" PJ_FJ_REPO="" PJ_FJ_TOKEN=""

# Sets PJ_FJ_BASE (https://host[/prefix]) and PJ_FJ_REPO (owner/repo).
fj_remote() {
  [ -z "$PJ_FJ_REPO" ] || return 0
  local url r path
  url=${PJ_FORGE_URL:-$(git config --get pj.forgeUrl 2>/dev/null || git remote get-url origin)}
  case "$url" in
    http://*|https://*) r=${url#*://}; r=${r#*@}; path=${r#*/}; PJ_FJ_BASE="${url%%://*}://${r%%/*}" ;;
    ssh://*) r=${url#ssh://}; r=${r#*@}; path=${r#*/}; PJ_FJ_BASE="https://${r%%[:/]*}" ;;
    *@*:*) r=${url#*@}; path=${r#*:}; PJ_FJ_BASE="https://${r%%:*}" ;;
    *) path=$url ;;
  esac
  path=${path%/}; path=${path%.git}
  PJ_FJ_REPO="$(basename "$(dirname "$path")")/$(basename "$path")"
  # A Forgejo under a sub-path: the path parts before owner/repo.
  case "$url" in http://*|https://*) r=$(dirname "$(dirname "$path")"); [ "$r" = . ] || PJ_FJ_BASE="$PJ_FJ_BASE/$r" ;; esac
}

fj_token() {
  [ -z "$PJ_FJ_TOKEN" ] || { echo "$PJ_FJ_TOKEN"; return; }
  local k f
  if [ -n "${FORGEJO_TOKEN:-}" ]; then PJ_FJ_TOKEN=$FORGEJO_TOKEN
  else
    k=${PJ_FJ_BASE#*://}
    for f in "${PJ_FJ_KEYS:-}" "${XDG_DATA_HOME:-$HOME/.local/share}/forgejo-cli/keys.json" \
      "$HOME/Library/Application Support/forgejo-cli.forgejo-cli/keys.json" \
      "$HOME/Library/Application Support/Cyborus.forgejo-cli/keys.json" \
      "${XDG_DATA_HOME:-$HOME/.local/share}/Cyborus/forgejo-cli/keys.json"; do
      [ -n "$f" ] && [ -f "$f" ] || continue
      PJ_FJ_TOKEN=$(jq -r --arg k "$k" '.hosts[$k].token // empty' "$f" 2>/dev/null || true)
      [ -z "$PJ_FJ_TOKEN" ] || break
    done
  fi
  echo "$PJ_FJ_TOKEN"
}

# fj_api <method> <path> [json-file]: prints the response body. <path> is under /api/v1;
# {repo} becomes owner/repo. Fails on an HTTP error and prints the body to stderr.
fj_api() {
  local m=$1 p=$2 data=${3:-} out rc
  fj_remote
  p=${p//\{repo\}/$PJ_FJ_REPO}
  set -- -sS --fail-with-body -X "$m" -H 'Accept: application/json' "$PJ_FJ_BASE/api/v1/$p"
  [ -z "$data" ] || set -- "$@" -H 'Content-Type: application/json' --data-binary "@$data"
  # The token goes through stdin, so it is not in the process list.
  out=$(printf 'header = "Authorization: token %s"\n' "$(fj_token)" | curl -K - "$@") && rc=0 || rc=$?
  [ $rc -eq 0 ] || { printf '%s\n' "$out" >&2; return $rc; }
  printf '%s\n' "$out"
}
# HTTP status of a GET, for the 204/404 checks.
fj_status() {
  fj_remote
  printf 'header = "Authorization: token %s"\n' "$(fj_token)" \
    | curl -K - -sS -o /dev/null -w '%{http_code}' "$PJ_FJ_BASE/api/v1/${1//\{repo\}/$PJ_FJ_REPO}" || true
}
fj_json() { # <jq filter> [jq args ...] -> temporary JSON file built with jq -n
  local f
  f=$(mktemp "${TMPDIR:-/tmp}/pj-fj.XXXXXX")
  jq -n "$@" > "$f"
  echo "$f"
}
fj_send() { # <method> <path> <jq filter> [jq args ...]: a write with a JSON body built by jq
  local m=$1 p=$2 f rc
  shift 2
  f=$(fj_json "$@")
  fj_api "$m" "$p" "$f" && rc=0 || rc=$?
  rm -f "$f"
  return $rc
}
# All pages of a list, as one array. Stops at <max> items.
fj_all() { # <path with or without ?query> [max]
  local p=$1 max=${2:-1000} page=1 sep='?' f n
  case "$p" in *\?*) sep='&' ;; esac
  f=$(mktemp "${TMPDIR:-/tmp}/pj-fj.XXXXXX")
  while :; do
    fj_api GET "$p${sep}limit=$PJ_FJ_PAGE&page=$page" | jq -c . > "$f.page" || { rm -f "$f" "$f.page"; return 1; }
    n=$(jq length "$f.page"); cat "$f.page" >> "$f"; rm -f "$f.page"
    [ "$n" -ge "$PJ_FJ_PAGE" ] && [ $((page * PJ_FJ_PAGE)) -lt "$max" ] || break
    page=$((page + 1))
  done
  jq -cs --argjson m "$max" 'add | .[:$m]' "$f"
  rm -f "$f"
}

forge_cli_ok() { command -v curl >/dev/null && command -v jq >/dev/null; }
forge_auth_ok() { [ -n "$(fj_remote; fj_token)" ] && fj_api GET user >/dev/null 2>&1; }
forge_me() { fj_api GET user | jq -r .login; }
forge_raw_url() { fj_remote; echo "$PJ_FJ_BASE/$PJ_FJ_REPO/raw/branch/$PJ_ATT/$1"; }

forge_labels() { fj_all 'repos/{repo}/labels' | jq -r '.[].name'; }
forge_label_create() { # <name> <hex> <desc>
  fj_send POST 'repos/{repo}/labels' '{name: $n, color: ("#" + $c), description: $d}' \
    --arg n "$1" --arg c "$2" --arg d "$3" >/dev/null
}

# Server-side branch rules: branch protections, from templates/branch-protections/<name>.json.
# A protected branch always rejects force-push and deletion.
forge_protections() {
  fj_api GET 'repos/{repo}/branch_protections' | jq -r --arg m "$PJ_MAIN" --arg a "$PJ_ATT" \
    '.[] | (.rule_name // .branch_name) | if . == $m then "pj-main" elif . == $a then "pj-attachments" else empty end'
}
forge_protection_create() { fj_api POST 'repos/{repo}/branch_protections' "$PJ_TEMPLATES/branch-protections/$1.json"; }

# jq definitions for the GitHub shapes.
PJ_FJ_DEFS='def actor: {author: {login: (.user.login // "ghost")}};
  def closes: (. // "") | [scan("(?i)\\b(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?):?\\s+#([0-9]+)") | .[0] | tonumber] | unique;
  def prstate: if .state == "open" then "OPEN" elif .merged then "MERGED" else "CLOSED" end;
  def fork: ((.head.repo.full_name // "") != (.base.repo.full_name // ""));
  def pr: actor + {number, title, body: (.body // ""), url: .html_url, createdAt: .created_at,
    state: prstate, isDraft: (.draft // false), headRefName: .head.ref, headRefOid: .head.sha,
    isCrossRepository: fork, additions, deletions, closingIssuesReferences: [.body | closes[] | {number: .}]};
  def comment: actor + {url: .html_url, createdAt: .created_at, body: (.body // ""), databaseId: .id};'

# Adds authorAssociation to each object with an author. See the header for the mapping.
fj_trust() { # stdin: JSON -> JSON
  local in owner otype l a map='{}'
  in=$(cat)
  fj_remote
  owner=${PJ_FJ_REPO%%/*} otype=user
  [ "$(fj_status "orgs/$owner")" = 200 ] && otype=org
  while read -r l; do
    [ -n "$l" ] || continue
    a=NONE
    if [ "$l" = "$owner" ]; then a=OWNER
    elif a=$(fj_api GET "repos/{repo}/collaborators/$l/permission" 2>/dev/null \
      | jq -r 'if .permission == "owner" then "OWNER" elif (.permission == "admin" or .permission == "write") then "COLLABORATOR" else "NONE" end'); then :
    else
      a=NONE
      [ "$(fj_status "repos/{repo}/collaborators/$l")" = 204 ] && a=COLLABORATOR
      [ "$a" = NONE ] && [ "$otype" = org ] && [ "$(fj_status "orgs/$owner/members/$l")" = 204 ] && a=MEMBER
    fi
    map=$(jq -c --arg l "$l" --arg a "$a" '. + {($l): $a}' <<< "$map")
  done <<< "$(jq -r '[.. | objects | .author?.login? // empty] | unique[]' <<< "$in")"
  jq -c --argjson A "$map" 'walk(if type == "object" and has("author")
    then . + {authorAssociation: ($A[.author.login] // "NONE")} else . end)' <<< "$in"
}

fj_open_prs() { fj_all 'repos/{repo}/pulls?state=open' 500 | jq -c "$PJ_FJ_DEFS [.[] | pr]"; }

# Temporary folder for the API answers. Large lists go to jq as files, not as arguments.
fj_tmp() { mktemp -d "${TMPDIR:-/tmp}/pj-fj.XXXXXX"; }

forge_issue_full() { # <n> <jq>
  local d deps out
  d=$(fj_tmp)
  fj_api GET "repos/{repo}/issues/$1" > "$d/i"
  fj_api GET "repos/{repo}/issues/$1/comments" > "$d/c"
  fj_open_prs > "$d/prs"
  deps=$(fj_all "repos/{repo}/issues/$1/dependencies" 2>/dev/null | jq length) || deps=0
  out=$(jq -c --slurpfile c "$d/c" --slurpfile prs "$d/prs" --argjson deps "${deps:-0}" --argjson n "$1" "$PJ_FJ_DEFS
    \$c[0] as \$c | \$prs[0] as \$prs |
    actor + {number, title, state: (.state | ascii_upcase), body: (.body // \"\"), url: .html_url, createdAt: .created_at,
      labels: {nodes: [.labels[]? | {name}]}, assignees: {nodes: [.assignees[]? | {login}]},
      closedByPullRequestsReferences: {nodes: [\$prs[] | select(.closingIssuesReferences | any(.number == \$n))
        | {number, isDraft, state, headRefName, isCrossRepository}]},
      subIssues: {totalCount: \$deps},
      comments: {nodes: [\$c[-100:][] | comment]}}" "$d/i")
  rm -rf "$d"
  fj_trust <<< "$out" | jq -r "$2"
}

forge_pr_full() { # <n> <jq>
  local d id out
  d=$(fj_tmp)
  fj_api GET "repos/{repo}/pulls/$1" > "$d/p"
  fj_api GET "repos/{repo}/issues/$1/comments" > "$d/c"
  fj_all "repos/{repo}/pulls/$1/reviews" > "$d/rv"
  : > "$d/rc"
  for id in $(jq -r '.[] | select((.comments_count // 0) > 0) | .id' "$d/rv"); do
    fj_api GET "repos/{repo}/pulls/$1/reviews/$id/comments" >> "$d/rc"
  done
  out=$(jq -c --slurpfile c "$d/c" --slurpfile rv "$d/rv" --slurpfile rc "$d/rc" "$PJ_FJ_DEFS
    \$c[0] as \$c | \$rv[0] as \$rv | (\$rc | add // []) as \$rc |
    pr | .closingIssuesReferences |= {nodes: .} | . + {comments: {nodes: [\$c[-100:][] | comment]},
      reviews: {nodes: [\$rv[-100:][] | actor + {url: .html_url, createdAt: .submitted_at, body: (.body // \"\"),
        state, commit: {oid: .commit_id}}]},
      reviewThreads: {nodes: [\$rc | sort_by(.created_at, .id)
        | group_by([.path, (if (.position // 0) > 0 then .position else -(.original_position // 0) end)])
        | sort_by(.[0].created_at, .[0].id)[]
        | {id: (.[0].id | tostring), path: .[0].path,
           line: (if (.[0].position // 0) > 0 then .[0].position else (.[0].original_position // null) end),
           isResolved: (.[0].resolver != null), comments: {nodes: [.[] | comment]}}]}}" "$d/p")
  rm -rf "$d"
  fj_trust <<< "$out" | jq -r "$2"
}

forge_issue_list() { # <open|all> <limit> <jq>
  fj_all "repos/{repo}/issues?state=$1&type=issues" "$2" | jq -r "$PJ_FJ_DEFS [.[] | actor + {number, title,
    state: (.state | ascii_upcase), labels: [.labels[]? | {name}], assignees: [.assignees[]? | {login}],
    createdAt: .created_at, body: (.body // \"\"), url: .html_url}] | $3"
}
forge_issue_body() { fj_api GET "repos/{repo}/issues/$1" | jq -j '.body // ""' > "$2"; } # <n> <file>
forge_issue_set_body() { fj_send PATCH "repos/{repo}/issues/$1" '{body: $b}' --rawfile b "$2" >/dev/null; }
forge_issue_labels() { fj_api GET "repos/{repo}/issues/$1/labels" | jq -r '.[].name'; } # <n>
forge_issue_relabel() { # <n> <add> [remove]
  fj_send POST "repos/{repo}/issues/$1/labels" '{labels: [$l]}' --arg l "$2" >/dev/null
  [ -z "${3:-}" ] || fj_api DELETE "repos/{repo}/issues/$1/labels/$3" >/dev/null
}
forge_issue_create() { # <title> <body-file> -> url
  fj_send POST 'repos/{repo}/issues' '{title: $t, body: $b}' --arg t "$1" --rawfile b "$2" | jq -r .html_url
}
forge_issue_assign_me() { # <n>
  local me have
  me=$(forge_me)
  have=$(fj_api GET "repos/{repo}/issues/$1" | jq -c '[.assignees[]?.login]')
  fj_send PATCH "repos/{repo}/issues/$1" '{assignees: ($h + [$me] | unique)}' --argjson h "$have" --arg me "$me" >/dev/null
}
forge_issue_link_child() { # <parent> <child>: the child blocks the parent
  fj_remote
  fj_send POST "repos/{repo}/issues/$1/dependencies" '{owner: $o, repo: $r, index: $i}' \
    --arg o "${PJ_FJ_REPO%%/*}" --arg r "${PJ_FJ_REPO#*/}" --argjson i "$2" >/dev/null 2>&1
}
forge_comment() { # <issue|pr> <n> <body-file> -> url
  fj_send POST "repos/{repo}/issues/$2/comments" '{body: $b}' --rawfile b "$3" | jq -r .html_url
}

forge_pr_list() { # <open|all> <limit> <jq>
  fj_all "repos/{repo}/pulls?state=$1" "$2" | jq -r "$PJ_FJ_DEFS [.[] | pr] | $3"
}
forge_pr_view() { fj_api GET "repos/{repo}/pulls/$1" | jq -r "$PJ_FJ_DEFS pr | $2"; } # <n> <jq>
forge_pr_create() { # <head> <base> <title> <body-file> [draft] -> url
  local t=$3
  [ "${5:-}" = draft ] && t="WIP: $t"
  fj_send POST 'repos/{repo}/pulls' '{head: $h, base: $b, title: $t, body: $body}' \
    --arg h "$1" --arg b "$2" --arg t "$t" --rawfile body "$4" | jq -r .html_url
}
forge_pr_set_body() { fj_send PATCH "repos/{repo}/pulls/$1" '{body: $b}' --rawfile b "$2" >/dev/null; }
forge_pr_ready() { # <n>: removes the WIP prefix from the title
  local t
  t=$(fj_api GET "repos/{repo}/pulls/$1" | jq -r '.title | sub("^\\s*(?i:wip:|\\[wip\\])\\s*"; "")')
  fj_send PATCH "repos/{repo}/pulls/$1" '{title: $t}' --arg t "$t" >/dev/null
}
forge_pr_diff() { fj_remote; fj_api GET "repos/{repo}/pulls/$1.diff"; } # <n>

# A COMMENT review on the head commit. comments: [{"path","line","side"?,"body"}]. Prints "<id> <url>".
forge_review_post() { # <pr> <body-file> <comments-json>
  local sha
  sha=$(fj_api GET "repos/{repo}/pulls/$1" | jq -r .head.sha)
  fj_send POST "repos/{repo}/pulls/$1/reviews" '{event: "COMMENT", commit_id: $sha, body: $b,
      comments: [$c[] | {path, body} + (if .side == "LEFT" then {old_position: .line, new_position: 0}
        else {new_position: .line, old_position: 0} end)]}' \
    --arg sha "$sha" --rawfile b "$2" --argjson c "$3" | jq -r '"\(.id) \(.html_url)"'
}
# The review comment <id> of a PR, as JSON. Fails if there is none.
fj_review_comment() { # <pr> <comment-id>
  local id c
  for id in $(fj_all "repos/{repo}/pulls/$1/reviews" | jq -r '.[] | select((.comments_count // 0) > 0) | .id'); do
    c=$(fj_api GET "repos/{repo}/pulls/$1/reviews/$id/comments" | jq -c --argjson c "$2" '.[] | select(.id == $c)')
    [ -z "$c" ] || { echo "$c"; return 0; }
  done
  return 1
}
forge_review_reply() { # <pr> <comment-id> <body-file> -> id
  local c
  c=$(fj_review_comment "$1" "$2") || { echo "No review comment $2 on PR #$1." >&2; return 1; }
  fj_send POST "repos/{repo}/pulls/$1/reviews/$(jq -r .pull_request_review_id <<< "$c")/comments" \
    '{body: $b, path: $c.path, new_position: ($c.position // 0), old_position: (if ($c.position // 0) > 0 then 0 else ($c.original_position // 0) end)}' \
    --rawfile b "$3" --argjson c "$c" | jq -r .id
}
forge_thread_first_body() { fj_review_comment "$1" "$2" | jq -r '.body // ""'; } # <pr> <thread-id>
forge_thread_resolve() { return 1; }
