# prebuilt-binaries

Prebuilt binaries of tools for Aysnc projects. Each **tool** is built from a **recipe** in `recipes/`, for every **target** the recipe lists, in GitHub Actions. It is tested, published as a GitHub release, and installed with mise's [`github:` backend](https://mise.jdx.dev/dev-tools/backends/github.html).

| Tool | Binaries | Targets | Recipe |
|---|---|---|---|
| Neon's local proxy | `neon-proxy` | macOS arm64, Linux x64, Linux arm64 (glibc 2.39+) | [`recipes/neon-proxy`](recipes/neon-proxy) |
| PHP 8.5, static, with WordPress and Laravel's extensions | `php`, `php-fpm` | macOS arm64, Linux x64, Linux arm64 (any libc) | [`recipes/php`](recipes/php) |
| PostgreSQL 18 with contrib and popular extensions | `postgres`, `psql`, `pg_ctl`, `initdb`, `pg_dump`, … | macOS arm64, Linux x64, Linux arm64 (glibc 2.35+) | [`recipes/postgres`](recipes/postgres) |

## Install

A release's tag is `<tool>-<version>`, plus `-<revision>` when the same upstream version is rebuilt. Pin it, because the repo's "latest" release can belong to any tool.

```toml
# mise.toml
[tools]
"github:aysnc-labs/prebuilt-binaries" = ["php-8.5.12", "postgres-18.7", "neon-proxy-8853"]
```

or `mise use github:aysnc-labs/prebuilt-binaries@php-8.5.12`.

In GitHub Actions, give a job that installs these `attestations: read` as well as `contents: read`: mise looks up artifact attestations for each download and fails on a 403 without it. Set `GITHUB_TOKEN` to avoid GitHub's API rate limit.

Each release has one `<tag>-<target>.tar.gz` per target, with a `.sha256` beside it. An archive holds `bin/`, the upstream `LICENSE`, and `licenses/` for anything bundled.

## Layout

```
recipes/
  targets.yaml        every target: its runner, and the container tests run in
  <tool>/
    recipe.yaml       version, source, binaries, targets, test, updates
    build.sh          upstream source -> $OUT/bin
    test.sh           optional: proves the binaries work for real
    test/             test fixtures
bin/                  the same commands locally and in CI
  package <recipe>    build and pack for this machine's target, into dist/
  test <recipe> <dir> run the recipe's test command and test.sh
  bump <recipe>       move pins to the latest upstream
  ci <recipe>         what CI does, on this machine; --linux runs it in an sbx sandbox
  plan                the CI matrix
  validate            check recipes, shellcheck, actionlint
.github/workflows/
  ci.yml              every push: lint, build and test what changed
  release.yml         manual: release recipes at their current version
  autobump.yml        nightly 00:00 UTC, or manual: bump, build, test, release, land on main
  pipeline.yml        the shared plan -> build -> test -> release -> install -> promote
```

Run `mise install` for the repo's own tools (yq, jq, shellcheck, actionlint). Before pushing a recipe change, run `bin/ci <recipe>` and `bin/ci <recipe> --linux`.

Every release carries a GitHub artifact attestation: `gh attestation verify <archive> --repo aysnc-labs/prebuilt-binaries`.

## Updates

`autobump` runs every night, and can be run by hand from the Actions tab with a list of recipes. For each recipe, `bin/bump` checks the sources listed in its `updates`:

- a new upstream `version` (resets `revision` to 0);
- any other pin, such as PHP's static-php-cli (`revision` goes up by one).

Any recipe that moved is committed to `autobump/<recipe>`, then built, tested and released from there. Then it is installed with mise and cherry-picked onto main. If a build or test fails, main and the releases stay as they were, and the next night tries again.

To release by hand: change the recipe on main, then run `release` with the recipe's name. See [CONTRIBUTING.md](CONTRIBUTING.md) to add a tool.

## License

This repo's recipes, scripts and workflows are MIT. Each tool keeps its upstream licence, shipped in its archives.
