# redis

Redis server, CLI, benchmark and Sentinel, built from the release tarball with Redis's vendored jemalloc, Lua and hiredis. The binaries link only against the C library. It's core Redis: no JSON, Search, TimeSeries or Bloom modules, and no TLS.

`test.sh` proves it works with the clients our apps use, each against a live server:

- Laravel: phpredis from our PHP release, running Laravel's queue push and pop Lua scripts (`cjson`), cache and tag sets.
- Next.js: node-redis pub/sub and hashes, as cache handlers use them.
- NestJS: a BullMQ job round trip with a delay and retries (Lua, `cmsgpack`, streams, blocking pops), and ioredis.

To start it:

```sh
redis-server --port 6379 --save "" --appendonly no
```

## License

Redis 8 is tri-licensed: [AGPL-3.0, SSPL-1.0 or RSALv2](https://github.com/redis/redis/blob/unstable/LICENSE.txt), at your choice. The licences of the vendored dependencies are in each archive's `licenses/`.
