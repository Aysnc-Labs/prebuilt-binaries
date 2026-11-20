# Coding standards

The judgement calls `code-review` applies to every diff in Prebuilt Binaries. A rule a tool can check belongs in the tool: when one here turns mechanical, move it to the table with its enforcer.

## Review rules

Each rule cites its source, so a reviewer can tell when it has gone stale.

1. **Run on the oldest distro.** Linux builds and tests run in `ubuntu:22.04` (glibc 2.35), the `container` in `recipes/targets.yaml`; a diff that raises it says why. ([CONTRIBUTING.md](CONTRIBUTING.md), "Adding a tool" step 2)
2. **Run in a bare container.** Link statically, or bundle every non-system library, so the archive runs in the test container with nothing installed. ([CONTRIBUTING.md](CONTRIBUTING.md), "Adding a tool" step 2)
3. **Smoke test for real.** When `--version` proves little, `test.sh` makes the binaries do their job: serve a query, load each extension. ([CONTRIBUTING.md](CONTRIBUTING.md), step 3)
4. **Ship every licence.** `$OUT/LICENSE` is upstream's, and every bundled library has its licence in `$OUT/licenses/`. `lib/bundle.py` covers the shared libraries it copies; `build.sh` adds the ones linked statically. ([CONTRIBUTING.md](CONTRIBUTING.md), step 2; `recipes/php/build.sh`)

## Enforced by tools

| Rule | Enforcer | Where |
|---|---|---|
| Recipe fields present, `name` matches its folder, known targets, executable scripts | `bin/validate` | `bin/validate` |
| Every download has a `sha256`, every git source a `commit` | `bin/validate`, `bin/fetch` | `bin/validate`, `bin/fetch` |
| Shell lint | shellcheck | `bin/validate` |
| No `\| grep -q` under pipefail | `bin/validate` | `bin/validate` |
| Workflow lint | actionlint | `bin/validate` |
| Actions pinned to a commit SHA | `bin/validate` | `bin/validate` |
| Feature map current and covering every module | check-feature-map | `scripts/check-feature-map.ts` |
