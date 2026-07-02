# Rust Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reimplement the bash commit-message validator as a single Rust binary with identical validation rules and exit codes, a cleaner CLI, prebuilt cross-platform release binaries, and full test coverage.

**Architecture:** A pure library core (`config`, `error`, `patterns`, `parser`, `validate`, `preprocess`) does all string-in/`Result`-out work with no I/O. A thin `clap` CLI (`main.rs`) with two subcommands (`message <FILE>`, `range <REV_RANGE>`) handles file/git/process I/O and maps `ValidationError` variants to the historical exit codes. Git access is via subprocess. The `.bats` suites are the golden reference and are ported to Rust tests.

**Tech Stack:** Rust (edition 2021, rust-version 1.80 for `std::sync::LazyLock`), `clap` (derive), `regex`; dev: `assert_cmd`, `predicates`, `tempfile`; CI coverage via `cargo-llvm-cov`.

## Global Constraints

- **Behavior-compatible port.** Validation rules are identical to `validator.sh` (regexes ported verbatim, including quirks). Error message *wording* may be tidied; rules and exit codes may not change.
- **Exit codes (verbatim):** Structure=1, Header=2, HeaderLength=3, Type=4, Scope=5, Subject=6, BodyLength=7, TrailingSpace=8, Jira=9, Revert=10. Success=0. `temp` commits print `ignoring temporary commit` and exit 0.
- **Env var names unchanged:** `COMMIT_VALIDATOR_NO_JIRA`, `COMMIT_VALIDATOR_ALLOW_TEMP`, `COMMIT_VALIDATOR_NO_REVERT_SHA1`, `GLOBAL_JIRA_IN_HEADER`, `GLOBAL_MAX_LENGTH`, `GLOBAL_BODY_MAX_LENGTH`, `GLOBAL_JIRA_TYPES`. Empty/unset boolean env → off; non-empty → on. Empty/unset numeric/list env → default.
- **Defaults:** header length 100, body length 100, jira types `feat fix`.
- **Crate & binary name:** `commit-message-validator`.
- **Workflow:** strict TDD (failing test → minimal impl → refactor). Atomic, individually-green commits following this repo's own commit convention. Run `/simplify` and `/code-review` before each commit / at end of each phase and address findings. All work on a feature branch; open a **draft PR** at the end.
- **Quality gates:** every commit must pass `cargo fmt --check`, `cargo clippy -- -D warnings`, `cargo test`. CI runs `cargo llvm-cov` and **hard-fails under 90%** line coverage (aim 100%).

---

## Task 1: Scaffold Cargo package + CI workflow

Sets up the branch, crate skeleton, dependencies, and the GitHub CI workflow so every later commit is checked. Deliverable: `cargo test` runs (with a trivial placeholder test) and CI is defined.

**Files:**
- Create: `Cargo.toml`
- Create: `src/lib.rs` (temporary placeholder)
- Create: `src/main.rs` (temporary placeholder)
- Create: `.github/workflows/ci.yml`
- Create: `rust-toolchain.toml`
- Create: `.gitignore` entry for `/target`

**Interfaces:**
- Produces: crate `commit_message_validator` (lib) + binary `commit-message-validator`.

- [ ] **Step 1: Create the feature branch**

```bash
git checkout -b feat/rust-migration
```

- [ ] **Step 2: Write `Cargo.toml`**

```toml
[package]
name = "commit-message-validator"
version = "2.0.0"
edition = "2021"
rust-version = "1.80"
description = "Enforce angular commit message convention"
license = "MIT"

[[bin]]
name = "commit-message-validator"
path = "src/main.rs"

[lib]
name = "commit_message_validator"
path = "src/lib.rs"

[dependencies]
clap = { version = "4", features = ["derive", "env"] }
regex = "1"

[dev-dependencies]
assert_cmd = "2"
predicates = "3"
tempfile = "3"
```

- [ ] **Step 3: Add `/target` to `.gitignore`**

Append `/target` on its own line to the existing `.gitignore`.

- [ ] **Step 4: Write `rust-toolchain.toml`**

```toml
[toolchain]
channel = "stable"
components = ["rustfmt", "clippy"]
```

- [ ] **Step 5: Write placeholder `src/lib.rs`**

```rust
#[cfg(test)]
mod tests {
    #[test]
    fn scaffold_compiles() {
        assert_eq!(2 + 2, 4);
    }
}
```

- [ ] **Step 6: Write placeholder `src/main.rs`**

```rust
fn main() {
    println!("commit-message-validator");
}
```

- [ ] **Step 7: Write `.github/workflows/ci.yml`**

```yaml
---
name: CI
on:
  push:
    branches: [master]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
        with:
          components: rustfmt, clippy
      - name: Format
        run: cargo fmt --all -- --check
      - name: Clippy
        run: cargo clippy --all-targets -- -D warnings
      - name: Test
        run: cargo test --all-targets
      - name: Install cargo-llvm-cov
        uses: taiki-e/install-action@cargo-llvm-cov
      - name: Coverage (fail under 90%)
        run: cargo llvm-cov --all-targets --fail-under-lines 90
```

- [ ] **Step 8: Verify it builds and tests pass**

Run: `cargo fmt --all -- --check && cargo clippy --all-targets -- -D warnings && cargo test`
Expected: PASS (1 test `scaffold_compiles`).

- [ ] **Step 9: Commit**

```bash
git add Cargo.toml Cargo.lock rust-toolchain.toml .gitignore src/lib.rs src/main.rs .github/workflows/ci.yml
git commit -m "chore(rust): scaffold cargo package and CI workflow"
```

---

## Task 2: Error types (`error.rs`)

The `ValidationError` enum: one variant per failure, each carrying a message and mapping to its exit code.

**Files:**
- Create: `src/error.rs`
- Modify: `src/lib.rs` (add `pub mod error;`)

**Interfaces:**
- Produces: `pub enum ValidationError` with variants `Structure`, `Header`, `HeaderLength`, `Type`, `Scope`, `Subject`, `BodyLength`, `TrailingSpace`, `Jira`, `Revert`, each `(String)`; method `pub fn code(&self) -> i32`; `impl Display`.

- [ ] **Step 1: Write the failing test** (in `src/error.rs`)

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn codes_match_historical_values() {
        assert_eq!(ValidationError::Structure(String::new()).code(), 1);
        assert_eq!(ValidationError::Header(String::new()).code(), 2);
        assert_eq!(ValidationError::HeaderLength(String::new()).code(), 3);
        assert_eq!(ValidationError::Type(String::new()).code(), 4);
        assert_eq!(ValidationError::Scope(String::new()).code(), 5);
        assert_eq!(ValidationError::Subject(String::new()).code(), 6);
        assert_eq!(ValidationError::BodyLength(String::new()).code(), 7);
        assert_eq!(ValidationError::TrailingSpace(String::new()).code(), 8);
        assert_eq!(ValidationError::Jira(String::new()).code(), 9);
        assert_eq!(ValidationError::Revert(String::new()).code(), 10);
    }

    #[test]
    fn display_renders_message() {
        assert_eq!(ValidationError::Type("boom".into()).to_string(), "boom");
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cargo test --lib error`
Expected: FAIL (compile error — `ValidationError` not defined).

- [ ] **Step 3: Write the implementation** (top of `src/error.rs`)

```rust
use std::fmt;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ValidationError {
    Structure(String),
    Header(String),
    HeaderLength(String),
    Type(String),
    Scope(String),
    Subject(String),
    BodyLength(String),
    TrailingSpace(String),
    Jira(String),
    Revert(String),
}

impl ValidationError {
    pub fn code(&self) -> i32 {
        match self {
            ValidationError::Structure(_) => 1,
            ValidationError::Header(_) => 2,
            ValidationError::HeaderLength(_) => 3,
            ValidationError::Type(_) => 4,
            ValidationError::Scope(_) => 5,
            ValidationError::Subject(_) => 6,
            ValidationError::BodyLength(_) => 7,
            ValidationError::TrailingSpace(_) => 8,
            ValidationError::Jira(_) => 9,
            ValidationError::Revert(_) => 10,
        }
    }

    fn message(&self) -> &str {
        match self {
            ValidationError::Structure(m)
            | ValidationError::Header(m)
            | ValidationError::HeaderLength(m)
            | ValidationError::Type(m)
            | ValidationError::Scope(m)
            | ValidationError::Subject(m)
            | ValidationError::BodyLength(m)
            | ValidationError::TrailingSpace(m)
            | ValidationError::Jira(m)
            | ValidationError::Revert(m) => m,
        }
    }
}

impl fmt::Display for ValidationError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.message())
    }
}
```

- [ ] **Step 4: Wire into `src/lib.rs`** — replace the placeholder file with:

```rust
pub mod error;

pub use error::ValidationError;
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cargo test --lib && cargo clippy --all-targets -- -D warnings`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add src/error.rs src/lib.rs
git commit -m "feat(error): add ValidationError with exit codes"
```

---

## Task 3: Config + resolution (`config.rs`)

The pure `Config` struct, its defaults, and a pure `resolve()` that combines CLI overrides with an env lookup using the bash-compatible empty/unset semantics.

**Files:**
- Create: `src/config.rs`
- Modify: `src/lib.rs` (add `pub mod config;` and re-exports)

