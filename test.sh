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
  echo
  echo "[[ ============ Testing: $1 ============ ]]"
  echo
}

fail() {
  echo "TEST FAILED: ${1:-test failed}"
  exit 1
}

run() {
  echo "RUNNING: $@"
  "$@"
}

export LC_ALL=C.UTF-8  # pg needs it for some reason

# ---------------------------------------------------------------------------- #
testing "create, start, query"
run lpg make ./testdir/pg
run lpg on ./testdir/pg cmd pg_ctl start
result=$(lpg on ./testdir/pg psql -tc 'SELECT 1, 2;')
echo "result: 〈$result〉"
[ "$result" = '        1 |        2' ] || fail

# ---------------------------------------------------------------------------- #
testing "create, query, auto"
run lpg make ./testdir/pg
result=$(echo 'psql -tc "SELECT 1, 2;"' | lpg on ./testdir/pg enter --auto)
echo "result: 〈$result〉"
[[ $result == *'        1 |        2'* ]] || fail

# ---------------------------------------------------------------------------- #
testing "create, query, auto: cleans up pg process?"
lpg make ./testdir/pg
out=$(echo 'echo "$LPG_LOC" && pg_ctl status' | lpg on ./testdir/pg enter --auto)
echo "$out"
pg_pid=$(echo "$out" | grep -oP '(?<=PID: )[0-9]+')
echo "pg pid: $pg_pid"
kill -0 "$pg_pid" 2>/dev/null && is_running=1 || is_running=0
(( $is_running )) && fail || true

# ---------------------------------------------------------------------------- #
testing "sandbox, auto, query"
result=$(echo $'psql -tc "SELECT 1, 2;"' | lpg sandbox)
echo "result: 〈$result〉"
[[ $result == *'        1 |        2'* ]] || fail

# ---------------------------------------------------------------------------- #
testing "sandbox: cleans up temp dir?"
loc=$(echo 'echo "$LPG_LOC"' | lpg sandbox)
echo "loc: $loc"
[ -n "$loc" ] || fail "LPG_LOC not printed"
[ ! -e "$loc" ] || fail "temp dir not cleaned up"

# ---------------------------------------------------------------------------- #
testing "sandbox: cleans up pg process?"
out=$(echo 'echo "$LPG_LOC" && pg_ctl status' | lpg sandbox)
echo "$out"
pg_pid=$(echo "$out" | grep -oP '(?<=PID: )[0-9]+')
echo "pg pid: $pg_pid"
kill -0 "$pg_pid" 2>/dev/null && is_running=1 || is_running=0
(( $is_running )) && fail || true

# ---------------------------------------------------------------------------- #
testing "convenience commands"
echo '~~ make'
lpg make ./testdir/pg ; [ "$?" = 0 ] || fail
echo '~~ get-connstr'
result=$(lpg on ./testdir/pg get-connstr -d my-db) ; [ "$?" = 0 ] || fail
[ "$result" = "postgresql://postgres@localhost/my-db?host=$(realpath ./testdir/pg)/socket" ] || fail
echo '~~ get-connstr'
result=$(lpg on ./testdir/pg get-connstr) ; [ "$?" = 0 ] || fail
[ "$result" = "postgresql://postgres@localhost/?host=$(realpath ./testdir/pg)/socket" ] || fail
echo '~~ up'
lpg on ./testdir/pg up ; [ "$?" = 0 ] || fail
echo '~~ up'
lpg on ./testdir/pg up ; [ "$?" = 0 ] || fail
echo '~~ down'
lpg on ./testdir/pg down ; [ "$?" = 0 ] || fail
echo '~~ down'
lpg on ./testdir/pg down ; [ "$?" = 0 ] || fail
echo '~~ restart'
lpg on ./testdir/pg restart ; [ "$?" = 0 ] || fail
echo '~~ echo LPG_LOC'
out=$(lpg on ./testdir/pg run 'echo $LPG_LOC')
echo "$out"
[ "$out" = "$(realpath ./testdir/pg)" ] || fail
