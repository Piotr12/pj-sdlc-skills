#!/usr/bin/env bash
# The spec block of an issue: the lines between "<!-- pj:spec:start -->" and "<!-- pj:spec:end -->".
# The hash is SHA-256 of those lines, CR stripped, each line ending with a newline.
# Usage:
#   spec.sh hash <n>                    current hash, snapshot hash, match
#   spec.sh set <n> <block-file>        replaces the block; adds it at the end if missing
#   spec.sh snapshot <n> <sha256:hex>   writes the block to attachments at issues/<n>/spec.md
# Prints one JSON line. Exit 3: no spec block, or the block changed after the sign-off.

. "$(dirname "$0")/lib.sh"

START='<!-- pj:spec:start -->'
END='<!-- pj:spec:end -->'

tmp=$(mktemp -d "${TMPDIR:-/tmp}/pj-spec.XXXXXX")
pj_cleanup() { rm -rf "$tmp"; }

# Issue body -> $tmp/body (exact), $tmp/block (CR stripped). Returns 1 without a complete block.
read_block() {
  local b
  # gh adds a newline after the body: the "." keeps the real trailing newlines, then goes.
  b=$(gh issue view "$1" --json body --jq '.body + "."')
  printf '%s' "${b%.}" > "$tmp/body"
  awk -v s="$START" -v e="$END" '{sub(/\r$/, "")} !inb && $0 == s {inb=1; next}
    inb && $0 == e {done=1; exit} inb {print} END {exit !done}' "$tmp/body" > "$tmp/block"
}
hash_of() { echo "sha256:$(pj_sha256 < "$1")"; }

cmd_hash() {
  local n=${1:-} h snap=""
  pj_num "$n"
  read_block "$n" || pj_die $PJ_EXIT_ASK no-spec-block "Issue #$n has no complete spec block."
  h=$(hash_of "$tmp/block")
  git -C "$(pj_top)" fetch -q origin "+refs/heads/$PJ_ATT:refs/remotes/origin/$PJ_ATT" 2>/dev/null || true
  snap=$( (git -C "$(pj_top)" show "origin/$PJ_ATT:issues/$n/spec.md" 2>/dev/null || true) | head -1 \
    | sed -n 's/^<!-- pj:spec \(sha256:[0-9a-f]*\) -->$/\1/p')
  printf '{"ok":true,"hash":"%s","snapshot":"%s","match":%s}\n' "$h" "$snap" "$([ "$h" = "$snap" ] && echo true || echo false)"
}

cmd_set() {
  local n=${1:-} src=${2:-} action
  pj_num "$n"
  [ -f "$src" ] || pj_die $PJ_EXIT_USAGE usage "spec.sh set <n> <block-file>"
  pj_require_main
  tr -d '\r' < "$src" > "$tmp/new"
  [ -z "$(tail -c1 "$tmp/new")" ] || echo >> "$tmp/new"
  grep -qxF -e "$START" -e "$END" "$tmp/new" && pj_die $PJ_EXIT_USAGE marker-in-block "The block file must not hold the spec markers."
  if read_block "$n"; then
    # Keep every byte outside the markers: copy the lines before and after as they are.
    awk -v s="$START" -v e="$END" -v f="$tmp/new" '
      { l = $0; sub(/\r$/, "", l) }
      st == 0 && l == s { print; while ((getline x < f) > 0) print x; st = 1; next }
      st == 1 && l == e { st = 2 }
      st != 1 { printf "%s%s", $0, (NR < last || trail ? "\n" : "") }' \
      last="$(awk 'END {print NR}' "$tmp/body")" trail="$([ -z "$(tail -c1 "$tmp/body")" ] && echo 1)" \
      "$tmp/body" > "$tmp/out"
    action=replaced
  else
    { cat "$tmp/body"; printf '\n%s\n' "$START"; cat "$tmp/new"; printf '%s\n' "$END"; } > "$tmp/out"
    action=added
  fi
  gh issue edit "$n" --body-file "$tmp/out" >/dev/null
  printf '{"ok":true,"action":"%s","hash":"%s"}\n' "$action" "$(hash_of "$tmp/new")"
}

cmd_snapshot() {
  local n=${1:-} want=${2:-} h res rc
  pj_num "$n"
  case "$want" in sha256:*) ;; *) pj_die $PJ_EXIT_USAGE usage "spec.sh snapshot <n> <sha256:hex>" ;; esac
  pj_require_main
  read_block "$n" || pj_die $PJ_EXIT_ASK no-spec-block "Issue #$n has no complete spec block."
  h=$(hash_of "$tmp/block")
  [ "$h" = "$want" ] || pj_die $PJ_EXIT_ASK spec-changed "The spec block changed after the sign-off: $h."
  { printf '<!-- pj:spec %s -->\n' "$h"; cat "$tmp/block"; } > "$tmp/spec.md"
  set +e
  res=$("$(dirname "$0")/attach.sh" -m "docs(spec): snapshot #$n" "issues/$n/spec.md" "$tmp/spec.md")
  rc=$?
  set -e
  if [ $rc -ne 0 ]; then PJ_DONE=1; echo "$res"; exit $rc; fi
  printf '{"ok":true,"hash":"%s","path":"issues/%s/spec.md","commit":%s}\n' "$h" "$n" \
    "$(pj_json "$(echo "$res" | sed -n 's/.*"commit":"\([^"]*\)".*/\1/p')")"
}

case "${1:-}" in
  hash) shift; cmd_hash "$@" ;;
  set) shift; cmd_set "$@" ;;
  snapshot) shift; cmd_snapshot "$@" ;;
  *) pj_die $PJ_EXIT_USAGE usage "spec.sh hash <n> | set <n> <block-file> | snapshot <n> <sha256:hex>" ;;
esac
