## Commands

- `bin/validate`: the one gate, run in CI and, through lefthook (`mise install` sets it up), on pre-push against a clean worktree of each pushed commit. Green locally means the lint job is green in CI.
- `bin/ci <tool>`: builds the recipe for this machine's target and runs its test command and `test.sh`. `--linux` does the same in an sbx sandbox, which sees only commits.

## Conventions

- A release tag is `<tool>-<version>`, plus `-<revision>` when the same upstream version is rebuilt: raise `revision` to rebuild.
- After moving a pin by hand, run `bin/lock <tool>` to record its `sha256` and `commit`.

## Agent skills

- Each feature's purpose, entry point and code: `docs/feature-map.md`. Start every task there.
- Issue tracker: GitHub issues on Aysnc-Labs/prebuilt-binaries, via `gh`. Where the plan and its decisions live: `docs/agents/issue-tracker.md`. Labels: `docs/agents/triage-labels.md`.
- Domain: `GLOSSARY.md` and `docs/adr/`, read as `docs/agents/domain.md` says.
- Review rules: `CODING_STANDARDS.md`.
- Verifying a change: `docs/agents/verification.md`.
