# redis

Redis with the modules the official `redis:8` image loads: JSON, Search (the Query Engine), TimeSeries and Bloom. Vector sets are part of the server itself. It is built from the release tarball, which carries every module's source, so the tarball's sha256 pins them all.

`bin/redis-server` loads every module by itself, as the official image does. It passes `--loadmodule` for each file in `lib/redis/modules/` to the real server in `libexec/`, after the config file when you give one. `--sentinel`, `redis-sentinel` and the check tools skip the modules.

How it's built:

- On Linux it's built on Ubuntu 22.04 with GCC 12, for a glibc 2.35 floor. OpenSSL, which TimeSeries and Search link, is bundled into `lib/`.
- RediSearch is built without LTO. Its LTO build needs Clang and lld at the LLVM version of its Rust toolchain.
- RediSearch's CMake would download Boost unpinned, so the recipe fetches it by sha256 into the folder RediSearch looks in first. If a new Redis wants another Boost, the build stops and names it. Move `boost.tag` and run `bin/lock redis`.
- Rust crates for JSON and Search come from crates.io, checked against each module's `Cargo.lock`.
- The server is built without TLS. It would tie the binaries to the system's OpenSSL, and local development doesn't need it.

`test.sh` checks every module and the clients our apps use, each against a live server:

- Laravel: phpredis from our PHP release, running Laravel's queue push and pop Lua scripts (`cjson`), cache and tag sets.
- Next.js: node-redis pub/sub and hashes, as cache handlers use them, and JSON documents with a Search index, as the `redis-stack` cache handler uses them.
- NestJS: a BullMQ job round trip with a delay and retries (Lua, `cmsgpack`, streams, blocking pops), and ioredis.

To start it:

```sh
redis-server --port 6379 --save "" --appendonly no
```

## License

Redis 8 and its modules are tri-licensed: [AGPL-3.0, SSPL-1.0 or RSALv2](https://github.com/redis/redis/blob/unstable/LICENSE.txt), at your choice. The licences of the modules and vendored dependencies are in each archive's `licenses/`.
