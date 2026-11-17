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
   - `source` is optional: a `git` repo and `ref`, or a tarball `url`. It's fetched into `$SRC` before `build.sh` runs, with `{version}` replaced.
   - `runners` is optional: a runner per target, overriding `recipes/targets.yaml` (e.g. an older Ubuntu for an older glibc floor).
   - `targets` come from `recipes/targets.yaml`. `build-deps` (apt, brew) is optional.
   - `cache` is optional: `rust` keeps cargo's `target/`, `dir` keeps `$CACHE`.
   - `test` is a command, and an extended regex its output must match.
   - `updates` is what autobump checks. Each names a `field` and a `type`: `git-tag` (`repo`, and a `pattern` whose first group is the value), `github-release` (`repo: owner/name`), `php` (`series: "8.5"`) or `postgres` (`series: "18"`).

2. Write `build.sh`. A build that links shared libraries can run `python3 -I "$ROOT/lib/bundle.py" "$OUT"` last: it copies every non-system library into `$OUT/lib`, with its licence, and points the binaries at it. It gets `ROOT`, `VERSION`, `TARGET`, `SRC`, `WORK`, `CACHE` and `OUT`, and must leave `$OUT/bin/<binaries>` and `$OUT/LICENSE`. Put the licences of anything bundled in `$OUT/licenses/`. Build the most portable binary you can: static, or against the oldest glibc you can.

3. If `--version` doesn't prove much, add `test.sh`. It gets `BIN_DIR` with the binaries, which are also first on `PATH`. On Linux, CI runs it as root in a bare `ubuntu:24.04`.

4. Try it: `bin/validate`, then `bin/ci <tool>` on your Mac and `bin/ci <tool> --linux` in a Linux sandbox ([sbx](https://docs.docker.com/ai/sandboxes/)). The sandbox only sees commits.

5. Push a branch. CI builds and tests it on every target. Once it's merged, run the `release` workflow with the tool's name, and add a row to the README's table.
