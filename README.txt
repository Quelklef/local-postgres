lpg (Local PostGres): manage local PostgreSQL instances


Basic Commands:

  lpg make <loc>

      Create an lpg-managed PostgreSQL instance at the specified location.
      The instance will be initialized with a superuser named 'postgres'
      Ex: lpg make ./pg

  lpg shell (<loc> | --sandbox)

      Enter an interactive shell with a modified environment such that libpq
      commands, like psql and pg_ctl, will use the lpg instance at <loc>.

      If '--sandbox' is given, use a temporary anonymous lpg instance instead

      Environment modifications are:
        - LPG_IN_SHELL is set to '1'
        - LPG_LOC is set to an absolute version of <loc>
        - LPG_CONNSTR is set to a PostgreSQL connection string for the
          given lpg instance
        - PGDATA and PGHOST are set
        - pg_ctl is monkeypatched to:
            - log to <loc>/log
            - listen on the unix socket at <loc>/socket/.s.PGSQL.5432
            - not listen on any TPC ports
        - psql is monkeypatched to:
            - log in with user postgres by default instead of sock
          Note that this behaviour can be overturned by passing your
          own CLI arguments, e.g. 'psql -U sock'

  lpg env (<loc> | --sandbox)

      Like 'lpg shell', but instead of entering an interactive shell, prints
      a sourceable bash script.
      Ex: source <(lpg env --sandbox) && pg_ctl start

  lpg help

      Show this message


Derived Commands:

  Convenience commands built on top of the basic commands

  lpg cmd <loc> <cmd>...
      Run a command on an lpg instance without affecting the shell
      Ex: lpg cmd ./pg psql -U postgres -tc 'SELECT * FROM mytable;'

  lpg bash <loc> <str>
      Run a bash command on an lpg instance
      Ex: lpg bash ./pg 'pg_ctl stop && pg_ctl start'

  lpg pg-start <loc>
      Start an lpg instance.
      Equivalent to: lpg cmd <loc> pg_ctl start

  lpg pg-up <loc>
      Start an lpg instance if it is not already running
      Equivalent to: lpg bash <loc> 'pg_ctl status || pg_ctl start'

  lpg pg-stop <loc>
      Stop an lpg instance.
      Equivalent to: lpg cmd <loc> pg_ctl stop

  lpg pg-down <loc>
      Stop an lpg instance if it is running
      Equivalent to: lpg bash <loc> 'if pg_ctl status; then pg_ctl stop; else true; fi'

  lpg pg-restart <loc>
      Restart an lpg instance.
      Equivalent to: lpg bash <loc> 'pg_ctl stop && pg_ctl start'

