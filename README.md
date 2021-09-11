```
lpg (Local PostGres): manage local PostgreSQL instances

Commands:

  lpg make <loc>

      Create an lpg-managed PostgreSQL instance at the specified location.
      The instance will be initialized with a superuser named 'postgres'
      Ex: lpg-make ./pg

  lpg shell (<loc> | --sandbox)

      Enter an interactive shell with a modified environment such that libpq
      commands, like psql and pg_ctl, will use the lpg instance at <loc>.

      If '--sandbox' is given, use a temporary anonymous lpg instance instead

      Environment modifications are:
        - LPG_IN_SHELL is set to '1'
        - LPG_LOC is set to an absolute version of <loc>
        - LPG_CONNSTR is set to a PostgrSQL connection string for the
          given lpg instance
        - PGDATA and PGHOST are set
        - pg_ctl is monkeypatched to:
          - log to <loc>/log
          - listen on the unix socket at <loc>/socket/.s.PGSQL.5432
          - not listen on any TPC ports
          If any of this is undesired behaviour, it can be overturned
          by passing your own command-line arguments to pg_ctl, i.e.:
            lpg shell ./pg
            pg_ctl start -o '--listen_addresses=127.0.0.1'

  lpg do <loc> <cmd>...

      Run a command on an lpg instance without affecting the shell
      Ex: lpg-do ./pg psql -U postgres

  lpg env (<loc> | --sandbox)

      Like 'lpg shell', but instead of entering an interactive shell, prints
      a sourceable bash script.
      Ex: source <(lpg env --sandbox) && pg_ctl start

  lpg help

      Show this message

```
