#!/usr/bin/env bash
# Replays the pj-prep-the-repo scripts against throwaway repos with a bare origin
# and a fake gh. Covers re-runs, crash leftovers, parallel devlog writes, the safety
# checks, and the guard hook.
# Usage: bash tests/prep-scripts.sh   (no network, no GitHub)

set -uo pipefail
S="$(cd "$(dirname "$0")/../skills/pj-prep-the-repo/scripts" && pwd)"
ROOT=$(mktemp -d "${TMPDIR:-/tmp}/pj-test.XXXXXX")
trap '[ -n "${KEEP:-}" ] || rm -rf "$ROOT"' EXIT
G="$(cd "$(dirname "$0")/../hooks" && pwd)/pj-guard.sh"
pass=0 fail=0

export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

mkdir -p "$ROOT/bin"
cat > "$ROOT/bin/gh" <<'EOF'
#!/usr/bin/env bash
# Fake gh. State: $FAKE_GH/labels, $FAKE_GH/rulesets (names),
# $FAKE_GH/prs ("<n> <STATE> <branch> <url> <isCrossRepository>"). FAKE_GH_FAIL=1 fails every call.
st=$FAKE_GH; touch "$st/labels" "$st/prs" "$st/rulesets"
[ -n "${FAKE_GH_FAIL:-}" ] && { echo "fake gh: failure" >&2; exit 1; }
if [ "$1" = api ]; then
  case "$*" in
    *"-X POST"*rulesets*) while [ $# -gt 0 ]; do [ "$1" = --input ] && f=$2; shift; done
      sed -n 's/.*"name": *"\([^"]*\)".*/\1/p' "$f" | head -1 >> "$st/rulesets" ;;
    *rulesets*) cat "$st/rulesets" ;;
    *) echo "fake gh: unsupported: $*" >&2; exit 1 ;;
  esac
  exit 0
fi
case "$1 $2" in
  "auth status") ;;
  "label list") cat "$st/labels" ;;
  "label create") echo "$3" >> "$st/labels" ;;
  "pr list") cat "$st/prs" ;;
  "pr create")
    while [ $# -gt 0 ]; do [ "$1" = --head ] && head=$2; shift; done
    n=$(( $(wc -l < "$st/prs") + 1 ))
    echo "$n OPEN $head https://example.test/pull/$n false" >> "$st/prs"
    echo "https://example.test/pull/$n" ;;
  "pr edit") echo "$3" >> "$st/edits" ;;
  *) echo "fake gh: unsupported: $*" >&2; exit 1 ;;
esac
EOF
chmod +x "$ROOT/bin/gh"
export PATH="$ROOT/bin:$PATH"

# new_repo <name> [empty|<default branch>] -> creates $ROOT/<name>/{origin.git,work}; cd into work
new_repo() {
  local d="$ROOT/$1" b=main
  [ -n "${2:-}" ] && [ "$2" != empty ] && b=$2
  mkdir -p "$d/gh"; export FAKE_GH="$d/gh"
  git init -q --bare -b "$b" "$d/origin.git"
  git clone -q "$d/origin.git" "$d/work" 2>/dev/null
  cd "$d/work"
  if [ "${2:-}" != empty ]; then
    git checkout -q -b "$b" 2>/dev/null || true
    echo hi > README.md; git add README.md; git commit -q -m init; git push -q origin "$b"
  fi
}

ok() { # <desc> <command...>
  local d=$1; shift
  if "$@" >/dev/null 2>&1; then pass=$((pass + 1)); echo "  ok   $d"
  else fail=$((fail + 1)); echo "  FAIL $d"; fi
}
field() { sed -n "s/.*\"$1\":\"\{0,1\}\([^\",}]*\).*/\1/p"; } # <key> <<< json
run() { out=$("$@" 2>&1); rc=$?; }