**Interfaces:**
- Produces:
  - `pub struct Config { pub no_jira: bool, pub allow_temp: bool, pub no_revert_sha1: bool, pub jira_in_header: bool, pub header_max_length: usize, pub body_max_length: usize, pub jira_types: Vec<String> }` with `impl Default`.
  - `pub struct Overrides { pub no_jira: bool, pub allow_temp: bool, pub no_revert_sha1: bool, pub jira_in_header: bool, pub header_length: Option<usize>, pub body_length: Option<usize>, pub jira_types: Option<String> }` with `#[derive(Default)]`.
  - `pub fn Config::resolve(o: &Overrides, env: impl Fn(&str) -> Option<String>) -> Config`.

- [ ] **Step 1: Write the failing tests** (in `src/config.rs`)

```rust
#[cfg(test)]
mod tests {
    use super::*;

    fn no_env(_: &str) -> Option<String> {
        None
    }

    #[test]
    fn defaults_when_nothing_set() {
        let c = Config::resolve(&Overrides::default(), no_env);
        assert!(!c.no_jira && !c.allow_temp && !c.no_revert_sha1 && !c.jira_in_header);
        assert_eq!(c.header_max_length, 100);
        assert_eq!(c.body_max_length, 100);
        assert_eq!(c.jira_types, vec!["feat".to_string(), "fix".to_string()]);
    }

    #[test]
    fn cli_flag_enables_bool() {
        let o = Overrides { no_jira: true, ..Default::default() };
        assert!(Config::resolve(&o, no_env).no_jira);
    }

    #[test]
    fn nonempty_env_enables_bool_empty_does_not() {
        let on = |n: &str| (n == "COMMIT_VALIDATOR_NO_JIRA").then(|| "1".to_string());
        let empty = |n: &str| (n == "COMMIT_VALIDATOR_NO_JIRA").then(String::new);
        assert!(Config::resolve(&Overrides::default(), on).no_jira);
        assert!(!Config::resolve(&Overrides::default(), empty).no_jira);
    }

    #[test]
    fn cli_length_overrides_env_and_default() {
        let o = Overrides { header_length: Some(150), ..Default::default() };
        assert_eq!(Config::resolve(&o, no_env).header_max_length, 150);
    }

    #[test]
    fn env_length_used_when_no_cli_and_empty_falls_back() {
        let set = |n: &str| (n == "GLOBAL_BODY_MAX_LENGTH").then(|| "150".to_string());
        let empty = |n: &str| (n == "GLOBAL_BODY_MAX_LENGTH").then(String::new);
        assert_eq!(Config::resolve(&Overrides::default(), set).body_max_length, 150);
        assert_eq!(Config::resolve(&Overrides::default(), empty).body_max_length, 100);
    }

    #[test]
    fn jira_types_split_on_whitespace() {
        let o = Overrides { jira_types: Some("feat fix chore".into()), ..Default::default() };
        let c = Config::resolve(&o, no_env);
        assert_eq!(c.jira_types, vec!["feat", "fix", "chore"]);
    }

    #[test]
    fn empty_env_jira_types_falls_back_to_default() {
        let empty = |n: &str| (n == "GLOBAL_JIRA_TYPES").then(String::new);
        assert_eq!(
            Config::resolve(&Overrides::default(), empty).jira_types,
            vec!["feat".to_string(), "fix".to_string()]
        );
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cargo test --lib config`
Expected: FAIL (compile error — `Config`/`Overrides` not defined).

- [ ] **Step 3: Write the implementation** (top of `src/config.rs`)

```rust
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Config {
    pub no_jira: bool,
    pub allow_temp: bool,
    pub no_revert_sha1: bool,
    pub jira_in_header: bool,
    pub header_max_length: usize,
    pub body_max_length: usize,
    pub jira_types: Vec<String>,
}

impl Default for Config {
    fn default() -> Self {
        Config {
            no_jira: false,
            allow_temp: false,
            no_revert_sha1: false,
            jira_in_header: false,
            header_max_length: 100,
            body_max_length: 100,
            jira_types: vec!["feat".to_string(), "fix".to_string()],
        }
    }
}

#[derive(Debug, Default)]
pub struct Overrides {
    pub no_jira: bool,
    pub allow_temp: bool,
    pub no_revert_sha1: bool,
    pub jira_in_header: bool,
    pub header_length: Option<usize>,
    pub body_length: Option<usize>,
    pub jira_types: Option<String>,
}

fn resolve_usize(cli: Option<usize>, env: Option<String>, default: usize) -> usize {
    if let Some(n) = cli {
        return n;
    }
    env.and_then(|v| v.parse().ok()).unwrap_or(default)
}

impl Config {
    pub fn resolve(o: &Overrides, env: impl Fn(&str) -> Option<String>) -> Config {
        let flag = |cli: bool, name: &str| {
            cli || env(name).map(|v| !v.is_empty()).unwrap_or(false)
        };
        let default = Config::default();
        let jira_types = o
            .jira_types
            .clone()
            .or_else(|| env("GLOBAL_JIRA_TYPES").filter(|v| !v.is_empty()))
            .map(|t| t.split_whitespace().map(String::from).collect())
            .unwrap_or(default.jira_types);
        Config {
            no_jira: flag(o.no_jira, "COMMIT_VALIDATOR_NO_JIRA"),
            allow_temp: flag(o.allow_temp, "COMMIT_VALIDATOR_ALLOW_TEMP"),
            no_revert_sha1: flag(o.no_revert_sha1, "COMMIT_VALIDATOR_NO_REVERT_SHA1"),
            jira_in_header: flag(o.jira_in_header, "GLOBAL_JIRA_IN_HEADER"),
            header_max_length: resolve_usize(
                o.header_length,
                env("GLOBAL_MAX_LENGTH"),
                default.header_max_length,
            ),
            body_max_length: resolve_usize(
                o.body_length,
                env("GLOBAL_BODY_MAX_LENGTH"),
                default.body_max_length,
            ),
            jira_types,
        }
    }
}
```

- [ ] **Step 4: Wire into `src/lib.rs`**

```rust
pub mod config;
pub mod error;

pub use config::{Config, Overrides};
pub use error::ValidationError;
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cargo test --lib && cargo clippy --all-targets -- -D warnings`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add src/config.rs src/lib.rs
git commit -m "feat(config): add Config with env/flag resolution"
```

---

## Task 4: Regex patterns (`patterns.rs`)

All patterns from `validator.sh`, compiled once via `LazyLock`, ported verbatim.

**Files:**
- Create: `src/patterns.rs`
- Modify: `src/lib.rs` (add `mod patterns;` — crate-private)

**Interfaces:**
- Produces (all `pub`): `HEADER`, `TYPE`, `SCOPE`, `SUBJECT`, `JIRA_FOOTER`, `JIRA_HEADER`, `BROKE`, `TRAILING_SPACE`, `REVERT_HEADER`, `REVERT_COMMIT`, `TEMP_HEADER` as `LazyLock<Regex>`; const `JIRA: &str`.

- [ ] **Step 1: Write the failing tests** (in `src/patterns.rs`)

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn header_captures_type_scope_subject() {
        let caps = HEADER.captures("type(scope): message").unwrap();
        assert_eq!(&caps[1], "type");
        assert_eq!(&caps[2], "scope");
        assert_eq!(&caps[3], "message");
    }

    #[test]
    fn header_rejects_malformed() {
        assert!(HEADER.captures("type(scope):message").is_none());
        assert!(HEADER.captures("type scope: message").is_none());
        assert!(HEADER.captures("type(scope): ").is_none());
    }

    #[test]
    fn type_only_known_lowercase() {
        assert!(TYPE.is_match("feat"));
        assert!(!TYPE.is_match("Feat"));
        assert!(!TYPE.is_match("feat "));
        assert!(!TYPE.is_match("plop"));
    }

    #[test]
    fn scope_is_kebab_case() {
        assert!(SCOPE.is_match("p2"));
        assert!(SCOPE.is_match("pl2op-plop1-plop-0001"));
        assert!(!SCOPE.is_match(""));
        assert!(!SCOPE.is_match("plopPlop"));
        assert!(!SCOPE.is_match("plop plop"));
        assert!(!SCOPE.is_match("plop "));
    }

    #[test]
    fn subject_rules() {
        assert!(SUBJECT.is_match("0002 dedezf ef"));
        assert!(!SUBJECT.is_match(""));
        assert!(!SUBJECT.is_match("plop "));
        assert!(!SUBJECT.is_match("plop."));
    }

    #[test]
    fn jira_footer_and_header() {
        assert!(JIRA_FOOTER.is_match("ABC-1234"));
        assert!(JIRA_FOOTER.is_match("ABC-1234 DE-1234"));
        assert!(!JIRA_FOOTER.is_match("2345"));
        let caps = JIRA_HEADER.captures("feat(abc): ABC-1234").unwrap();
        assert_eq!(&caps[1], "ABC-1234");
    }

    #[test]
    fn misc_patterns() {
        assert!(BROKE.is_match("BROKEN:"));
        assert!(TRAILING_SPACE.is_match("foo "));
        assert!(!TRAILING_SPACE.is_match("foo"));
        assert!(REVERT_HEADER.is_match("revert: type(scope): message"));
        assert!(REVERT_HEADER.is_match("Revert \"type(scope): message\""));
        assert!(REVERT_COMMIT.captures("This reverts commit 1234abcd.").is_some());
        assert!(TEMP_HEADER.is_match("fixup! foo"));
        assert!(TEMP_HEADER.is_match("squash! foo"));
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cargo test --lib patterns`
Expected: FAIL (compile error — patterns not defined).

