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
        .args([
            "--jira-types",
            "feat",
            "message",
            feat.path().to_str().unwrap(),
        ])
        .assert()
        .failure()
        .code(9);

    let fix = write_msg("fix(widget): correct a bug\n");
    Command::cargo_bin("commit-message-validator")
        .unwrap()
        .args([
            "--jira-types",
            "feat",
            "message",
            fix.path().to_str().unwrap(),
        ])
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
fn message_accepts_realistic_commit_editmsg_with_comment_block() {
    let f = write_msg(
        "feat(scope): valid subject\n\nsome body text\n\n# Please enter the commit message for your changes.\n# Lines starting with '#' will be ignored.\n",
    );
    Command::cargo_bin("commit-message-validator")
        .unwrap()
        .args(["--no-jira", "message", f.path().to_str().unwrap()])
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
    git(
        dir.path(),
        &[
            "commit",
            "--allow-empty",
            "-q",
            "-m",
            "chore(init): initial commit",
        ],
    );
    dir
}

#[test]
fn range_accepts_valid_commits() {
    let dir = init_repo();
    git(
        dir.path(),
        &[
            "commit",
            "--allow-empty",
            "-q",
            "-m",
            "feat(widget): add widget",
        ],
    );
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
    git(
        dir.path(),
        &["commit", "--allow-empty", "-q", "-m", "bad commit message"],
    );
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