echo "fresh repo, full run, then a second run"
new_repo fresh
run "$S/prep.sh" status;      ok "status ok"                    test "$(echo "$out" | field gitOk)" = true
run "$S/prep.sh" exclude;     ok "exclude added"                test "$(echo "$out" | field action)" = added
run "$S/prep.sh" exclude;     ok "exclude second run"           test "$(echo "$out" | field action)" = exists
run "$S/prep.sh" labels;      ok "labels created"               grep -qx spec-ready "$FAKE_GH/labels"
run "$S/prep.sh" labels;      ok "labels second run: none"      test "$(echo "$out" | field created)" = ""
run "$S/prep.sh" attachments; ok "attachments created"          test "$(echo "$out" | field action)" = created
ok "attachments on origin"    git ls-remote --exit-code origin attachments
run "$S/prep.sh" attachments; ok "attachments second run"       test "$(echo "$out" | field action)" = exists
run "$S/prep.sh" worktree;    ok "prep worktree created"        test "$(echo "$out" | field action)" = created
echo x > .worktrees/prep/AGENTS.md; echo body > "$ROOT/body.md"
run "$S/prep.sh" pr "$ROOT/body.md"; ok "PR created"            test "$(echo "$out" | field action)" = created
ok "prep worktree removed"    test ! -d .worktrees/prep
run "$S/prep.sh" worktree;    ok "rerun reuses open PR"         test "$(echo "$out" | field action)" = reuse-pr
run "$S/prep.sh" pr "$ROOT/body.md"; ok "rerun updates, no 2nd PR" test "$(wc -l < "$FAKE_GH/prs" | tr -d ' ')" = 1

echo "previous prep PR merged"
git push -q origin pj/prep-the-repo:main; git fetch -q origin
sed -i.bak 's/ OPEN / MERGED /' "$FAKE_GH/prs"
run "$S/prep.sh" worktree;    ok "new branch after merged PR"   sh -c "echo '$out' | grep -q 'pj/prep-the-repo-'"
run "$S/prep.sh" pr "$ROOT/body.md"; ok "no changes: no PR"     test "$(echo "$out" | field reason)" = no-changes

echo "crash: worktree created, no PR yet"
new_repo crash-pr
"$S/prep.sh" worktree >/dev/null; echo y > .worktrees/prep/AGENTS.md
git -C .worktrees/prep add -A; git -C .worktrees/prep commit -q -m wip
git worktree remove --force .worktrees/prep
run "$S/prep.sh" worktree;    ok "resumes leftover branch"      test "$(echo "$out" | field action)" = resume
run "$S/prep.sh" pr "$ROOT/body.md"; ok "then opens the PR"     test "$(echo "$out" | field action)" = created

echo "crash: orphan worktree added, no commit"
new_repo crash-unborn
git worktree add -q --orphan -b attachments .worktrees/attachments
run "$S/prep.sh" attachments; ok "recovers unborn branch"       test "$(echo "$out" | field action)" = recovered-commit
ok "attachments on origin"    git ls-remote --exit-code origin attachments

echo "crash: committed, not pushed"
new_repo crash-push
git worktree add -q --orphan -b attachments .worktrees/attachments
git -C .worktrees/attachments commit -q --allow-empty -m first
run "$S/prep.sh" attachments; ok "pushes the local branch"      test "$(echo "$out" | field action)" = recovered-push

echo "attachments shares history with main"
new_repo not-orphan
git push -q origin main:attachments
run "$S/prep.sh" attachments; ok "stops with exit 3"            test $rc -eq 3
run "$S/attach.sh" -m m issues/1/a.txt README.md; ok "attach refuses" sh -c "test $rc -eq 3 && echo '$out' | grep -q attachments-not-orphan"

echo "empty origin"
new_repo empty empty
run "$S/prep.sh" worktree;    ok "stops with exit 4"            test $rc -eq 4
run "$S/prep.sh" attachments; ok "attachments also exit 4"      test $rc -eq 4
ok "nothing pushed"           test -z "$(git ls-remote origin)"