- [ ] **Step 3: Write the implementation** (top of `src/patterns.rs`)

```rust
use regex::Regex;
use std::sync::LazyLock;

pub const JIRA: &str = r"[A-Z]{2,7}[0-9]{0,6}-[0-9]{1,6}";

pub static HEADER: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"^([^(]+)\(([^)]+)\): (.+)$").unwrap());
pub static TYPE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"^(feat|fix|docs|gen|lint|refactor|test|chore)$").unwrap());
pub static SCOPE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"^([a-z][a-z0-9]*)(-[a-z0-9]+)*$").unwrap());
pub static SUBJECT: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"^[A-Za-z0-9].*[^ ^.]$").unwrap());
pub static JIRA_FOOTER: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(&format!(r"^({JIRA} ?)+$")).unwrap());
pub static JIRA_HEADER: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(&format!(r"^.*[^A-Z]({JIRA}).*$")).unwrap());
pub static BROKE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"^BROKEN:$").unwrap());
pub static TRAILING_SPACE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r" +$").unwrap());
pub static REVERT_HEADER: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"^[Rr](evert|eapply)[: ].*$").unwrap());
pub static REVERT_COMMIT: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"^This reverts commit ([a-f0-9]+)").unwrap());
pub static TEMP_HEADER: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"^(fixup!|squash!).*$").unwrap());
```

> Note the subject class `[^ ^.]` is intentionally `{space, caret, dot}` negated — a faithful port of the bash `[^ ^\.]`.

- [ ] **Step 4: Wire into `src/lib.rs`** (add the private module line, keep it out of the public re-exports)

```rust
mod patterns;
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cargo test --lib && cargo clippy --all-targets -- -D warnings`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add src/patterns.rs src/lib.rs
git commit -m "feat(patterns): port validator regexes to Rust"
```

---

## Task 5: Structure parser (`parser.rs`)

The line-by-line state machine that splits a message into `{ header, body, jira, footer }`, reproducing `validate_overall_structure`. Iterating `message.split('\n')` exactly matches bash `read` over the here-string.

**Files:**
- Create: `src/parser.rs`
- Modify: `src/lib.rs` (add `mod parser;`)

**Interfaces:**
- Consumes: `crate::error::ValidationError`, `crate::patterns`.
- Produces:
  - `pub struct ParsedMessage { pub header: String, pub body: String, pub jira: String, pub footer: String }` deriving `Debug, Default, PartialEq, Eq`.
  - `pub fn parse(message: &str, jira_in_header: bool) -> Result<ParsedMessage, ValidationError>`.

- [ ] **Step 1: Write the failing tests** (in `src/parser.rs`) — these port every `structure:` case from `validator.bats`.

```rust
#[cfg(test)]
mod tests {
    use super::*;

    fn ok(msg: &str, jira_in_header: bool) -> ParsedMessage {
        parse(msg, jira_in_header).expect("expected valid structure")
    }

    fn err_code(msg: &str) -> i32 {
        parse(msg, false).expect_err("expected structure error").code()
    }

    #[test]
    fn structure_errors() {
        // one trailing line
        assert_eq!(err_code("plop plop\n"), 1);
        // missing empty line after header (body)
        assert_eq!(err_code("plop plop\nplop\n\nplop\n"), 1);
        // missing empty line after header (jira)
        assert_eq!(err_code("plop plop\nABC-1234\n"), 1);
        // missing empty line after header (broken)
        assert_eq!(err_code("plop plop\nBROKEN:\n"), 1);
        // missing empty line after body with jira ref
        assert_eq!(err_code("plop plop\n\nplop\nplop\nplop\nplop\nLUM-1234\n"), 1);
        // missing empty line after body with broken
        assert_eq!(err_code("plop plop\n\nplop\nplop\nplop\nplop\nBROKEN:\n"), 1);
        // empty line after the body (double empty)
        assert_eq!(err_code("plop plop\n\nplop\nplop\nplop\nplop\n\n"), 1);
    }

    #[test]
    fn header_only() {
        let p = ok("plop plop", false);
        assert_eq!(p, ParsedMessage { header: "plop plop".into(), ..Default::default() });
    }

    #[test]
    fn header_and_jira() {
        let p = ok("plop plop\n\nABC-1234", false);
        assert_eq!(p.header, "plop plop");
        assert_eq!(p.jira, "ABC-1234");
        assert_eq!(p.body, "");
        assert_eq!(p.footer, "");
    }

    #[test]
    fn jira_in_header_extracted() {
        let p = ok("feat(abc): ABC-1234\n\nplop", true);
        assert_eq!(p.header, "feat(abc): ABC-1234");
        assert_eq!(p.jira, "ABC-1234");
        assert_eq!(p.body, "plop\n");
    }

    #[test]
    fn header_and_multiple_jira() {
        let p = ok("plop plop\n\nABC-1234 DE-1234", false);
        assert_eq!(p.jira, "ABC-1234 DE-1234");
    }

    #[test]
    fn header_and_broken() {
        let p = ok("plop plop\n\nBROKEN:\n- plop\n- plop", false);
        assert_eq!(p.footer, "- plop\n- plop\n");
        assert_eq!(p.body, "");
    }

    #[test]
    fn header_jira_and_broken() {
        let p = ok("plop plop\n\nABC-1234\nBROKEN:\n- plop\n- plop", false);
        assert_eq!(p.jira, "ABC-1234");
        assert_eq!(p.footer, "- plop\n- plop\n");
    }

    #[test]
    fn header_and_body() {
        let p = ok("plop plop\n\nhello", false);
        assert_eq!(p.body, "hello\n");
    }

    #[test]
    fn multiline_body() {
        let p = ok("plop plop\n\nhello\n\nplopplop\nplopplop\n\ntoto", false);
        assert_eq!(p.body, "hello\nplopplop\nplopplop\ntoto\n");
    }

    #[test]
    fn multiline_body_and_jira() {
        let p = ok("plop plop\n\nhello\n\nplopplop\nplopplop\n\ntoto\n\nABC-1234", false);
        assert_eq!(p.body, "hello\nplopplop\nplopplop\ntoto\n");
        assert_eq!(p.jira, "ABC-1234");
    }

    #[test]
    fn multiline_body_and_broken() {
        let p = ok("plop plop\n\nhello\n\nplopplop\nplopplop\n\ntoto\n\nBROKEN:\n- plop\n- plop", false);
        assert_eq!(p.body, "hello\nplopplop\nplopplop\ntoto\n");
        assert_eq!(p.footer, "- plop\n- plop\n");
    }

    #[test]
    fn multiline_body_jira_and_broken() {
        let p = ok(
            "plop plop\n\nhello\n\nplopplop\nplopplop\n\ntoto\n\nABC-1234\nBROKEN:\n- plop\n- plop",
            false,
        );
        assert_eq!(p.body, "hello\nplopplop\nplopplop\ntoto\n");
        assert_eq!(p.jira, "ABC-1234");
        assert_eq!(p.footer, "- plop\n- plop\n");
    }

    #[test]
    fn only_broken_allowed_after_jira() {
        // JIRA ref then a non-broken line -> structure error
        assert_eq!(err_code("plop plop\n\nABC-1234\nnope"), 1);
    }

