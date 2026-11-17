# neon-proxy

[Neon's](https://neon.com) `proxy` is the server [`@neondatabase/serverless`](https://github.com/neondatabase/serverless) talks to. With it, the driver runs against a local Postgres. It is built with:

```sh
cargo build --locked --release -p proxy --bin proxy --features testing
```

- `--features testing` adds `--auth-backend=postgres`, which reads roles from a plain Postgres instead of Neon's control plane.
- The toolchain comes from Neon's `rust-toolchain.toml`. The binary is stripped and renamed `neon-proxy`, and each archive carries Neon's `LICENSE`.
- No certificate is built in. Started without `--tls-key`/`--tls-cert`, the proxy serves plain WebSocket, so nothing expires. If you want TLS, generate a certificate when you start it.
- The version is Neon's proxy release number: upstream tag `release-proxy-<version>`. autobump follows new ones.

To run it against a local Postgres, first give the auth database an empty `neon_control_plane.endpoints(endpoint_id text primary key, allowed_ips text)` table. Then:

```sh
LOGFMT=text neon-proxy --auth-backend=postgres \
  --auth-endpoint=postgres://postgres:<password>@127.0.0.1:5432/postgres \
  --wss 127.0.0.1:4444
```

The driver then needs four settings:

- `neonConfig.useSecureWebSocket = false`;
- `neonConfig.wsProxy = () => 'localhost:4444/v2'`;
- a `localhost` host in the connection string, not an IP;
- `?options=endpoint%3Dlocal` in the connection string.

[`test.sh`](test.sh) runs the whole stack. CI runs it on every target, and on Linux it runs as root in a bare `ubuntu:24.04` container.

By default the proxy also listens on 4432 (`--proxy`), 7000 (`--mgmt`) and 7001 (`--http`). Set them explicitly to run more than one.

## License

Neon's proxy is [Apache 2.0](https://github.com/neondatabase/neon/blob/main/LICENSE).
