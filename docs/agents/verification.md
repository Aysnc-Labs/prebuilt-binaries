# Verification

## Access

How an agent gets into the app with nobody there.

- None needed: there is no app, login or seeded user. An agent proves a change by building and testing the recipe with `bin/ci <tool>`, and CI builds every target on push.
- Credentials: none. Builds use the run's read-only `GITHUB_TOKEN` in CI; locally, upstream downloads need no token.

## Checklist

Areas a careful human tester keeps in mind when testing a change on this project. The `aysnc-skills:prove-it` skill's verifier weighs each one against the changed surface and tests the ones that apply. Add your project's own risks.

- **Does it work:** the recipe's `test` and `test.sh` pass, and the binaries do real work beyond `--version`.
- **Does it run everywhere:** on every target in `recipes/targets.yaml`, and on Linux in a bare `ubuntu:24.04` with nothing else installed: no missing shared library, and a glibc floor no newer than before.
- **Is it complete:** `$OUT/bin` holds every name in `binaries`, `$OUT/LICENSE` is upstream's, and `$OUT/licenses/` holds the licence of everything bundled.
- **Is it the right release:** the tag is `<tool>-<version>[-<revision>]`, `revision` resets to 0 on a new upstream version, and mise installs the release with its attestation.
- **Is it safe:** every download is pinned by `sha256` or `commit`, and workflows keep least-privilege `permissions` and SHA-pinned actions.
