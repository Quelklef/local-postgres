{ pkgs ? import <nixpkgs> {}
, postgresql ? pkgs.postgresql
}:

let

script = ''
#!${pkgs.bash}/bin/bash

function lpg-help {
  cat <<'EOF'
lpg (Local PostGres): manage local PostgreSQL instances

Basic Commands:

  lpg make <loc>
      Create an lpg-managed PostgreSQL instance at the specified location.
      The instance will be initialized with a superuser named 'postgres'
      Ex: lpg make ./pg

      This is a wrapper around initdb, plus some extra stuff.

  lpg on <loc> enter [--auto | -a]
      Enter an interactive bash shell with a modified environment such that libpq
      commands, like psql and pg_ctl, will use the lpg instance at <loc>.

      If --auto is given, start the instance when the shell is
      entered (unless it is already running), and stop the instance when the
      shell is exited (unless it has already stopped).

      Environment modifications are:
        - LPG_IN_SHELL is set to '1'
        - LPG_LOC is set to an absolute version of <loc>
        - PGDATA and PGHOST are set
        - pg_ctl is monkeypatched to:
            - log to <loc>/log
            - listen on the unix socket at <loc>/socket/.s.PGSQL.5432
            - not listen on any TPC ports
            These can be overturned by passing your own arguments,
            such as 'pg_ctl -l <some-log-loc>'
        - psql is monkeypatched to:
            - log in with user 'postgres' by default instead of $USER
              This can be overturned by calling 'psql -U <some-user>'
        - A bash function lpg-get-connstr() is defined which produces
          a PostgreSQL connection string for the lpg instance.
          The function signature matches 'lpg on <loc> get-connstr';
          see below.

  lpg on <loc> env [--auto | -a]
      Like 'lpg on <loc> enter', but instead of entering an interactive shell,
      prints a sourceable bash script.
      Ex: source <(lpg on ./pg enter) && pg_ctl start

  lpg help
      Show this message

Convenience Commands:

  lpg on <loc> cmd <cmd>...
      Run a command on an lpg instance
      Ex: lpg on ./pg cmd psql -U postgres -tc 'SELECT * FROM mytable;'

  lpg on <loc> run <str>
      Run a bash command on an lpg instance
      Ex: lpg on ./pg run 'pg_ctl stop && pg_ctl start'

  lpg on <loc> psql
      Equivalent to: lpg on <loc> cmd psql

  lpg on <loc> get-connstr [-d <target-database>]
      Prints the PostgreSQL connection string for an lpg instance,
      optionally targeting a database other than the default.

  lpg on <loc> up
      Start an lpg instance if it is not already running
      Equivalent to: lpg on <loc> run 'pg_ctl status || pg_ctl start'

  lpg on <loc> down
      Stop an lpg instance if it is running
      Equivalent to: lpg on <loc> run 'if pg_ctl status; then pg_ctl stop; else true; fi'

  lpg on <loc> restart
      Run 'down' and then 'up'

  lpg sandbox
      Create an anonymous temporary lpg instance and enter into
      its shell, automatically starting the postgres database
      and stopping it when the shell is exited.

EOF
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