echo "devlog"
new_repo devlog
run "$S/devlog.sh" pj-test "#1" done "no attachments yet"
ok "no attachments: entry printed, exit 0" sh -c "test $rc -eq 0 && echo '$out' | grep -q '\"pushed\":false'"
"$S/prep.sh" attachments >/dev/null
git clone -q "$ROOT/devlog/origin.git" "$ROOT/devlog/other" 2>/dev/null
( cd "$ROOT/devlog/other" && git fetch -q origin attachments )
run "$S/devlog.sh" --tz Europe/Berlin pj-test "#1" done "first https://example.test/1"
ok "entry pushed"             test "$(echo "$out" | field pushed)" = true
ok "entry dated in its timezone" sh -c "echo '$out' | grep -q \"devlog/$(TZ=Europe/Berlin date +%F)/\""
run "$S/devlog.sh" --tz UTC pj-test "#1" done "same day as the parallel writes"
( cd "$ROOT/devlog/other" && "$S/devlog.sh" pj-test "#2" done "second clone" ) > "$ROOT/o2"
ok "second clone pushes"      grep -q '"pushed":true' "$ROOT/o2"
# Parallel writers race for the same branch: pushes get rejected and must retry.
for i in 1 2 3 4 5 6; do ( "$S/devlog.sh" pj-par "#$i" done "parallel $i" > "$ROOT/par$i" ) & done; wait
ok "6 parallel writes pushed" test "$(cat "$ROOT"/par* | grep -c '"pushed":true')" = 6
ok "a rejected push retried"  grep -q '"retries":[1-9]' "$ROOT"/par1 "$ROOT"/par2 "$ROOT"/par3 "$ROOT"/par4 "$ROOT"/par5 "$ROOT"/par6
run "$S/devlog.sh" view;      page=$(echo "$out" | field page)
ok "view shows all 8 entries" test "$(grep -c '<article>' "$page")" = 8
ok "view is valid nesting"    test "$(grep -c '</article>' "$page")" = 8
ok "config timezone default"  test "$("$S/prep.sh" status | field timezone)" = UTC

echo "default branch is not main: stop before any change"
new_repo on-master master
run "$S/prep.sh" status;      ok "status reports master"        test "$(echo "$out" | field mainOk)" = false
run "$S/prep.sh" labels;      ok "labels exit 3"                test $rc -eq 3
ok "no labels created"        test ! -s "$FAKE_GH/labels"
run "$S/prep.sh" attachments; ok "attachments exit 3"           test $rc -eq 3
ok "no attachments pushed"    test -z "$(git ls-remote origin attachments)"

echo "shallow and single-branch clones"
new_repo clones; "$S/prep.sh" attachments >/dev/null
git clone -q --depth 1 "file://$ROOT/clones/origin.git" "$ROOT/clones/shallow" 2>/dev/null
( cd "$ROOT/clones/shallow" && "$S/prep.sh" attachments ) > "$ROOT/sh.out"; rc=$?
ok "shallow clone: exit 3"    sh -c "test $rc -eq 3 && grep -q shallow-clone '$ROOT/sh.out'"
git clone -q --single-branch -b main "$ROOT/clones/origin.git" "$ROOT/clones/single" 2>/dev/null
( cd "$ROOT/clones/single" && "$S/devlog.sh" pj-test "#1" done "single-branch" ) > "$ROOT/sb.out"
ok "single-branch clone writes" grep -q '"pushed":true' "$ROOT/sb.out"

echo "fork PRs, secrets in the PR, body file"
new_repo forks
echo "7 OPEN pj/prep-the-repo https://example.test/pull/7 true" >> "$FAKE_GH/prs"
run "$S/prep.sh" worktree;    ok "fork PR is ignored"           test "$(echo "$out" | field action)" = created
echo SECRET=1 > .worktrees/prep/.env; echo x > .worktrees/prep/AGENTS.md
run "$S/prep.sh" pr "$ROOT/body.md"; ok ".env refused, exit 3"   sh -c "test $rc -eq 3 && echo '$out' | grep -q sensitive-files"
ok "nothing pushed"           test -z "$(git ls-remote origin 'pj/*')"
rm .worktrees/prep/.env; echo b > .worktrees/prep/body.md
run "$S/prep.sh" pr .worktrees/prep/body.md; ok "body file in worktree refused" test $rc -eq 2
rm .worktrees/prep/body.md
run "$S/prep.sh" pr "$ROOT/body.md"; ok "then the PR opens"      test "$(echo "$out" | field action)" = created

