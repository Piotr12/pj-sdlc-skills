#!/usr/bin/env bash
# Entry point of the plugin hook. The guard lives in the pj scripts, so that prep copies it to target repos.
exec "$(dirname "$0")/../skills/pj-prep-the-repo/scripts/pj-guard.sh" "$@"
