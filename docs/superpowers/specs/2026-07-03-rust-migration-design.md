# Rust Migration — Commit Message Validator

**Date:** 2026-07-03
**Status:** Approved design, ready for implementation planning

## Goal

Migrate the bash commit-message validator to Rust. Drivers: maintainability
(the bash state machine + regex are hard to extend), correctness (bash quoting
and macOS/bash-version portability quirks), performance (large ranges spawn git
per commit), and shipping a single distributable binary.

## Non-goals

- Changing the validation *rules* or *exit codes*. This is a behavior-compatible
  port: same rules, same exit codes. Error message wording and the CLI surface
  may be modernized.
- Publishing the core to crates.io (not now — structure allows promotion later).

## Compatibility contract

- **Validation rules:** identical to `validator.sh` (regex patterns ported 1:1,
  including quirks such as the subject end-class `[^ ^\.]`).
- **Exit codes:** unchanged. `Structure=1, Header=2, HeaderLength=3, Type=4,
  Scope=5, Subject=6, BodyLength=7, TrailingSpace=8, Jira=9, Revert=10`.
  Success = 0. `temp` commits print `ignoring temporary commit` and exit 0.
- **Env var names:** unchanged (`COMMIT_VALIDATOR_NO_JIRA`,
  `COMMIT_VALIDATOR_ALLOW_TEMP`, `COMMIT_VALIDATOR_NO_REVERT_SHA1`,
  `GLOBAL_JIRA_IN_HEADER`, `GLOBAL_MAX_LENGTH`, `GLOBAL_BODY_MAX_LENGTH`,
  `GLOBAL_JIRA_TYPES`) so `action.yml`'s `inputs → env` wiring keeps working.
  Empty/unset boolean env → off; non-empty → on (preserves bash quirk).

## Architecture (Approach A: library + CLI in one package)

Single Cargo package `commit-message-validator`.

```
src/
  lib.rs        # public API: validate_message(&str, &Config) -> Result<Outcome, ValidationError>
  config.rs     # Config struct + defaults
  error.rs      # ValidationError enum (carries exit code + Display message)
  patterns.rs   # compiled regexes (LazyLock), ported 1:1 from validator.sh
  parser.rs     # WAITING_HEADER→…→FOOTER state machine → ParsedMessage
  validate.rs   # per-rule fns (header, length, type, scope, subject, body,
                #   trailing, jira, revert)
  preprocess.rs # MERGE_MSG skip, strip `#` comment lines, "merge" first-word skip
  main.rs       # clap CLI: subcommands `message` / `range`; git subprocess; I/O + exit codes
tests/
  cli.rs        # assert_cmd integration tests against the built binary
