\set QUIET on
create extension vector;
create extension pg_cron;
create schema partman;
create extension pg_partman schema partman;
create extension hypopg;
create extension pgaudit;
create extension pg_repack;
create extension pg_stat_statements;
create extension pgcrypto;
create extension "uuid-ossp";
create extension hstore;
create extension citext;
create extension pg_trgm;
create extension btree_gin;
create extension btree_gist;
create extension unaccent;
create extension fuzzystrmatch;
create extension tablefunc;
create extension postgres_fdw;
create extension xml2;
create extension postgis;
create extension postgis_topology;
create extension timescaledb;

do $$
begin
  assert (select '[1,2,3]'::vector <-> '[1,2,4]'::vector) = 1, 'pgvector';
  assert (select count(*) from cron.job) = 0, 'pg_cron';
  assert similarity('postgres', 'postgis') > 0, 'pg_trgm';
  assert unaccent('Crème brûlée') = 'Creme brulee', 'unaccent';
  assert 'ABC'::citext = 'abc'::citext, 'citext';
  assert length(gen_random_uuid()::text) = 36 and length(uuidv7()::text) = 36, 'uuids';
  assert length(uuid_generate_v4()::text) = 36, 'uuid-ossp';
  assert digest('x', 'sha256') is not null, 'pgcrypto (OpenSSL)';
  assert current_setting('ssl_library') = 'OpenSSL', 'OpenSSL';
  assert xpath_string('<a>b</a>', '/a') = 'b', 'xml2 (libxslt)';
  assert levenshtein('kitten', 'sitting') = 3, 'fuzzystrmatch';
end $$;

create collation german (provider = icu, locale = 'de-DE');
do $$ begin assert 'ä' < 'b' collate german, 'ICU'; end $$;

create table compressed (t text compression lz4);
insert into compressed select repeat('x', 100000);
do $$ begin assert (select pg_column_compression(t) from compressed) = 'lz4', 'lz4'; end $$;
set default_toast_compression = 'lz4';

create table items (id int, v vector(3));
create index on items using hnsw (v vector_l2_ops);
select count(*) from hypopg_create_index('create index on items (id)');

create table events (at timestamptz not null) partition by range (at);
select partman.create_parent('public.events', 'at', '1 day');

select 'init' from pg_create_logical_replication_slot('w2j', 'wal2json');
insert into items values (1, '[1,1,1]');
do $$ begin assert (select count(*) from pg_logical_slot_get_changes('w2j', null, null)) > 0, 'wal2json'; end $$;
select pg_drop_replication_slot('w2j');

do $$
begin
  assert (select round(ST_X(ST_Transform(ST_SetSRID(ST_MakePoint(1, 0), 4326), 3857)))) = 111319, 'PostGIS with PROJ data';
  assert (select ST_Distance('POINT(0 0)'::geography, 'POINT(1 0)'::geography) > 111000), 'PostGIS geography';
  assert (select ST_Area(ST_Buffer('POINT(0 0)'::geometry, 1)) > 3), 'PostGIS with GEOS';
end $$;
select length(ST_AsMVT(t)) > 0 from (select ST_AsMVTGeom('POINT(1 1)'::geometry, ST_MakeEnvelope(0, 0, 4, 4)) as geom) t;

create table metrics (at timestamptz not null, v double precision);
select create_hypertable('metrics', by_range('at')) is not null;
insert into metrics select now() - n * interval '1 hour', n from generate_series(1, 100) n;
do $$ begin assert (select count(*) from timescaledb_information.chunks where hypertable_name = 'metrics') > 0, 'TimescaleDB'; end $$;

/*+ SeqScan(items) */ select count(*) from items;
select 'all extensions work';
