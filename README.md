# Aysnc Prebuilt Binaries

PHP, PostgreSQL and more, built from source, tested and signed, ready to install with [mise](https://mise.jdx.dev).

| Tool | Version |
|---|---|
| [PHP](recipes/php) | 8.5, static, WordPress and Laravel extensions |
| [PostgreSQL](recipes/postgres) | 18, with PostGIS, TimescaleDB, pgvector and more |
| [neon-proxy](recipes/neon-proxy) | Neon's local proxy |

macOS arm64, Linux x64 and Linux arm64.

```toml
[tools]
"github:aysnc-labs/prebuilt-binaries" = ["php-8.5.12", "postgres-18.7"]
```

Pin a tag. Tags update nightly; see [releases](https://github.com/aysnc-labs/prebuilt-binaries/releases). In GitHub Actions, grant `attestations: read`.

To add a tool, see [CONTRIBUTING.md](CONTRIBUTING.md). MIT; each tool keeps its own licence.
