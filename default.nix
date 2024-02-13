{ pkgs ? import <nixpkgs> {}
, postgresql ? pkgs.postgresql
}:

let

script = ''
#!${pkgs.bash}/bin/bash

function lpg-help {
  echo ${pkgs.lib.escapeShellArg (builtins.readFile ./README.txt)}
}

function lpg-make {
  [[ $# = 1 ]] || { echo >&2 "Expected exactly 1 argument"; return 1; }
  [[ -e "$1" ]] && { echo >&2 "$1 already exists"; return 1; }
  local dir=$(realpath "$1")

  mkdir -p "$dir"/{cluster,socket} || return 1
  touch "$dir"/log || return 1
  ${postgresql}/bin/initdb "$dir"/cluster -U postgres || return 1
}

function lpg-env {
  [[ $# -ge 1 ]] || { echo >&2 "Expected at least 1 argument"; return 1; }

  [[ -d "$1" ]] || { echo >&2 "$1 does not exist"; return 1; }
  local dir=$(realpath "$1")

  do_auto=
  [ "$2" = '--auto' -o "$2" = '-a' ] && do_auto=1 || do_auto=0

  cat <<EOF

export PGDATA=$dir/cluster
export PGHOST=$dir/socket

export LPG_IN_SHELL=1
export LPG_LOC=$dir

function pg_ctl {
  ${postgresql}/bin/pg_ctl \\
    -l "$dir"/log \\
    -o "--unix_socket_directories='$dir/socket'" \\
    -o '--listen_addresses=""' \\
    "\$@"
}
export -f pg_ctl

function psql {
  ${postgresql}/bin/psql \\
    -U postgres \\
    "\$@"
}
export -f psql

function lpg-get-connstr {
  local db=
  case "\$1" in
    -d) shift; db="\$1"; shift ;;
    "") ;;
    *) echo >&2 "Bad call to lpg-get-connstr. Called like: lpg-get-connstr \$@"; return 1 ;;
  esac
  echo "postgresql://postgres@localhost/\$db?host=$dir/socket"
}

EOF

  (( $do_auto )) && cat <<EOF
pg_ctl status >/dev/null || pg_ctl start
lpg-cleanup() { pg_ctl status >/dev/null && pg_ctl stop; }
trap lpg-cleanup EXIT INT TERM
EOF

}

function lpg-enter {
  ( source <(lpg-env "$@") && bash )
}

function lpg-cmd {
  [[ $# -ge 2 ]] || { echo >&2 "Expected 2 or more arguments"; return 1; }
  [[ -d "$1" ]] || { echo >&2 "$1 does not exist or is not a directory."; return 1; }
  local dir=$1; shift;

  ( source <(lpg-env "$dir") && "$@" )
}

function lpg-run {
  [[ $# -eq 2 ]] || { echo >&2 "Expected exactly 2 arguments"; return 1; }
  [[ -d "$1" ]] || { echo >&2 "$1 does not exist or is not a directory."; return 1; }
  local dir=$1; shift;
  local str=$1; shift;

  ( source <(lpg-env "$dir") && bash -c "$str" )
}


function _main {

  # Validate
  case "$1" in
    make|on|help|sandbox ) ;;
    * ) lpg-help; exit 0 ;;
  esac

  # Rewrite 'lpg on <loc> <cmd> <args>...' to 'lpg <cmd> <loc> <args>...'
  if [ "$1" = 'on' ]; then
    shift
    loc="$1"; shift
    cmd="$1"; shift
    set -- "$cmd" "$loc" "$@"
  fi

  local cmd_name="$1"; shift;

  case "$cmd_name" in
    # Basic commands
    make       ) lpg-make "$@" ;;
    env        ) lpg-env "$@" ;;
    enter      ) lpg-enter "$@" ;;

    # Derived commands
    cmd         ) lpg-cmd "$@" ;;
    run         ) lpg-run "$@" ;;
    psql        ) local dir="$1"; shift; lpg-cmd "$dir" psql "$@" ;;
    get-connstr ) local dir="$1"; shift; lpg-cmd "$dir" lpg-get-connstr "$@" ;;
    up          ) local dir="$1"; shift; lpg-run "$dir" 'pg_ctl status || pg_ctl start' ;;
    down        ) local dir="$1"; shift; lpg-run "$dir" 'if pg_ctl status; then pg_ctl stop; else true; fi' ;;
    restart     ) local dir="$1"; shift; lpg-run "$dir" 'if pg_ctl status; then pg_ctl stop; else true; fi; pg_ctl start' ;;
    sandbox     ) local dir=$(mktemp -du) && lpg-make "$dir" && lpg-enter "$dir" --auto && rm -rf "$dir" ;;

    # Help
    help       ) lpg-help ;;
    *          ) lpg-help ;;
  esac

}

_main "$@"

'';

in

pkgs.writeScriptBin "lpg" script