```

**Isolation boundary:** everything under `lib.rs` is pure (string in, `Result`
out — no file/git/process I/O). All I/O (reading the message file, shelling out
to `git`, printing, `process::exit`) lives in `main.rs`. This makes the rules
trivially unit-testable and is what proves equivalence against the `.bats` suite.

### Data flow

`main` parses CLI/env → builds `Config` → reads input (file for `message`;
`git log -1 --pretty=%B` per commit for `range`) → `preprocess` (skip/strip) →
`parser` builds `ParsedMessage { header, body, jira, footer }` → `validate` runs
the rule pipeline → `Ok` or `ValidationError` → `main` prints and exits with the
mapped code.

### Parser notes

- Line-by-line processing mirrors bash `read` semantics.
- The state machine reproduces `validate_overall_structure`: header → empty line
  → body/jira-footer/broken → footer, with the same structure errors
  (missing empty line, double empty line, trailing newline, etc.).
- JIRA reference extracted from the footer, or from the header when
  `--jira-in-header` is set.

### Regex

`regex` crate, patterns compiled once via `LazyLock`, ported verbatim from
`validator.sh`. No backreferences are needed, so `regex` covers all patterns.

### Git access (range subcommand)

Shell out to `git` as a subprocess (as today). Rationale: `git` is an
unavoidable dependency for a commit validator, keeps the binary tiny, and keeps
static musl cross-compilation easy — directly serving the prebuilt-binary
distribution model. `git2`/libgit2 was rejected as a heavy C dependency that
complicates cross-builds.

## CLI surface

```
commit-message-validator message <FILE>       # commit-msg hook (replaces check_message.sh)
commit-message-validator range   <REV_RANGE>  # CI / pre-push (replaces check.sh)
```

clap derive. Each option is declared once with an `env` fallback, so a flag wins,
otherwise the env var, otherwise the default:

| Flag | Env fallback | Default |
|---|---|---|
| `--no-jira` | `COMMIT_VALIDATOR_NO_JIRA` | off |
| `--allow-temp` | `COMMIT_VALIDATOR_ALLOW_TEMP` | off |
| `--no-revert-sha1` | `COMMIT_VALIDATOR_NO_REVERT_SHA1` | off |
| `--jira-in-header` | `GLOBAL_JIRA_IN_HEADER` | off |
| `--header-length <N>` | `GLOBAL_MAX_LENGTH` | 100 |
| `--body-length <N>` | `GLOBAL_BODY_MAX_LENGTH` | 100 |
| `--jira-types <LIST>` | `GLOBAL_JIRA_TYPES` | `feat fix` |

## Testing

- **Workflow: strict TDD.** For every rule and code path, write the failing test
  first, then the minimal implementation to pass, then refactor. Tests are ported
  from the `.bats` suites as the golden reference before the corresponding Rust
  code exists.
- **Coverage target: 100%.** Measured with `cargo llvm-cov`. CI fails if coverage
  regresses below the threshold. Any intentionally-uncovered line must carry an
  explicit justification.
- **Unit tests** per module for the pure core — the bulk, ported from
  `validator.bats` (~16.7 KB of cases) as table-driven tests asserting
  `(exit code, message)` per input. This is the equivalence proof.
- **Integration tests** (`tests/cli.rs`, `assert_cmd` + `predicates`) cover
  `message` preprocessing (MERGE_MSG skip, comment stripping, merge-commit skip)
  and a small `range` case against a throwaway temp git repo.
- The old `.bats` files are removed once their cases are ported (retained in git
  history).

## Commits

- **Atomic, review-friendly commits.** Each commit is a single logical step that
  builds and passes tests on its own — e.g. one commit per module (test+impl
  together, since TDD pairs them), one for the CLI, one per distribution surface.
  Follow this repo's own commit convention (validated by the tool itself).

## Distribution / CI

- **CI workflow (GitHub Actions, on push/PR):** `cargo fmt --check`,
  `cargo clippy -D warnings`, `cargo test`, and `cargo llvm-cov` with the 100%
  coverage gate. This must be green before merge.
- **Release workflow:** on tag push, build static binaries for `x86_64`/`aarch64`
  × linux(musl)/macOS and attach them to the GitHub Release for the tag.
- **`action.yml`:** composite action downloads the binary matching the runner
  os/arch (cached via `actions/cache`) and runs `range`, keeping the existing
  `inputs → env` wiring.
- **pre-push:** thin script downloads/uses the prebuilt binary, calls `range`.
- **pre-commit (`.pre-commit-hooks.yaml`):** `language: script` wrapper that
  downloads the prebuilt binary on first run and calls `message`. Keeps a small
  bash shim but needs no Rust toolchain on the committer's machine.

## Phasing

1. Scaffold Cargo package + **CI workflow first** (fmt/clippy/test/llvm-cov gate),
   so every subsequent commit is checked in GitHub from the start.
2. Core library (`config`, `error`, `patterns`, `parser`, `validate`,
   `preprocess`) built TDD, unit tests ported from `validator.bats`.
3. CLI (`main.rs`, clap subcommands, git subprocess) + `tests/cli.rs`.
4. Release workflow (tagged, cross-platform static binaries).
5. Distribution surfaces: `action.yml`, `pre-push`, `.pre-commit-hooks.yaml`
   download shim; remove obsolete bash + `.bats`.
