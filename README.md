```
lpg (Local PostGres): manage local PostgreSQL instances

Commands:

  lpg make LOC

      Create an lpg-managed PostgreSQL instance at the specified location.
      The instance will be initialized with a superuser named 'postgres'
      Ex: lpg-make ./pg

  lpg shell (LOC | --anon)

      Enter an interactive shell with a modified environment such that libpq
      commands, like psql and pg_ctl, will use the lpg instance at LOC

      If '--anon' is given, use a temporary anonymous lpg instance instead

      Environment modifications are:
        - LPG_IN_SHELL is set to '1'
        - LPG_LOC is set to an absolute versin of LOC
          This can come in handy when using 'lpg sandbox'
        - LPG_CONNSTR is set to a PostgrSQL connection string for the
          given lpg instance
        - PGDATA, PGHOST, and PGPORT are set, and pg_ctl is monkeypatched

  lpg do LOC CMD...

      Run a command on an lpg instance without affecting the shell
      Ex: lpg-do ./pg psql -U postgres

  lpg env (LOC | --anon)

      Like 'lpg shell', but instead of entering an interactive shell, prints
      a sourceable bash script.
      Ex: source <(lpg env --anon) && pg_ctl start

  lpg sandbox

      Synonym for 'lpg shell --anon'

  lpg help

      Show this message

```
