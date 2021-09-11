#!/bin/env bash
set -euo pipefail

nix-build
function lpg { ./result/bin/lpg "$@"; }

cleanup() {
  rm -rf ./testdir
}
trap cleanup EXIT

testing() {
  rm -rf ./testdir
  mkdir ./testdir
  echo
  echo "[[ ============ Testing: $1 ============ ]]"
  echo
}

fail() {
  echo "TEST FAILED: ${1:-test failed}"
  exit 1
}

# ---------------------------------------------------------------------------- #
testing "create, start, query"
lpg make ./testdir/pg
lpg do ./testdir/pg pg_ctl start
result=$(lpg do ./testdir/pg psql -U postgres -tc 'SELECT 1, 2;')
echo "result: $result"
[ "$result" = '        1 |        2' ] || fail

# ---------------------------------------------------------------------------- #
testing "sandbox, query"
reuslt=$(echo $'pg_ctl start && psql -U postgres -tc "SELECT 1, 2;"' | lpg shell --sandbox)
echo "result: $result"
[ "$result" = '        1 |        2' ] || fail

# ---------------------------------------------------------------------------- #
testing "sandbox: cleans up temp dir?"
loc=$(echo 'echo "$LPG_LOC"' | lpg shell --sandbox)
echo "loc: $loc"
[ -n "$loc" ] || fail "LPG_LOC not printed"
[ ! -e "$loc" ] || fail "temp dir not cleaned up"

# ---------------------------------------------------------------------------- #
testing "sandbox: cleans up pg process?"
out=$(echo 'pg_ctl start && echo "$LPG_LOC" && pg_ctl status' | lpg shell --sandbox)
echo "$out"
pg_pid=$(echo "$out" | grep -oP '(?<=PID: )[0-9]+')
echo "pg pid: $pg_pid"
kill -0 "$pg_pid" 2>/dev/null && is_running=1 || is_running=0
(( $is_running )) && fail || true
