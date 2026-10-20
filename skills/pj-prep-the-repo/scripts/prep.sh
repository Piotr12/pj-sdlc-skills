#!/usr/bin/env bash
# Idempotent steps of pj-prep-the-repo. Each command checks the local and remote
# state first, so it can run again after a crash at any point.
# Usage: prep.sh status | forge <name> | exclude | labels | rulesets [--apply] | attachments | worktree
#        | scripts | pr <body-file>
# Prints one JSON line. Exit 3: stop and ask the user. Exit 4: origin has no commits yet.
# Every command that changes something first checks that origin uses main.

. "$(dirname "$0")/lib.sh"

PREP=pj/prep-the-repo
PJ_TEMPLATES="$PJ_DIR/../templates"
TITLE="chore: prepare repo for pj skills"

top=$(pj_top)
# The pr body path is relative to the caller: resolve it before changing directory.
if [ "${1:-}" = pr ] && [ -f "${2:-}" ]; then set -- pr "$(cd "$(dirname "$2")" && pwd -P)/$(basename "$2")"; fi
cd "$top"

is_dirty() { [ -n "$(git -C "$1" status --porcelain)" ]; }

# "<number> <state> <branch> <url>" for each PR from a prep branch of this repo (forks ignored).
prep_prs() { pj_prs | awk -v p="$PREP" 'index($3, p) == 1 && $5 != "true" {print $1, $2, $3, $4}'; }

# Files that must never go into the prep PR.
SENSITIVE='(^|/)(\.env(\..*)?|node_modules/.*|.*\.pem|.*\.key|.*\.p12|id_rsa.*|id_ed25519.*)$'
pr_of() { echo "$2" | awk -v b="$1" '$3 == b {print; exit}'; } # <branch> <prs>

# Shared scripts and the adapter that prep.sh scripts copies, as "<source> <name in .pj/scripts>".
script_files() {
  local f
  for f in "$PJ_DIR"/*.sh; do [ "${f##*/}" = prep.sh ] || echo "$f ${f##*/}"; done
  echo "$PJ_DIR/forge/$PJ_FORGE_NAME.sh forge.sh"
}

# missing | current | stale: .pj/scripts on <ref> against the scripts of this skill.
scripts_state() { # <ref>
  local src name n=0
  git cat-file -e "$1:.pj/scripts/forge.sh" 2>/dev/null || { echo missing; return; }
  while read -r src name; do
    git show "$1:.pj/scripts/$name" 2>/dev/null | cmp -s - "$src" || { echo stale; return; }
    n=$((n + 1))
  done <<< "$(script_files)"
  [ "$(git ls-tree --name-only "$1:.pj/scripts/" | wc -l | tr -d ' ')" -eq $n ] && echo current || echo stale
}

cmd_status() {
  local v ok cli=false auth=false remote="" def="" shallow att=none wt=missing leaks=false sc=missing
  v=$(git --version | awk '{print $3}')
  ok=false; pj_git_ok && ok=true
  if [ -n "$PJ_FORGE_NAME" ] && forge_cli_ok; then cli=true; forge_auth_ok && auth=true; fi
  command -v gitleaks >/dev/null && leaks=true
  remote=$(git remote get-url origin 2>/dev/null || true)
  shallow=$(git rev-parse --is-shallow-repository)
  if [ -n "$remote" ]; then
    def=$(pj_default_branch || true)
    pj_fetch 2>/dev/null || true
  fi
  if pj_has_ref "refs/remotes/origin/$PJ_ATT"; then att=$(pj_orphan_state "origin/$PJ_ATT")
  elif pj_has_ref "refs/heads/$PJ_ATT"; then att=local-only
  fi
  wt_registered "$top/.worktrees/prep" && { wt=clean; is_dirty "$top/.worktrees/prep" && wt=dirty; }
  [ -n "$PJ_FORGE_NAME" ] && pj_has_ref "refs/remotes/origin/$PJ_MAIN" && sc=$(scripts_state "origin/$PJ_MAIN")
  printf '{"ok":true,"git":%s,"gitOk":%s,"forge":%s,"cli":%s,"cliOk":%s,"auth":%s,"gitleaks":%s,"remote":%s,"defaultBranch":%s,"mainOk":%s,"shallow":%s,"attachments":"%s","prepWorktree":"%s","scripts":"%s","timezone":%s}\n' \
    "$(pj_json "$v")" "$ok" "$(pj_json "$PJ_FORGE_NAME")" "$(pj_json "${PJ_FORGE_CLI:-}")" "$cli" "$auth" "$leaks" \
    "$(pj_json "$remote")" "$(pj_json "$def")" \
    "$([ "$def" = "$PJ_MAIN" ] && echo true || echo false)" "$shallow" "$att" "$wt" "$sc" "$(pj_json "$(pj_tz)")"
}

