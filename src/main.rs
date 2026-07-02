use std::process::ExitCode;

use clap::{Args, Parser, Subcommand};
use commit_message_validator::preprocess::{preprocess_message_file, Preprocessed};
use commit_message_validator::{validate_message, Config, Outcome, Overrides, ValidationError};

#[derive(Parser)]
#[command(
    name = "commit-message-validator",
    version,
    about = "Enforce angular commit message convention"
)]
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

fn main() -> ExitCode {
    let cli = Cli::parse();
    let config = Config::resolve(&cli.opts.to_overrides(), |name| std::env::var(name).ok());

    let code = match &cli.command {
        Command::Message { file } => run_message(file, &config),
        Command::Range { range } => run_range(range, &config),
    };
    ExitCode::from(code)
}
