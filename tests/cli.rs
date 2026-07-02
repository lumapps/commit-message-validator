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
fn message_missing_file_errors() {
    Command::cargo_bin("commit-message-validator")
        .unwrap()
        .args(["message", "/no/such/file/xyz"])
        .assert()
        .failure();
}
