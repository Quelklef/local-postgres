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

