#!/usr/bin/env bash
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

export LC_ALL=C.UTF-8  # pg needs it for some reason

# ---------------------------------------------------------------------------- #
testing "create, start, query"
lpg make ./testdir/pg
lpg cmd ./testdir/pg pg_ctl start
result=$(lpg cmd ./testdir/pg psql -tc 'SELECT 1, 2;')
echo "result: $result"
[ "$result" = '        1 |        2' ] || fail

# ---------------------------------------------------------------------------- #
testing "sandbox, query"
reuslt=$(echo $'pg_ctl start && psql -tc "SELECT 1, 2;"' | lpg shell --sandbox)
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

# ---------------------------------------------------------------------------- #
testing "convenience commands"
echo '~~ make'
lpg make ./testdir/pg ; echo "$?"
echo '~~ start'
lpg pg-start ./testdir/pg ; echo "$?"
echo '~~ restart'
lpg pg-restart ./testdir/pg ; echo "$?"
echo '~~ stop'
lpg pg-stop ./testdir/pg ; echo "$?"
echo '~~ up'
lpg pg-up ./testdir/pg ; echo "$?"
echo '~~ up'
lpg pg-up ./testdir/pg ; echo "$?"
echo '~~ down'
lpg pg-down ./testdir/pg ; echo "$?"
echo '~~ down'
lpg pg-down ./testdir/pg ; echo "$?"
echo '~~ echo LPG_LOC'
out=$(lpg bash ./testdir/pg 'echo $LPG_LOC')
echo "$out"
[ "$out" = "$(realpath ./testdir/pg)" ] || fail