# Saves the forge of this clone in git config, for a host that prep.sh status cannot tell.
cmd_forge() {
  local n=${1:-}
  case " $PJ_FORGES " in *" $n "*) [ -n "$n" ] ;; *) false ;; esac || pj_die $PJ_EXIT_USAGE usage "prep.sh forge github|forgejo"
  git config pj.forge "$n"
  printf '{"ok":true,"forge":"%s"}\n' "$n"
}

# Copies the shared scripts and the adapter of the forge to .pj/scripts/ in the prep worktree.
cmd_scripts() {
  local wt="$top/.worktrees/prep" dest src name f action=current
  pj_require_main
  wt_registered "$wt" || pj_die $PJ_EXIT_ERROR no-worktree "Run prep.sh worktree first."
  dest="$wt/.pj/scripts"
  mkdir -p "$dest"
  while read -r src name; do
    cmp -s "$src" "$dest/$name" || { cp "$src" "$dest/$name"; action=written; }
    chmod +x "$dest/$name"
  done <<< "$(script_files)"
  for f in "$dest"/*; do
    [ -e "$f" ] || continue
    script_files | awk -v n="${f##*/}" '$2 == n {found=1} END {exit !found}' || { rm -rf "$f"; action=written; }
  done
  printf '{"ok":true,"action":"%s","forge":"%s","path":".pj/scripts"}\n' "$action" "$PJ_FORGE_NAME"
}

cmd_exclude() { printf '{"ok":true,"action":"%s"}\n' "$(pj_exclude_worktrees)"; }

