# Adding a tool

1. Make `recipes/<tool>/recipe.yaml`. `name` must match the folder.

   ```yaml
   name: my-tool
   version: "1.2.3"
   revision: 0
   description: What it is
   homepage: https://…
   license: MIT
   source:
     git: https://github.com/owner/repo.git
     ref: v{version}
     commit: 0123…
   binaries: [my-tool]
   targets: [macos-arm64, linux-x64, linux-arm64]
   build-deps:
     apt: [cmake]
     brew: [cmake]
   cache: rust
   test: [my-tool --version, "^my-tool {version}"]
   updates:
     - field: .version
       type: git-tag
       repo: https://github.com/owner/repo.git
       pattern: ^v([0-9.]+)$
   ```

   - `version` is upstream's; the tag is `my-tool-1.2.3`. Raise `revision` to rebuild the same version (`my-tool-1.2.3-1`).
   - `source` is optional: a `git` repo, `ref` and the `commit` that ref must be, or a tarball `url` and its `sha256`. It's fetched into `$SRC` before `build.sh` runs, with `{version}` replaced.
   - Every other download is an entry with a `url` and a `sha256`, fetched with `bin/fetch <tool> <entry path> <file>`, which refuses a file that doesn't match. A url can use `{version}`, the entry's `{tag}`, and any field as `{.path.to.field}`.
   - `bin/lock <tool>` fills in every `sha256` and `commit`. `bin/bump` runs it after moving a pin, and `bin/validate` fails on a missing one.
   - `runners` is optional: a runner per target, overriding `recipes/targets.yaml` (e.g. an older Ubuntu for an older glibc floor).
   - `targets` come from `recipes/targets.yaml`. `build-deps` (apt, brew) is optional.
   - `cache` is optional: `rust` keeps cargo's `target/`, `dir` keeps `$CACHE`.
   - `test` is a command, and an extended regex its output must match.
   - `updates` is what autobump checks. Each names a `field` and a `type`: `git-tag` (`repo`, and a `pattern` whose first group is the value), `github-release` (`repo: owner/name`), `php` (`series: "8.5"`) or `postgres` (`series: "18"`).

2. Write `build.sh`. A build that links shared libraries can run `python3 -I "$ROOT/lib/bundle.py" "$OUT"` last: it copies every non-system library into `$OUT/lib`, with its licence, and points the binaries at it. It gets `ROOT`, `VERSION`, `TARGET`, `SRC`, `WORK`, `CACHE` and `OUT`, and must leave `$OUT/bin/<binaries>` and `$OUT/LICENSE`. Put the licences of anything bundled in `$OUT/licenses/`. Build the most portable binary you can: static, or against the oldest glibc you can.

3. If `--version` doesn't prove much, add `test.sh`. It gets `BIN_DIR` with the binaries, which are also first on `PATH`. On Linux, CI runs it as root in a bare `ubuntu:24.04`.

4. Try it: `bin/validate`, then `bin/ci <tool>` on your Mac and `bin/ci <tool> --linux` in a Linux sandbox ([sbx](https://docs.docker.com/ai/sandboxes/)). The sandbox only sees commits.

5. Push a branch. CI builds and tests it on every target. Once it's merged, run the `release` workflow with the tool's name, and add a row to the README's table.

# How it works

```
recipes/
  targets.yaml        every target: its runner, and the container tests run in
  <tool>/
    recipe.yaml       version, downloads and their sha256, binaries, targets, test, updates
    build.sh          upstream source -> $OUT/bin
    test.sh           optional: proves the binaries work for real
bin/
  ci <tool>           what CI does, on this machine; --linux runs it in an sbx sandbox
  package <tool>      build and pack for this machine's target, into dist/
  test <tool> <dir>   run the recipe's test command and test.sh
  bump <tool>         move pins to the latest upstream, then lock
  lock <tool>         record the sha256 of every download, and the commit of a git source
  fetch               download one entry and check its sha256
  plan                the CI matrix
  validate            check recipes, shellcheck, actionlint, pinned actions, docs/feature-map.md
.lefthook/pre-push/validate  bin/validate on each pushed commit, in a clean worktree
.github/workflows/
  ci.yml              every push: lint, then build and test what changed (read-only)
  release.yml         manual: release recipes at their current version
  autobump.yml        nightly 00:00 UTC, or manual: bump, build, test, release, land on main
  _build.yml          plan -> build -> test
  _publish.yml        release and attest -> install with mise -> land on main
  _release.yml        _build, then _publish
```

Run `mise install` for the repo's own tools and its git hooks: before every push, `.lefthook/pre-push/validate` runs `bin/validate` on each pushed commit in a clean worktree.

**Releases.** A tag is `<tool>-<version>`, plus `-<revision>` when the same upstream version is rebuilt. Each release has a `<tag>-<target>.tar.gz` per target with a `.sha256` beside it, holding `bin/`, the upstream `LICENSE` and `licenses/` for anything bundled. Each carries a GitHub artifact attestation: `gh attestation verify <archive> --repo aysnc-labs/prebuilt-binaries`.

**Updates.** Every night, `bin/bump` checks each recipe's `updates`. A new upstream `version` resets `revision` to 0; any other moved pin raises it by one. A recipe that moved is committed to `autobump/<tool>`, built, tested and released from there, installed with mise, then cherry-picked onto main. A recipe on main whose tag has no release yet is released from main. If anything fails, main and the releases stay as they were. Each run also re-enables its own schedule, which GitHub turns off after 60 days without commits.
