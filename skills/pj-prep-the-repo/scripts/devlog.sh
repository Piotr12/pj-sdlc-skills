#!/usr/bin/env bash
# Devlog for the human operator. One file per entry, so parallel runs never conflict.
# Usage:
#   devlog.sh [--tz <tz>] <skill> <target> <outcome> <note> [<note> ...]
#   devlog.sh view [--tz <tz>] [yyyy-mm-dd]   builds one page for the day, prints its path
# Timezone: --tz, else "timezone" in .pj/config.json, else UTC.
# Writing never fails the run: if attachments is not usable, the entry is printed instead.

. "$(dirname "$0")/lib.sh"

view=false
[ "${1:-}" = view ] && { view=true; shift; }
tz=""
[ "${1:-}" = --tz ] && { tz=${2:?}; shift 2; }
tz=${tz:-$(pj_tz)}
top=$(pj_top)

esc() { printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g' -e "s/'/\&#39;/g"; }

if $view; then
  day=${1:-$(TZ=$tz date +%F)}
  case "$day" in [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;; *) pj_die $PJ_EXIT_USAGE bad-day "$day" ;; esac
  git -C "$top" fetch -q origin "+refs/heads/$PJ_ATT:refs/remotes/origin/$PJ_ATT" 2>/dev/null || true
  out=$(mktemp -d "${TMPDIR:-/tmp}/pj-devlog-view.XXXXXX")/devlog-$day.html
  {
    # The page shows text from a shared branch: no scripts, no external loads.
    printf '<!doctype html><meta charset="utf-8"><meta http-equiv="Content-Security-Policy" content="default-src '"'none'"'; style-src '"'unsafe-inline'"'">\n'
    printf '<title>devlog %s</title>\n' "$day"
    printf '<style>body{font:15px/1.5 system-ui,sans-serif;max-width:900px;margin:24px auto;padding:0 16px}article{border-top:1px solid #ccc;padding:8px 0}h2{font-size:15px;margin:0}</style>\n'
    printf '<h1>devlog %s (%s)</h1>\n' "$day" "$(esc "$tz")"
    git -C "$top" ls-tree --name-only "origin/$PJ_ATT" "devlog/$day/" 2>/dev/null | sort \
      | while read -r f; do git -C "$top" show "origin/$PJ_ATT:$f" | sed -n '/<article>/,/<\/article>/p'; done || true
  } > "$out"
  printf '{"ok":true,"page":%s}\n' "$(pj_json "$out")"
  exit 0
fi

[ $# -ge 4 ] || pj_die $PJ_EXIT_USAGE usage "devlog.sh [--tz <tz>] <skill> <target> <outcome> <note> [<note> ...]"
skill=$1 target=$2 outcome=$3; shift 3
case "$skill" in *[!a-z0-9-]*|"") pj_die $PJ_EXIT_USAGE bad-skill "$skill" ;; esac

# Escaped first, so a link holds only URL characters and never closes the attribute.
link() { esc "$1" | sed -E 's#(https?://[^ &]+)#<a href="\1">\1</a>#g'; }

day=$(TZ=$tz date +%F)
time=$(TZ=$tz date +%H:%M)
stamp=$(TZ=$tz date +%H%M%S)
name="$stamp-$skill-$(pj_rand).html"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/pj-devlog.XXXXXX")
pj_cleanup() { rm -rf "$tmp"; }
{
  printf '<!doctype html><meta charset="utf-8"><title>%s %s</title>\n' "$time" "$skill"
  printf '<article>\n  <h2>%s %s · %s %s · %s</h2>\n  <ul>\n' "$time" "$(esc "$tz")" "$skill" "$(esc "$target")" "$(esc "$outcome")"
  for n in "$@"; do printf '    <li>%s</li>\n' "$(link "$n")"; done
  printf '  </ul>\n</article>\n'
} > "$tmp/$name"

set +e
res=$("$(dirname "$0")/attach.sh" -m "chore(devlog): $skill $target" "devlog/$day/$name" "$tmp/$name")
rc=$?
set -e
if [ $rc -eq 0 ]; then
  printf '{"ok":true,"pushed":true,"path":%s,"attach":%s}\n' "$(pj_json "devlog/$day/$name")" "$res"
else
  printf '{"ok":true,"pushed":false,"attach":%s,"entry":%s}\n' "$(pj_json "$res")" "$(pj_json "$(cat "$tmp/$name")")"
fi