cmd_labels() {
  local have created=""
  pj_require_main
  have=$(forge_labels)
  if ! echo "$have" | grep -qxF needs-input; then
    forge_label_create needs-input FBCA04 "pj: waiting for a human answer"
    created="$created needs-input"
  fi
  if ! echo "$have" | grep -qxF spec-ready; then
    forge_label_create spec-ready 0E8A16 "pj: meets the Definition of Ready"
    created="$created spec-ready"
  fi
  printf '{"ok":true,"created":%s}\n' "$(pj_json "${created# }")"
}

cmd_rulesets() {
  local apply=${1:-} have name present="" created="" missing="" err
  pj_require_main
  have=$(forge_protections 2>&1) \
    || pj_die $PJ_EXIT_ASK rulesets-unavailable "$have"
  for name in pj-main pj-attachments; do
    if echo "$have" | grep -qxF "$name"; then present="$present $name"
    elif [ "$apply" = --apply ]; then
      err=$(forge_protection_create "$name" 2>&1 >/dev/null) \
        || pj_die $PJ_EXIT_ASK ruleset-create-failed "$name: $err"
      created="$created $name"
    else missing="$missing $name"; fi
  done
  printf '{"ok":true,"present":%s,"created":%s,"missing":%s}\n' \
    "$(pj_json "${present# }")" "$(pj_json "${created# }")" "$(pj_json "${missing# }")"
}

cmd_attachments() {
  local wt="$top/.worktrees/$PJ_ATT" action
  pj_require_main
  pj_fetch
  git worktree prune
  if pj_has_ref "refs/remotes/origin/$PJ_ATT"; then
    [ "$(pj_orphan_state "origin/$PJ_ATT")" = not-orphan ] && pj_die $PJ_EXIT_ASK attachments-not-orphan \
      "origin/$PJ_ATT shares history with $PJ_MAIN."
    action=exists
    if ! wt_registered "$wt"; then
      [ -e "$wt" ] && [ -n "$(ls -A "$wt")" ] && pj_die $PJ_EXIT_ASK path-in-use "$wt"
      if pj_has_ref "refs/heads/$PJ_ATT"; then git worktree add -q "$wt" "$PJ_ATT"
      else git worktree add -q --track -b "$PJ_ATT" "$wt" "origin/$PJ_ATT"; fi
      action=worktree-added
    fi
    git -C "$wt" merge -q --ff-only "origin/$PJ_ATT" >/dev/null 2>&1 || true
  elif pj_has_ref "refs/heads/$PJ_ATT"; then
    # Crash after the first commit, before the push.
    [ "$(pj_orphan_state "$PJ_ATT")" = not-orphan ] && pj_die $PJ_EXIT_ASK attachments-not-orphan \
      "Local $PJ_ATT shares history with $PJ_MAIN."
    wt_registered "$wt" || git worktree add -q "$wt" "$PJ_ATT"
    git push -q --no-verify -u origin "$PJ_ATT"
    action=recovered-push
  elif wt_registered "$wt"; then
    # Crash after "worktree add --orphan", before the first commit.
    git -C "$wt" "${PJ_ATT_COMMIT[@]}" -q --allow-empty -m "chore: create attachments branch"
    git -C "$wt" push -q --no-verify -u origin "$PJ_ATT"
    action=recovered-commit
  else
    [ -e "$wt" ] && [ -n "$(ls -A "$wt")" ] && pj_die $PJ_EXIT_ASK path-in-use "$wt"
    pj_git_ok || pj_die $PJ_EXIT_ASK git-too-old "Creating attachments needs git 2.42 or later."
    git worktree add -q --orphan -b "$PJ_ATT" "$wt"
    git -C "$wt" "${PJ_ATT_COMMIT[@]}" -q --allow-empty -m "chore: create attachments branch"
    git -C "$wt" push -q --no-verify -u origin "$PJ_ATT"
    action=created
  fi
  printf '{"ok":true,"action":"%s","worktree":%s}\n' "$action" "$(pj_json "$wt")"
}

cmd_worktree() {
  local wt="$top/.worktrees/prep" prs open b cur pr action
  pj_require_main
  pj_fetch
  git worktree prune
  prs=$(prep_prs)
  open=$(echo "$prs" | awk '$2 == "OPEN" {print; exit}')
  cur=$(wt_branch "$wt")
  wt_registered "$wt" && [ -z "$cur" ] && cur="(unknown)"

  if [ -n "$cur" ]; then
    case "$cur" in "$PREP"*) ;; *) pj_die $PJ_EXIT_ASK worktree-wrong-branch "$wt is on $cur." ;; esac
    pr=$(pr_of "$cur" "$prs")
    case "$pr" in
      *" MERGED "*|*" CLOSED "*)
        is_dirty "$wt" && pj_die $PJ_EXIT_ASK dirty-leftover "$wt has changes, and the PR of $cur is closed."
        git worktree remove "$wt"; cur="" ;;
    esac
  fi

  if [ -n "$open" ]; then
    b=$(echo "$open" | awk '{print $3}')
    if [ -n "$cur" ] && [ "$cur" != "$b" ]; then pj_die $PJ_EXIT_ASK two-prep-branches "Open PR on $b, worktree on $cur."; fi
    if [ -z "$cur" ]; then
      if pj_has_ref "refs/heads/$b"; then git worktree add -q "$wt" "$b"
      else git worktree add -q --track -b "$b" "$wt" "origin/$b"; fi
    fi
    git -C "$wt" merge -q --ff-only "origin/$b" >/dev/null 2>&1 || true
    action=reuse-pr
  elif [ -n "$cur" ]; then
    b=$cur; action=resume
  else
    # A prep branch without a PR is a crash leftover: resume it.
    b=$(git for-each-ref --sort=-committerdate --format='%(refname:short)' "refs/heads/$PREP" "refs/heads/$PREP-*" \
      | while read -r x; do [ -z "$(pr_of "$x" "$prs")" ] && { echo "$x"; break; }; done || true)
    if [ -n "$b" ]; then git worktree add -q "$wt" "$b"; action=resume
    else
      b=$(git for-each-ref --sort=-committerdate --format='%(refname:short)' "refs/remotes/origin/$PREP" "refs/remotes/origin/$PREP-*" \
        | sed 's#^origin/##' | while read -r x; do [ -z "$(pr_of "$x" "$prs")" ] && { echo "$x"; break; }; done || true)
      if [ -n "$b" ]; then git worktree add -q --track -b "$b" "$wt" "origin/$b"; action=resume
      else
        b=$PREP
        if [ -n "$(pr_of "$b" "$prs")" ] || pj_has_ref "refs/heads/$b" || pj_has_ref "refs/remotes/origin/$b"; then
          b="$PREP-$(date +%Y%m%d-%H%M%S)"
        fi
        git worktree add -q -b "$b" "$wt" "origin/$PJ_MAIN"
        action=created
      fi
    fi
  fi
  printf '{"ok":true,"action":"%s","branch":%s,"worktree":%s}\n' "$action" "$(pj_json "$b")" "$(pj_json "$wt")"
}