echo "rulesets"
run "$S/prep.sh" rulesets;    ok "both missing"                 test "$(echo "$out" | field missing)" = "pj-main pj-attachments"
run "$S/prep.sh" rulesets --apply; ok "both created"            test "$(echo "$out" | field created)" = "pj-main pj-attachments"
run "$S/prep.sh" rulesets;    ok "both present"                 test "$(echo "$out" | field present)" = "pj-main pj-attachments"

echo "attachments safety"
new_repo safety; "$S/prep.sh" attachments >/dev/null
printf '#!/bin/sh\nexit 1\n' > .git/hooks/pre-commit; printf '#!/bin/sh\nexit 1\n' > .git/hooks/pre-push
chmod +x .git/hooks/pre-commit .git/hooks/pre-push
run "$S/attach.sh" -m m issues/1/a.txt README.md; ok "repo hooks do not block attachments" test "$(echo "$out" | field pushed)" = true
run "$S/attach.sh" -m m .github/workflows/x.yml README.md; ok "workflow destination refused" test $rc -eq 3
run "$S/attach.sh" -m m notes/x.txt README.md; ok "destination outside issues/prs/devlog refused" test $rc -eq 3
ln -s /etc/hosts "$ROOT/link"
run "$S/attach.sh" -m m issues/1/l README.md issues/1/h "$ROOT/link"; ok "symlink source refused" test $rc -eq 3
ok "no-scan warning shown"    sh -c "command -v gitleaks >/dev/null || echo '$("$S/attach.sh" -m m issues/2/a.txt README.md)' | grep -q 'not scanned'"
run "$S/devlog.sh" pj-test "#9" done 'evil https://x.test/a"onmouseover=alert(1) <script>x</script>'
run "$S/devlog.sh" view;      page=$(echo "$out" | field page)
ok "no attribute break-out"   sh -c "! grep -q '\"onmouseover' '$page'"
ok "no script tag"            sh -c "! grep -q '<script>' '$page'"
ok "view page blocks scripts" grep -q "Content-Security-Policy" "$page"
FAKE_GH_FAIL=1 run "$S/prep.sh" labels
ok "unexpected failure still prints JSON" sh -c "echo '$out' | grep -q '\"reason\":\"unexpected\"'"

echo "guard hook"
new_repo guard; mkdir -p .pj; echo '{}' > .pj/config.json
gcase() { # <expect 0|2> <command>
  local r
  printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$2" | "$G" >/dev/null 2>&1; r=$?
  ok "guard $1: $2" test $r -eq "$1"
}
gcase 2 "git push --force origin pj/1"
gcase 2 "git push -f"
gcase 2 "git push origin +pj/1"
gcase 2 "git push origin main"
gcase 2 "git push origin HEAD:main"
gcase 2 "git push origin --delete pj/1"
gcase 2 "git push origin :pj/1"
gcase 2 "gh pr merge 3 --squash"
gcase 2 "gh issue close 4"
gcase 2 "gh api -X DELETE repos/o/r/git/refs/heads/x"
gcase 2 "gh secret set TOKEN"
gcase 2 "echo x > .github/workflows/ci.yml"
gcase 0 "git push -u origin pj/42"
gcase 0 "git push origin HEAD:attachments"
gcase 0 "git push origin pj/main-fix"
gcase 0 "gh pr create --draft"
gcase 0 "gh pr ready 3"
gcase 0 "git status"
rm -rf .pj
gcase 0 "gh pr merge 3"

echo; echo "$pass passed, $fail failed"
[ $fail -eq 0 ]
