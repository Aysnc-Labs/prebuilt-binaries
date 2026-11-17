<div align="center">

<a href="https://github.com/Aysnc-Labs"><img src="https://avatars.githubusercontent.com/u/216275417?s=200" alt="Aysnc Labs" width="72"></a>

<h1>Prebuilt Binaries</h1>

Prebuilt binaries for [mise](https://mise.jdx.dev), built from source, tested,<br>
and signed with a GitHub artifact attestation.

<br>

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Install with mise](https://img.shields.io/badge/install%20with-mise-black)](https://mise.jdx.dev)

<sub>macOS arm64 &nbsp;·&nbsp; Linux x64 &nbsp;·&nbsp; Linux arm64</sub>

</div>

---

## Installation

Add the tools to your `mise.toml`, each pinned to a release tag:

```toml
[tools]
"github:aysnc-labs/prebuilt-binaries" = ["php-8.5.12", "postgres-18.7"]
```

A nightly job releases new upstream versions as new tags. The [releases page](https://github.com/aysnc-labs/prebuilt-binaries/releases) lists the current tags.

In GitHub Actions, grant the job `attestations: read`, because mise checks the attestation when it installs.

To check an archive by hand, run `gh attestation verify <archive> --repo aysnc-labs/prebuilt-binaries`.

## Tools

| Tool | What it contains |
|---|---|
| [PHP](recipes/php) | PHP CLI and FPM, static, with the extensions WordPress and Laravel use |
| [PostgreSQL](recipes/postgres) | PostgreSQL with its contrib modules, PostGIS, TimescaleDB, pgvector and more |
| [neon-proxy](recipes/neon-proxy) | Neon's proxy, with the Postgres auth backend for local development |
| [Redis](recipes/redis) | Redis with the JSON, Search, TimeSeries and Bloom modules loaded |

Each tool keeps its own license.
