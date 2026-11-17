# postgres

PostgreSQL with every contrib module and these extensions: PostGIS (without raster), TimescaleDB (Apache-licensed part only), pgvector, pg_cron, pg_partman, pg_hint_plan, hypopg, pgaudit, pg_repack and wal2json. Each is pinned to an upstream tag in `recipe.yaml`, and autobump follows new ones.

Built with OpenSSL, ICU, LZ4, Zstandard, libxml2, libxslt, libedit and uuid. Every shared library outside the OS is copied into `lib/`, with its licence in `licenses/`, so nothing needs installing. Linux builds run on Ubuntu 22.04, so they need glibc 2.35 or newer.

The install is relocatable: it finds its `share/` and `lib/` from where the binaries are.

timescaledb, pg_cron, pgaudit, pg_hint_plan and pg_stat_statements need `shared_preload_libraries`. pg_cron also needs `cron.database_name`, and wal2json needs `wal_level = logical` and `output_plugin_libraries = 'wal2json'`.

Postgres won't run as root. As root, run it as another user with `runuser -u <user> --`.