cmd_pr() {
  local body=${1:-} wt="$top/.worktrees/prep" b msg open url action bad
  [ -f "$body" ] || pj_die $PJ_EXIT_USAGE usage "prep.sh pr <body-file>"
  case "$body" in "$wt"/*) pj_die $PJ_EXIT_USAGE body-in-worktree "Write the body file outside $wt." ;; esac
  pj_require_main
  wt_registered "$wt" || pj_die $PJ_EXIT_ERROR no-worktree "Run prep.sh worktree first."
  b=$(wt_branch "$wt")
  git -C "$wt" add -A
  bad=$(git -C "$wt" diff --cached --name-only | grep -E "$SENSITIVE" || true)
  if [ -n "$bad" ]; then
    git -C "$wt" reset -q
    pj_die $PJ_EXIT_ASK sensitive-files "$bad"
  fi
  if ! git -C "$wt" diff --cached --quiet; then
    msg=$TITLE
    [ "$(git -C "$wt" rev-list --count "origin/$PJ_MAIN..HEAD")" -gt 0 ] && msg="chore: update pj prep"
    git -C "$wt" commit -q -m "$msg"
  fi
  if [ "$(git -C "$wt" rev-list --count "origin/$PJ_MAIN..HEAD")" -eq 0 ]; then
    git worktree remove "$wt"
    echo '{"ok":true,"pr":null,"reason":"no-changes"}'; return
  fi
  if ! git -C "$wt" push -q -u origin "$b" 2>/dev/null; then
    git -C "$wt" fetch -q origin "+refs/heads/$b:refs/remotes/origin/$b"
    git -C "$wt" rebase -q "origin/$b" >/dev/null 2>&1 || {
      git -C "$wt" rebase --abort >/dev/null 2>&1 || true
      pj_die $PJ_EXIT_ASK branch-diverged "origin/$b has commits that conflict with this run."
    }
    git -C "$wt" push -q -u origin "$b"
  fi
  open=$(prep_prs | awk -v b="$b" '$3 == b && $2 == "OPEN" {print; exit}')
  if [ -n "$open" ]; then
    forge_pr_set_body "$(echo "$open" | awk '{print $1}')" "$body"
    url=$(echo "$open" | awk '{print $4}'); action=updated
  else
    url=$(forge_pr_create "$b" "$PJ_MAIN" "$TITLE" "$body"); action=created
  fi
  git worktree remove "$wt"
  printf '{"ok":true,"action":"%s","pr":%s,"branch":%s}\n' "$action" "$(pj_json "$url")" "$(pj_json "$b")"
}

case "${1:-}" in
  status) cmd_status ;;
  forge) shift; cmd_forge "$@" ;;
  exclude) cmd_exclude ;;
  labels) cmd_labels ;;
  rulesets) shift; cmd_rulesets "$@" ;;
  attachments) cmd_attachments ;;
  worktree) cmd_worktree ;;
  scripts) cmd_scripts ;;
  pr) shift; cmd_pr "$@" ;;
  *) pj_die $PJ_EXIT_USAGE usage "prep.sh status | forge <name> | exclude | labels | rulesets [--apply] | attachments | worktree | scripts | pr <body-file>" ;;
esac