    #[test]
    fn no_empty_line_in_broken_part() {
        assert_eq!(err_code("plop plop\n\nBROKEN:\n- plop\n\n- plop"), 1);
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cargo test --lib parser`
Expected: FAIL (compile error — `parse`/`ParsedMessage` not defined).

- [ ] **Step 3: Write the implementation** (top of `src/parser.rs`)

```rust
use crate::error::ValidationError;
use crate::patterns;

#[derive(Debug, Default, PartialEq, Eq)]
pub struct ParsedMessage {
    pub header: String,
    pub body: String,
    pub jira: String,
    pub footer: String,
}

#[derive(PartialEq)]
enum State {
    WaitingHeader,
    WaitingEmpty,
    StartText,
    ReadingBody,
    ReadingBroken,
    ReadingFooter,
}

fn structure(msg: &str) -> ValidationError {
    ValidationError::Structure(msg.to_string())
}

pub fn parse(message: &str, jira_in_header: bool) -> Result<ParsedMessage, ValidationError> {
    let mut parsed = ParsedMessage::default();
    let mut state = State::WaitingHeader;

    for line in message.split('\n') {
        match state {
            State::WaitingHeader => {
                parsed.header = line.to_string();
                state = State::WaitingEmpty;
                if jira_in_header {
                    if let Some(caps) = patterns::JIRA_HEADER.captures(line) {
                        parsed.jira = caps[1].to_string();
                    }
                }
            }
            State::WaitingEmpty => {
                if !line.is_empty() {
                    return Err(structure(
                        "missing empty line in commit message between header and body or body and footer",
                    ));
                }
                state = State::StartText;
            }
            State::StartText => {
                if line.is_empty() {
                    return Err(structure("double empty line is not allowed"));
                }
                if patterns::BROKE.is_match(line) {
                    state = State::ReadingFooter;
                } else if patterns::JIRA_FOOTER.is_match(line) {
                    state = State::ReadingBroken;
                    parsed.jira = line.to_string();
                } else {
                    state = State::ReadingBody;
                    parsed.body.push_str(line);
                    parsed.body.push('\n');
                }
            }
            State::ReadingBody => {
                if patterns::BROKE.is_match(line) {
                    return Err(structure("missing empty line before broke part"));
                }
                if patterns::JIRA_FOOTER.is_match(line) {
                    return Err(structure("missing empty line before JIRA reference"));
                }
                if line.is_empty() {
                    state = State::StartText;
                } else {
                    parsed.body.push_str(line);
                    parsed.body.push('\n');
                }
            }
            State::ReadingBroken => {
                if patterns::BROKE.is_match(line) {
                    state = State::ReadingFooter;
                } else {
                    return Err(structure(
                        "only broken part could be after the JIRA reference",
                    ));
                }
            }
            State::ReadingFooter => {
                if line.is_empty() {
                    return Err(structure("no empty line allowed in broken part"));
                }
                parsed.footer.push_str(line);
                parsed.footer.push('\n');
            }
        }
    }

    if state == State::StartText {
        return Err(structure("new line at the end of the commit is not allowed"));
    }

    Ok(parsed)
}
```

- [ ] **Step 4: Wire into `src/lib.rs`** (add `mod parser;`).

- [ ] **Step 5: Run tests to verify they pass**

Run: `cargo test --lib && cargo clippy --all-targets -- -D warnings`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add src/parser.rs src/lib.rs
git commit -m "feat(parser): port commit structure state machine"
```

---

## Task 6: Validation rules (`validate.rs`)

Per-rule functions and header classification, ported from the `validate_*` and `need_jira` bash functions.

**Files:**
- Create: `src/validate.rs`
- Modify: `src/lib.rs` (add `mod validate;`)

**Interfaces:**
- Consumes: `crate::config::Config`, `crate::error::ValidationError`, `crate::patterns`.
- Produces:
  - `pub enum HeaderKind { Temp, Revert, Conventional { type_: String, scope: String, subject: String } }`.
  - `pub fn classify_header(header: &str, config: &Config) -> Result<HeaderKind, ValidationError>`.
  - `pub fn header_length(header: &str, max: usize) -> Result<(), ValidationError>`.
  - `pub fn commit_type(type_: &str) -> Result<(), ValidationError>`.
  - `pub fn scope(scope: &str) -> Result<(), ValidationError>`.
  - `pub fn subject(subject: &str) -> Result<(), ValidationError>`.
  - `pub fn body_length(text: &str, max: usize) -> Result<(), ValidationError>`.
  - `pub fn trailing_space(text: &str) -> Result<(), ValidationError>`.
  - `pub fn need_jira(type_: &str, config: &Config) -> bool`.
  - `pub fn jira(type_: &str, jira: &str, config: &Config) -> Result<(), ValidationError>`.
  - `pub fn revert(body: &str, config: &Config) -> Result<(), ValidationError>`.

- [ ] **Step 1: Write the failing tests** (in `src/validate.rs`) — porting every rule case from `validator.bats`.

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use crate::config::Config;

    fn cfg() -> Config {
        Config::default()
    }

    #[test]
    fn classify_rejects_malformed_headers() {
        for bad in [
            "type",
            "type(scope)",
            "type(scope) message",
            "type(scope) : message",
            "type(scope: message",
            "type scope: message",
            "type(scope):message",
        ] {
            assert_eq!(classify_header(bad, &cfg()).unwrap_err().code(), 2, "{bad}");
        }
    }

    #[test]
    fn classify_temp_only_when_allowed() {
        let mut c = cfg();
        assert_eq!(classify_header("fixup! x", &c).unwrap_err().code(), 2);
        assert_eq!(classify_header("squash! x", &c).unwrap_err().code(), 2);
        c.allow_temp = true;
        assert!(matches!(classify_header("fixup! x", &c).unwrap(), HeaderKind::Temp));
        assert!(matches!(classify_header("squash! x", &c).unwrap(), HeaderKind::Temp));
    }

    #[test]
    fn classify_revert() {
        assert!(matches!(
            classify_header("revert: type(scope): message", &cfg()).unwrap(),
            HeaderKind::Revert
        ));
        assert!(matches!(
            classify_header("Revert \"type(scope): message\"", &cfg()).unwrap(),
            HeaderKind::Revert
        ));
    }

    #[test]
    fn classify_conventional_extracts_parts() {
        let k = classify_header("type(scope): message", &cfg()).unwrap();
        match k {
            HeaderKind::Conventional { type_, scope, subject } => {
                assert_eq!(type_, "type");
                assert_eq!(scope, "scope");
                assert_eq!(subject, "message");
            }
            _ => panic!("expected conventional"),
        }
    }

    #[test]
    fn header_length_boundary() {
        let at = "0".repeat(100);
        let over = "0".repeat(101);
        assert!(header_length(&at, 100).is_ok());
        assert_eq!(header_length(&over, 100).unwrap_err().code(), 3);
        assert!(header_length(&over, 150).is_ok());
    }

    #[test]
    fn commit_type_rules() {
        assert!(commit_type("feat").is_ok());
        assert_eq!(commit_type("plop").unwrap_err().code(), 4);
        assert_eq!(commit_type("feat ").unwrap_err().code(), 4);
        assert_eq!(commit_type("Feat").unwrap_err().code(), 4);
    }

    #[test]
    fn scope_rules() {
        assert!(scope("p2").is_ok());
        assert!(scope("pl2op-plop1-plop-0001").is_ok());
        for bad in ["", "plopPlop", "plop plop", "plop "] {
            assert_eq!(scope(bad).unwrap_err().code(), 5, "{bad}");
        }
    }

    #[test]
    fn subject_rules() {
        assert!(subject("0002 dedezf ef zefzef").is_ok());
        for bad in ["", "plop ", "plop."] {
            assert_eq!(subject(bad).unwrap_err().code(), 6, "{bad}");
        }
    }

    #[test]
    fn body_length_rules() {
        let over = "12345678 ".to_string() + &"0".repeat(93); // 102 chars, has a space
        assert_eq!(body_length(&over, 100).unwrap_err().code(), 7);
        // long line with no space is skipped
        let long_no_space = "0".repeat(260);
        assert!(body_length(&long_no_space, 100).is_ok());
        // 100-char line with space is fine
        let at = "12345678 ".to_string() + &"0".repeat(91); // 100 chars
        assert!(body_length(&at, 100).is_ok());
        assert!(body_length(&over, 150).is_ok());
    }

    #[test]
    fn trailing_space_rules() {
        assert_eq!(trailing_space("pdzofjzf ").unwrap_err().code(), 8);
        assert_eq!(trailing_space("\nrerer\n\n  \nLUM-2345").unwrap_err().code(), 8);
        assert!(trailing_space("\nrerer\n\n\nLUM-2345").is_ok());
    }

    #[test]
    fn need_jira_rules() {
        let mut c = cfg();
        assert!(need_jira("feat", &c));
        assert!(need_jira("fix", &c));
        assert!(!need_jira("docs", &c));
        assert!(!need_jira("test", &c));
        c.no_jira = true;
        assert!(!need_jira("feat", &c));
    }

    #[test]
    fn jira_rules() {
        assert_eq!(jira("feat", "", &cfg()).unwrap_err().code(), 9);
        assert!(jira("lint", "", &cfg()).is_ok());
        assert!(jira("feat", "ABC-123", &cfg()).is_ok());
        assert!(jira("feat", "AB-123", &cfg()).is_ok());
    }

    #[test]
    fn revert_rules() {
        let no_sha = "rerer\n\nLUM-2345";
        let with_sha = "rerer\n\nThis reverts commit 1234567890.\n\nLUM-2345";
        assert_eq!(revert(no_sha, &cfg()).unwrap_err().code(), 10);
        assert!(revert(with_sha, &cfg()).is_ok());
        let mut c = cfg();
        c.no_revert_sha1 = true;
        assert!(revert(no_sha, &c).is_ok());
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cargo test --lib validate`
Expected: FAIL (compile error — functions not defined).

- [ ] **Step 3: Write the implementation** (top of `src/validate.rs`)

```rust
use crate::config::Config;
use crate::error::ValidationError;
use crate::patterns;

pub enum HeaderKind {
    Temp,
    Revert,
    Conventional {
        type_: String,
        scope: String,
        subject: String,
    },
}

pub fn classify_header(header: &str, config: &Config) -> Result<HeaderKind, ValidationError> {
    if config.allow_temp && patterns::TEMP_HEADER.is_match(header) {
        Ok(HeaderKind::Temp)
    } else if patterns::REVERT_HEADER.is_match(header) {
        Ok(HeaderKind::Revert)
    } else if let Some(caps) = patterns::HEADER.captures(header) {
        Ok(HeaderKind::Conventional {
            type_: caps[1].to_string(),
            scope: caps[2].to_string(),
            subject: caps[3].to_string(),
        })
    } else {
        Err(ValidationError::Header(
            "commit header doesn't match overall header pattern: 'type(scope): message'"
                .to_string(),
        ))
    }
}

pub fn header_length(header: &str, max: usize) -> Result<(), ValidationError> {
    if header.chars().count() > max {
        return Err(ValidationError::HeaderLength(format!(
            "commit header length is more than {max} characters"
        )));
    }
    Ok(())
}

pub fn commit_type(type_: &str) -> Result<(), ValidationError> {
    if patterns::TYPE.is_match(type_) {
        Ok(())
    } else {
        Err(ValidationError::Type(format!("commit type '{type_}' is unknown")))
    }
}

pub fn scope(scope: &str) -> Result<(), ValidationError> {
    if patterns::SCOPE.is_match(scope) {
        Ok(())
    } else {
        Err(ValidationError::Scope(format!(
            "commit scope '{scope}' is not kebab-case"
        )))
    }
}

pub fn subject(subject: &str) -> Result<(), ValidationError> {
    if patterns::SUBJECT.is_match(subject) {
        Ok(())
    } else {
        Err(ValidationError::Subject(format!(
            "commit subject '{subject}' should not end with a '.'"
        )))
    }
}

pub fn body_length(text: &str, max: usize) -> Result<(), ValidationError> {
    for line in text.split('\n') {
        // Skip lines with no whitespace as they can't be wrapped.
        if !line.contains(|c: char| c.is_ascii_whitespace()) {
            continue;
        }
        if line.chars().count() > max {
            return Err(ValidationError::BodyLength(format!(
                "body message line length is more than {max} characters"
            )));
        }
    }
    Ok(())
}

pub fn trailing_space(text: &str) -> Result<(), ValidationError> {
    for line in text.split('\n') {
        if patterns::TRAILING_SPACE.is_match(line) {
            return Err(ValidationError::TrailingSpace(
                "body message must not have trailing spaces".to_string(),
            ));
        }
    }
    Ok(())
}

pub fn need_jira(type_: &str, config: &Config) -> bool {
    if config.no_jira {
        return false;
    }
    config.jira_types.iter().any(|t| t == type_)
}

pub fn jira(type_: &str, jira: &str, config: &Config) -> Result<(), ValidationError> {
    if need_jira(type_, config) && jira.is_empty() {
        return Err(ValidationError::Jira(format!(
            "commits with type '{type_}' need to include a reference to a JIRA ticket, by adding the project prefix and the issue number to the commit message, this could be done easily with: git commit -m 'feat(widget): add a wonderful widget' -m LUM-1234"
        )));
    }
    Ok(())
}

pub fn revert(body: &str, config: &Config) -> Result<(), ValidationError> {
    if config.no_revert_sha1 {
        return Ok(());
    }
    let has_sha = body
        .split('\n')
        .any(|line| patterns::REVERT_COMMIT.is_match(line));
    if has_sha {
        Ok(())
    } else {
        Err(ValidationError::Revert(
            "revert commit should contain the reverted sha1".to_string(),
        ))
    }
}
```

- [ ] **Step 4: Wire into `src/lib.rs`** (add `mod validate;`).

- [ ] **Step 5: Run tests to verify they pass**

Run: `cargo test --lib && cargo clippy --all-targets -- -D warnings`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add src/validate.rs src/lib.rs
git commit -m "feat(validate): port per-rule validation functions"
```

---

## Task 7: Orchestration (`validate_message` in `lib.rs`)

Ties parser + rules together in the exact order of the bash `validate` function.

**Files:**
- Modify: `src/lib.rs`

**Interfaces:**
- Consumes: `parser::parse`, `validate::*`, `config::Config`.
- Produces:
  - `pub enum Outcome { Valid, Temp }`.
  - `pub fn validate_message(message: &str, config: &Config) -> Result<Outcome, ValidationError>`.

- [ ] **Step 1: Write the failing tests** (append to `src/lib.rs`) — porting the `overall validation` cases from `validator.bats`.

```rust
#[cfg(test)]
mod tests {
    use super::*;

    fn code(msg: &str, config: &Config) -> i32 {
        validate_message(msg, config).map(|_| 0).unwrap_or_else(|e| e.code())
    }

    #[test]
    fn invalid_structure() {
        assert_eq!(code("plop\nplop", &Config::default()), 1);
    }

    #[test]
    fn invalid_header() {
        assert_eq!(code("plop", &Config::default()), 2);
    }

    #[test]
    fn invalid_header_length() {
        let msg = "feat(plop): 012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789";
        assert_eq!(code(msg, &Config::default()), 3);
    }

    #[test]
    fn invalid_type() {
        let msg = "Feat(scope1): subject\n\nCommit about stuff\n\nLUM-2345";
        assert_eq!(code(msg, &Config::default()), 4);
    }

    #[test]
    fn invalid_scope() {
        let msg = "feat(scope 1): subject\n\nCommit about stuff\n\nLUM-2345";
        assert_eq!(code(msg, &Config::default()), 5);
    }

    #[test]
    fn valid_capitalized_subject_is_not_subject_error() {
        let msg = "feat(scope1): Subject\n\nCommit about stuff\n\nLUM-2345";
        assert_ne!(code(msg, &Config::default()), 6);
    }

    #[test]
    fn invalid_body_length() {
        let msg = "feat(scope1): subject\n\n1 2 3 4 5678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901\n\nLUM-2345";
        assert_eq!(code(msg, &Config::default()), 7);
    }

    #[test]
    fn invalid_body_trailing_space() {
        let msg = "chore(scope1): subject\n\n123456789012345678901234567890123456789012 ";
        assert_eq!(code(msg, &Config::default()), 8);
    }

    #[test]
    fn invalid_footer_length() {
        let msg = "feat(scope1): subject\n\nplop\n\nLUM-2345\nBROKEN:\n- 12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901";
        assert_eq!(code(msg, &Config::default()), 7);
    }

    #[test]
    fn invalid_footer_trailing_space() {
        let msg = "feat(scope1): subject\n\nplop\n\nLUM-2345\nBROKEN:\n- 123456 ";
        assert_eq!(code(msg, &Config::default()), 8);
    }

    #[test]
    fn missing_jira() {
        let msg = "feat(scope1): subject\n\nCommit about stuff\n\n2345";
        assert_eq!(code(msg, &Config::default()), 9);
    }

    #[test]
    fn fully_valid() {
        let msg = "feat(scope1): subject\n\nCommit about stuff dezd\n\n12345678901234567890123456789012345678901234567890\n12345678901234567890123456789012345678901234567890\n\nLUM-2345\nBROKEN:\n- plop\n- plop";
        assert_eq!(code(msg, &Config::default()), 0);
    }

    #[test]
    fn revert_valid_with_sha() {
        let msg = "Revert \"feat(scope1): subject\"\n\nThis reverts commit 12345678900.\nCommit about stuff dezd\n\n12345678901234567890123456789012345678901234567890\n\nLUM-2345\nBROKEN:\n- plop\n- plop";
        assert_eq!(code(msg, &Config::default()), 0);
    }

    #[test]
    fn fixup_valid_when_allowed_rejected_otherwise() {
        let msg = "fixup! plepozkfopezr\n\nCommit about stuff dezd\n\nLUM-2345\nBROKEN:\n- plop\n- plop";
        let mut c = Config::default();
        assert_eq!(code(msg, &c), 2);
        c.allow_temp = true;
        assert_eq!(code(msg, &c), 0);
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cargo test --lib`
Expected: FAIL (compile error — `validate_message`/`Outcome` not defined).

- [ ] **Step 3: Write the implementation** — the final `src/lib.rs` reads:

```rust
pub mod config;
pub mod error;
mod parser;
mod patterns;
mod validate;

pub use config::{Config, Overrides};
pub use error::ValidationError;

use validate::HeaderKind;

#[derive(Debug, PartialEq, Eq)]
pub enum Outcome {
    Valid,
    Temp,
}

pub fn validate_message(message: &str, config: &Config) -> Result<Outcome, ValidationError> {
    let parsed = parser::parse(message, config.jira_in_header)?;

    match validate::classify_header(&parsed.header, config)? {
        HeaderKind::Temp => Ok(Outcome::Temp),
        HeaderKind::Revert => {
            validate::revert(&parsed.body, config)?;
            Ok(Outcome::Valid)
        }
        HeaderKind::Conventional { type_, scope, subject } => {
            validate::header_length(&parsed.header, config.header_max_length)?;
            validate::commit_type(&type_)?;
            validate::scope(&scope)?;
            validate::subject(&subject)?;
            validate::body_length(&parsed.body, config.body_max_length)?;
            validate::body_length(&parsed.footer, config.body_max_length)?;
            validate::trailing_space(&parsed.body)?;
            validate::trailing_space(&parsed.footer)?;
            validate::jira(&type_, &parsed.jira, config)?;
            Ok(Outcome::Valid)
        }
    }
}
```

(Keep the `#[cfg(test)] mod tests { ... }` block from Step 1 at the bottom of the file.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `cargo test --lib && cargo clippy --all-targets -- -D warnings`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/lib.rs
git commit -m "feat(lib): orchestrate full commit validation"
```

---

## Task 8: Message preprocessing (`preprocess.rs`)

Reproduces `check_message.sh`'s pre-validation handling: skip `*MERGE_MSG` paths, strip `#` comment lines, skip messages whose first word is `merge` (any case).

**Files:**
- Create: `src/preprocess.rs`
- Modify: `src/lib.rs` (add `pub mod preprocess;`)

**Interfaces:**
- Produces:
  - `pub enum Preprocessed { Skip, Message(String) }`.
  - `pub fn preprocess_message_file(path: &str, contents: &str) -> Preprocessed`.

- [ ] **Step 1: Write the failing tests** (in `src/preprocess.rs`) — porting `check_message.bats` preprocessing cases.

```rust
#[cfg(test)]
mod tests {
    use super::*;

    fn is_skip(path: &str, contents: &str) -> bool {
        matches!(preprocess_message_file(path, contents), Preprocessed::Skip)
    }

    #[test]
    fn skips_merge_msg_path() {
        assert!(is_skip("/some/path/MERGE_MSG", "Merge branch 'foo' into 'bar'"));
    }

    #[test]
    fn skips_merge_first_word_any_case() {
        for msg in [
            "Merge branch 'foo' into 'bar'",
            "Merge pull request #1",
            "MERGE branch 'feature' into 'main'",
            "MeRgE branch 'test'",
            "merge whatever",
        ] {
            assert!(is_skip("/x/COMMIT_EDITMSG", msg), "{msg}");
        }
    }

    #[test]
    fn strips_comment_lines() {
        match preprocess_message_file("/x/COMMIT_EDITMSG", "# a comment\nfeat(scope): valid subject\n") {
            Preprocessed::Message(m) => assert_eq!(m, "feat(scope): valid subject"),
            Preprocessed::Skip => panic!("should not skip"),
        }
    }

    #[test]
    fn returns_message_for_normal_commit() {
        match preprocess_message_file("/x/COMMIT_EDITMSG", "feat(widget): add a widget") {
            Preprocessed::Message(m) => assert_eq!(m, "feat(widget): add a widget"),
            Preprocessed::Skip => panic!("should not skip"),
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cargo test --lib preprocess`
Expected: FAIL (compile error — not defined).

- [ ] **Step 3: Write the implementation** (top of `src/preprocess.rs`)

```rust
pub enum Preprocessed {
    Skip,
    Message(String),
}

pub fn preprocess_message_file(path: &str, contents: &str) -> Preprocessed {
    if path.ends_with("MERGE_MSG") {
        return Preprocessed::Skip;
    }

    // Remove comment lines (leading '#'), mirroring `sed '/^#/d'`.
    let stripped = contents
        .lines()
        .filter(|line| !line.starts_with('#'))
        .collect::<Vec<_>>()
        .join("\n");

    // First word (up to the first space), lowercased, like `${MSG%% *}`.
    let first_word = stripped
        .split(' ')
        .next()
        .unwrap_or("")
        .to_lowercase();
    if first_word == "merge" {
        return Preprocessed::Skip;
    }

    Preprocessed::Message(stripped)
}
```

- [ ] **Step 4: Wire into `src/lib.rs`** — add `pub mod preprocess;` near the other module declarations.

- [ ] **Step 5: Run tests to verify they pass**

Run: `cargo test --lib && cargo clippy --all-targets -- -D warnings`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add src/preprocess.rs src/lib.rs
git commit -m "feat(preprocess): port merge/comment message handling"
```

---

## Task 9: CLI — `message` subcommand (`main.rs`)

The `clap` CLI, config assembly from flags+env, and the `message` subcommand. `range` is added in Task 10.

**Files:**
- Modify: `src/main.rs`
- Create: `tests/cli.rs`

**Interfaces:**
- Consumes: `commit_message_validator::{validate_message, Config, Overrides, Outcome, ValidationError}` and `commit_message_validator::preprocess::{preprocess_message_file, Preprocessed}`.
- Produces: binary `commit-message-validator` with subcommand `message <FILE>`; process exit code = `ValidationError::code()` on failure, 0 on success/temp/skip.

- [ ] **Step 1: Write the failing integration tests** (in `tests/cli.rs`)

```rust
use assert_cmd::Command;
use std::io::Write;
use tempfile::NamedTempFile;

fn write_msg(contents: &str) -> NamedTempFile {
    let mut f = NamedTempFile::new().unwrap();
    f.write_all(contents.as_bytes()).unwrap();
    f
}

#[test]
fn message_accepts_valid_commit() {
    let f = write_msg("feat(widget): add a wonderful widget\n");
    Command::cargo_bin("commit-message-validator")
        .unwrap()
        .args(["message", f.path().to_str().unwrap()])
        .arg("--no-jira")
        .assert()
        .success();
}

#[test]
fn message_rejects_invalid_commit() {
    let f = write_msg("this is not valid\n");
    Command::cargo_bin("commit-message-validator")
        .unwrap()
        .args(["--no-jira", "message", f.path().to_str().unwrap()])
        .assert()
        .failure()
        .code(2);
}

#[test]
fn message_skips_merge_commit() {
    let f = write_msg("Merge branch 'foo' into 'bar'\n");
    Command::cargo_bin("commit-message-validator")
        .unwrap()
        .args(["message", f.path().to_str().unwrap()])
        .assert()
        .success();
}

#[test]
fn message_strips_comments() {
    let f = write_msg("# comment\nfeat(scope): valid subject\n");
    Command::cargo_bin("commit-message-validator")
        .unwrap()
        .args(["--no-jira", "message", f.path().to_str().unwrap()])
        .assert()
        .success();
}

#[test]
fn jira_types_flag_requires_jira_for_feat_not_fix() {
    let feat = write_msg("feat(widget): add a wonderful widget\n");
    Command::cargo_bin("commit-message-validator")
        .unwrap()
        .args(["--jira-types", "feat", "message", feat.path().to_str().unwrap()])
        .assert()
        .failure()
        .code(9);

    let fix = write_msg("fix(widget): correct a bug\n");
    Command::cargo_bin("commit-message-validator")
        .unwrap()
        .args(["--jira-types", "feat", "message", fix.path().to_str().unwrap()])
        .assert()
        .success();
}

#[test]
fn no_jira_via_env_var() {
    let f = write_msg("feat(widget): add a wonderful widget\n");
    Command::cargo_bin("commit-message-validator")
        .unwrap()
        .env("COMMIT_VALIDATOR_NO_JIRA", "1")
        .args(["message", f.path().to_str().unwrap()])
        .assert()
        .success();
}

#[test]
fn message_missing_file_errors() {
    Command::cargo_bin("commit-message-validator")
        .unwrap()
        .args(["message", "/no/such/file/xyz"])
        .assert()
        .failure();
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cargo test --test cli`
Expected: FAIL (no `message` subcommand yet / arg parse errors).

- [ ] **Step 3: Write the implementation** — full `src/main.rs`

```rust
use std::process::ExitCode;

use clap::{Args, Parser, Subcommand};
use commit_message_validator::preprocess::{preprocess_message_file, Preprocessed};
use commit_message_validator::{validate_message, Config, Outcome, Overrides, ValidationError};

#[derive(Parser)]
#[command(name = "commit-message-validator", version, about = "Enforce angular commit message convention")]
struct Cli {
    #[command(flatten)]
    opts: CliOptions,
    #[command(subcommand)]
    command: Command,
}

#[derive(Args)]
struct CliOptions {
    /// Do not require JIRA references.
    #[arg(long, global = true)]
    no_jira: bool,
    /// Allow `fixup!` / `squash!` commits.
    #[arg(long, global = true)]
    allow_temp: bool,
    /// Do not require the reverted sha1 in revert commits.
    #[arg(long, global = true)]
    no_revert_sha1: bool,
    /// Allow the JIRA reference to appear in the header.
    #[arg(long, global = true)]
    jira_in_header: bool,
    /// Maximum header length (default 100).
    #[arg(long, global = true)]
    header_length: Option<usize>,
    /// Maximum body line length (default 100).
    #[arg(long, global = true)]
    body_length: Option<usize>,
    /// Space-separated commit types that require a JIRA reference (default "feat fix").
    #[arg(long, global = true)]
    jira_types: Option<String>,
}

#[derive(Subcommand)]
enum Command {
    /// Validate a single commit message file (commit-msg hook).
    Message { file: String },
    /// Validate every commit in a git revision range.
    Range { range: String },
}

impl CliOptions {
    fn to_overrides(&self) -> Overrides {
        Overrides {
            no_jira: self.no_jira,
            allow_temp: self.allow_temp,
            no_revert_sha1: self.no_revert_sha1,
            jira_in_header: self.jira_in_header,
            header_length: self.header_length,
            body_length: self.body_length,
            jira_types: self.jira_types.clone(),
        }
    }
}

fn report(result: Result<Outcome, ValidationError>) -> u8 {
    match result {
        Ok(Outcome::Valid) => 0,
        Ok(Outcome::Temp) => {
            println!("ignoring temporary commit");
            0
        }
        Err(e) => {
            eprintln!("{e}");
            e.code() as u8
        }
    }
}

fn run_message(file: &str, config: &Config) -> u8 {
    let contents = match std::fs::read_to_string(file) {
        Ok(c) => c,
        Err(e) => {
            eprintln!("cannot read commit message file '{file}': {e}");
            return 1;
        }
    };
    match preprocess_message_file(file, &contents) {
        Preprocessed::Skip => 0,
        Preprocessed::Message(msg) => report(validate_message(&msg, config)),
    }
}

fn main() -> ExitCode {
    let cli = Cli::parse();
    let config = Config::resolve(&cli.opts.to_overrides(), |name| std::env::var(name).ok());

    let code = match &cli.command {
        Command::Message { file } => run_message(file, &config),
        Command::Range { range } => {
            eprintln!("range not yet implemented for '{range}'");
            1
        }
    };
    ExitCode::from(code)
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cargo test --test cli && cargo clippy --all-targets -- -D warnings`
Expected: PASS (the `range` placeholder test is not exercised yet).

- [ ] **Step 5: Commit**

```bash
git add src/main.rs tests/cli.rs
git commit -m "feat(cli): add message subcommand with flag/env config"
```

---

## Task 10: CLI — `range` subcommand + git adapter

Adds range validation by shelling out to git, matching `check.sh` (`--no-merges`, per-commit `%B`, stop on first failure).

**Files:**
- Modify: `src/main.rs`
- Modify: `tests/cli.rs`

**Interfaces:**
- Consumes: `std::process::Command` (git subprocess).
- Produces: subcommand `range <REV_RANGE>`; exits with the first failing commit's code, else 0.

- [ ] **Step 1: Write the failing integration tests** (append to `tests/cli.rs`)

```rust
use std::process::Command as StdCommand;

fn git(repo: &std::path::Path, args: &[&str]) {
    let status = StdCommand::new("git")
        .current_dir(repo)
        .args(args)
        .status()
        .unwrap();
    assert!(status.success(), "git {args:?} failed");
}

fn init_repo() -> tempfile::TempDir {
    let dir = tempfile::tempdir().unwrap();
    git(dir.path(), &["init", "-q"]);
    git(dir.path(), &["config", "user.email", "test@test.com"]);
    git(dir.path(), &["config", "user.name", "Test"]);
    git(dir.path(), &["commit", "--allow-empty", "-q", "-m", "chore(init): initial commit"]);
    dir
}

#[test]
fn range_accepts_valid_commits() {
    let dir = init_repo();
    git(dir.path(), &["commit", "--allow-empty", "-q", "-m", "feat(widget): add widget"]);
    Command::cargo_bin("commit-message-validator")
        .unwrap()
        .current_dir(dir.path())
        .env("COMMIT_VALIDATOR_NO_JIRA", "1")
        .args(["range", "HEAD~1..HEAD"])
        .assert()
        .success();
}

#[test]
fn range_rejects_invalid_commit() {
    let dir = init_repo();
    git(dir.path(), &["commit", "--allow-empty", "-q", "-m", "bad commit message"]);
    Command::cargo_bin("commit-message-validator")
        .unwrap()
        .current_dir(dir.path())
        .env("COMMIT_VALIDATOR_NO_JIRA", "1")
        .args(["range", "HEAD~1..HEAD"])
        .assert()
        .failure();
}

#[test]
fn range_empty_succeeds() {
    let dir = init_repo();
    Command::cargo_bin("commit-message-validator")
        .unwrap()
        .current_dir(dir.path())
        .env("COMMIT_VALIDATOR_NO_JIRA", "1")
        .args(["range", "HEAD..HEAD"])
        .assert()
        .success();
}

#[test]
fn range_bad_revision_errors() {
    let dir = init_repo();
    Command::cargo_bin("commit-message-validator")
        .unwrap()
        .current_dir(dir.path())
        .args(["range", "not-a-real-ref..HEAD"])
        .assert()
        .failure();
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cargo test --test cli range`
Expected: FAIL (range prints "not yet implemented", exits 1 — `range_accepts_valid_commits` and `range_empty_succeeds` fail).

- [ ] **Step 3: Write the implementation** — add git helpers and replace the `Range` arm in `src/main.rs`.

Add these functions above `main`:

```rust
fn git_output(args: &[&str]) -> Result<String, String> {
    let output = std::process::Command::new("git")
        .args(args)
        .output()
        .map_err(|e| format!("failed to run git: {e}"))?;
    if !output.status.success() {
        return Err(format!(
            "git {args:?} failed: {}",
            String::from_utf8_lossy(&output.stderr).trim()
        ));
    }
    Ok(String::from_utf8_lossy(&output.stdout).into_owned())
}

fn run_range(range: &str, config: &Config) -> u8 {
    let hashes = match git_output(&["log", "--no-merges", "--pretty=%H", "--no-decorate", range]) {
        Ok(out) => out,
        Err(e) => {
            eprintln!("{e}");
            return 1;
        }
    };
    for hash in hashes.lines() {
        let message = match git_output(&["log", "-1", "--pretty=%B", hash]) {
            Ok(m) => m,
            Err(e) => {
                eprintln!("{e}");
                return 1;
            }
        };
        println!("checking commit {hash}...");
        // %B carries a trailing newline; trim it like bash command substitution.
        let code = report(validate_message(message.trim_end_matches('\n'), config));
        if code != 0 {
            return code;
        }
    }
    println!("All commits successfully checked");
    0
}
```

Replace the `Range` arm in `main`:

```rust
        Command::Range { range } => run_range(range, &config),
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cargo test --test cli && cargo clippy --all-targets -- -D warnings`
Expected: PASS.

- [ ] **Step 5: Verify coverage locally**

Run: `cargo llvm-cov --all-targets --fail-under-lines 90`
Expected: PASS (≥90%; investigate any uncovered lines and add tests toward 100%).

- [ ] **Step 6: Commit**

```bash
git add src/main.rs tests/cli.rs
git commit -m "feat(cli): add range subcommand via git subprocess"
```

---

## Task 11: Release workflow (prebuilt binaries)

On tag push, build static binaries for the four target triples and attach them to the GitHub Release.

**Files:**
- Create: `.github/workflows/release.yml`

**Interfaces:**
- Produces: release assets named `commit-message-validator-<target>` for `x86_64-unknown-linux-musl`, `aarch64-unknown-linux-musl`, `x86_64-apple-darwin`, `aarch64-apple-darwin`.

- [ ] **Step 1: Write `.github/workflows/release.yml`**

```yaml
---
name: Release
on:
  push:
    tags: ["v*"]

permissions:
  contents: write

jobs:
  build:
    strategy:
      matrix:
        include:
          - target: x86_64-unknown-linux-musl
            os: ubuntu-latest
          - target: aarch64-unknown-linux-musl
            os: ubuntu-latest
          - target: x86_64-apple-darwin
            os: macos-latest
          - target: aarch64-apple-darwin
            os: macos-latest
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
        with:
          targets: ${{ matrix.target }}
      - name: Install cross-compilation deps (linux)
        if: runner.os == 'Linux'
        run: |
          sudo apt-get update
          sudo apt-get install -y musl-tools
          cargo install cross --locked
      - name: Build (linux via cross)
        if: runner.os == 'Linux'
        run: cross build --release --target ${{ matrix.target }}
      - name: Build (macos)
        if: runner.os == 'macOS'
        run: cargo build --release --target ${{ matrix.target }}
      - name: Rename artifact
        run: |
          cp target/${{ matrix.target }}/release/commit-message-validator \
             commit-message-validator-${{ matrix.target }}
      - name: Attach to release
        uses: softprops/action-gh-release@v2
        with:
          files: commit-message-validator-${{ matrix.target }}
```

- [ ] **Step 2: Validate the workflow YAML locally**

Run: `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/release.yml'))" && echo OK`
Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "ci(release): build cross-platform binaries on tag"
```

---

## Task 12: GitHub composite Action (`action.yml`)

Rewrite the composite Action to download the prebuilt binary for the runner and run `range`, preserving the existing `inputs → env` wiring.

**Files:**
- Modify: `action.yml`

**Interfaces:**
- Consumes: release assets from Task 11; env var names from Global Constraints.
- Produces: composite action that validates `base..head`.

- [ ] **Step 1: Rewrite `action.yml`**

```yaml
---
name: 'Commit message validator'
description: >
  Enforce angular commit message convention using a prebuilt Rust binary.
author: 'Sébastien Boulle'
branding:
  icon: 'check-square'
  color: 'green'
inputs:
  no_jira:
    description: 'If not empty, no validation is done on JIRA refs.'
    required: false
  allow_temp:
    description: 'If not empty, no validation is done on `fixup!` and `squash!` commits.'
    required: false
  no_revert_sha1:
    description: 'If not empty, reverted sha1 commit is not mandatory in revert commit message.'
    required: false
  header_length:
    description: 'If not empty, max header length.'
    required: false
  body_length:
    description: 'If not empty, max body length.'
    required: false
  jira_types:
    description: 'If not empty, space separated list of types that require Jira refs.'
    required: false
  jira_in_header:
    description: 'If not empty, allow for jira ref in header.'
    required: false
  version:
    description: 'Release tag of the validator binary to download (defaults to the action ref).'
    required: false
    default: ''
runs:
  using: "composite"
  steps:
    - name: Ensure that base is fetched
      run: git fetch origin ${{ github.event.pull_request.base.sha }}
      shell: bash

    - name: Ensure that head is fetched
      run: git fetch origin ${{ github.event.pull_request.head.sha }}
      shell: bash

    - name: Download validator binary
      shell: bash
      run: |
        set -euo pipefail
        case "$(uname -s)-$(uname -m)" in
          Linux-x86_64)   target=x86_64-unknown-linux-musl ;;
          Linux-aarch64)  target=aarch64-unknown-linux-musl ;;
          Darwin-x86_64)  target=x86_64-apple-darwin ;;
          Darwin-arm64)   target=aarch64-apple-darwin ;;
          *) echo "unsupported platform: $(uname -s)-$(uname -m)" >&2; exit 1 ;;
        esac
        version="${{ inputs.version }}"
        if [ -z "$version" ]; then version="${{ github.action_ref }}"; fi
        url="https://github.com/lumapps/commit-message-validator/releases/download/${version}/commit-message-validator-${target}"
        curl -sSfL "$url" -o /tmp/commit-message-validator
        chmod +x /tmp/commit-message-validator

    - name: Validation
      run: |
        /tmp/commit-message-validator range \
          ${{ github.event.pull_request.base.sha }}..${{ github.event.pull_request.head.sha }} \
          | tee -a "$GITHUB_STEP_SUMMARY"
      env:
        COMMIT_VALIDATOR_NO_JIRA: ${{ inputs.no_jira }}
        COMMIT_VALIDATOR_ALLOW_TEMP: ${{ inputs.allow_temp }}
        COMMIT_VALIDATOR_NO_REVERT_SHA1: ${{ inputs.no_revert_sha1 }}
        GLOBAL_JIRA_IN_HEADER: ${{ inputs.jira_in_header }}
        GLOBAL_JIRA_TYPES: ${{ inputs.jira_types }}
        GLOBAL_MAX_LENGTH: ${{ inputs.header_length }}
        GLOBAL_BODY_MAX_LENGTH: ${{ inputs.body_length }}
      shell: bash
```

- [ ] **Step 2: Validate the YAML**

Run: `python3 -c "import yaml; yaml.safe_load(open('action.yml'))" && echo OK`
Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
git add action.yml
git commit -m "feat(action): run prebuilt rust binary in composite action"
```

---

## Task 13: pre-commit hook + pre-push (download shims)

Replace the `language: script` entry so pre-commit downloads the prebuilt binary and runs `message`; update `pre-push` to use `range`.

**Files:**
- Modify: `.pre-commit-hooks.yaml`
- Create: `hooks/commit-message-validator` (download-and-run shim)
- Modify: `pre-push`

**Interfaces:**
- Consumes: release assets from Task 11.
- Produces: pre-commit `commit-message-validator` hook (commit-msg stage) and a working `pre-push`.

- [ ] **Step 1: Write the shim `hooks/commit-message-validator`**

```bash
#!/usr/bin/env bash
set -euo pipefail

VERSION="${COMMIT_VALIDATOR_VERSION:-master}"
case "$(uname -s)-$(uname -m)" in
  Linux-x86_64)   target=x86_64-unknown-linux-musl ;;
  Linux-aarch64)  target=aarch64-unknown-linux-musl ;;
  Darwin-x86_64)  target=x86_64-apple-darwin ;;
  Darwin-arm64)   target=aarch64-apple-darwin ;;
  *) echo "unsupported platform: $(uname -s)-$(uname -m)" >&2; exit 1 ;;
esac

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/commit-message-validator/${VERSION}"
bin="${cache_dir}/commit-message-validator"
if [ ! -x "$bin" ]; then
  mkdir -p "$cache_dir"
  url="https://github.com/lumapps/commit-message-validator/releases/download/${VERSION}/commit-message-validator-${target}"
  curl -sSfL "$url" -o "$bin"
  chmod +x "$bin"
fi

exec "$bin" message "$@"
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x hooks/commit-message-validator
```

- [ ] **Step 3: Update `.pre-commit-hooks.yaml`**

```yaml
---
- id: commit-message-validator
  name: Commit Message Validator
  description: Checks that commit messages are compliant with Lumapps rules.
  entry: hooks/commit-message-validator
  language: script
  stages: [commit-msg]
```

- [ ] **Step 4: Rewrite `pre-push`** to use the shim's binary via `range`.

```bash
#!/bin/bash -e

remote="$1"
url="$2"

z40=0000000000000000000000000000000000000000

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

while read -r local_ref local_sha remote_ref remote_sha
do
	if [ "$local_sha" = $z40 ]; then
		:
	else
		if [ "$remote_sha" = $z40 ]; then
			range="$local_sha"
		else
			range="$remote_sha..$local_sha"
		fi
		"$DIR/hooks/commit-message-validator" range "$range" || exit $?
	fi
done

exit 0
```

> Note: `hooks/commit-message-validator` accepts the `range` subcommand because it `exec`s the binary with all passed args — but it hardcodes `message`. Adjust the shim to forward the subcommand instead: change its last line to `exec "$bin" "$@"` and update `.pre-commit-hooks.yaml` entry to `hooks/commit-message-validator message` via `args`? Simpler: keep two thin wrappers. See Step 5.

- [ ] **Step 5: Reconcile the shim for both subcommands** — make the shim subcommand-agnostic.

Change the last line of `hooks/commit-message-validator` from:

```bash
exec "$bin" message "$@"
```

to:

```bash
exec "$bin" "$@"
```

And set the pre-commit entry to pass the subcommand explicitly in `.pre-commit-hooks.yaml`:

```yaml
---
- id: commit-message-validator
  name: Commit Message Validator
  description: Checks that commit messages are compliant with Lumapps rules.
  entry: hooks/commit-message-validator message
  language: script
  stages: [commit-msg]
```

(`pre-push` already calls `"$DIR/hooks/commit-message-validator" range "$range"`, which now works.)

- [ ] **Step 6: Shell-check the shim and pre-push parse**

Run: `bash -n hooks/commit-message-validator && bash -n pre-push && echo OK`
Expected: `OK`.

- [ ] **Step 7: Commit**

```bash
git add hooks/commit-message-validator .pre-commit-hooks.yaml pre-push
git commit -m "feat(hooks): download prebuilt binary in pre-commit and pre-push"
```

---

## Task 14: Update docs + remove obsolete bash & bats

Update `README.md` and other docs to the Rust story; delete the superseded bash scripts and `.bats` tests.

**Files:**
- Modify: `README.md`
- Modify: `.pre-commit-config.yaml`
- Modify: `Makefile`
- Modify: `git-commit-template` (only if it references the scripts)
- Delete: `validator.sh`, `check.sh`, `check_message.sh`, `validator.bats`, `check.bats`, `check_message.bats`

**Interfaces:** none (documentation + cleanup).

- [ ] **Step 1: Update `README.md`**

Make these concrete edits:
- In the intro/tagline, replace "with minimal dependancy only git and bash" with wording describing a single prebuilt Rust binary (git still required to read commits).
- Replace any installation section that references cloning/sourcing `check.sh`/`check_message.sh` with: download the binary for your platform from the Releases page (list the four target names), `chmod +x`, and place on `PATH`; or use the pre-commit hook / GitHub Action.
- Replace usage examples that call `check_message.sh <file>` with `commit-message-validator message <file>`, and `check.sh <range>` with `commit-message-validator range <range>`.
- Update the options documentation to the flag table (with env equivalents) from the Global Constraints.
- Keep the commit-convention rules section unchanged (rules are identical).

- [ ] **Step 2: Update `.pre-commit-config.yaml`**

In the self-referencing local hook block, ensure the `commit-message-validator` hook entry matches the new `.pre-commit-hooks.yaml` (id + `stages: [commit-msg]`, args `[--no-jira, --allow-temp]` preserved). No change needed to the other third-party hooks.

- [ ] **Step 3: Update `Makefile`**

The `lint`/`venv` targets drive pre-commit and don't call the removed scripts directly, so they remain valid. Verify by reading the file; if any target references `check.sh`/`validator.sh`, remove that reference. (Expected: no change required.)

- [ ] **Step 4: Check `git-commit-template`**

Read it; it documents the message format for humans. Only edit if it names the bash scripts. (Expected: no change required.)

- [ ] **Step 5: Delete obsolete bash and bats files**

```bash
git rm validator.sh check.sh check_message.sh validator.bats check.bats check_message.bats
```

- [ ] **Step 6: Verify nothing else references the removed files**

Run: `grep -rn -e validator.sh -e check_message.sh -e 'check\.sh' --include='*.yml' --include='*.yaml' --include='*.md' --include='Makefile' . || echo "no dangling references"`
Expected: `no dangling references` (fix any that appear).

- [ ] **Step 7: Full verification**

Run: `cargo fmt --all -- --check && cargo clippy --all-targets -- -D warnings && cargo test && cargo llvm-cov --all-targets --fail-under-lines 90`
Expected: all PASS.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "docs(readme): document rust binary and remove bash implementation"
```

---

## Task 15: Open the draft PR

Push the branch and open a draft PR against `master`.

**Files:** none.

- [ ] **Step 1: Run `/simplify` and `/code-review` over the full branch diff** and address any findings (commit fixes atomically).

- [ ] **Step 2: Push the branch**

```bash
git push -u origin feat/rust-migration
```

- [ ] **Step 3: Open the draft PR**

```bash
gh pr create --draft --base master --title "Migrate commit validator to Rust" \
  --body "Reimplements the bash commit-message validator as a single Rust binary. Behavior-compatible (same rules and exit codes), cleaner CLI (\`message\`/\`range\` subcommands), prebuilt cross-platform release binaries, CI with a 90% coverage gate. See docs/superpowers/specs/2026-07-03-rust-migration-design.md."
```

- [ ] **Step 4: Confirm CI is green on the PR**

Run: `gh pr checks --watch`
Expected: all checks pass.

---

## Notes for the implementer

- **`split('\n')` equals bash `read`:** bash here-strings append a trailing newline, so `while read` over `$MSG` yields exactly the segments `message.split('\n')` produces. Do not use `.lines()` in the parser or rule loops — it would drop a trailing empty segment and change structure results.
- **Regex fidelity:** the subject end-class `[^ ^.]` negates `{space, caret, dot}` on purpose. Don't "fix" it.
- **`%B` trailing newline:** `git log --pretty=%B` appends a newline; `run_range` trims trailing newlines to mirror bash command substitution before validating.
- **Coverage:** if a line can't be covered (e.g. an unreachable arm), add a targeted test or justify it in the PR; the CI floor is 90% but aim for 100%.
