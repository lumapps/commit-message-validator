#!/usr/bin/env bats

setup() {
  REPO=$(mktemp -d)
  SCRIPT="$BATS_TEST_DIRNAME/check.sh"
  git -C "$REPO" init -q
  git -C "$REPO" config user.email "test@test.com"
  git -C "$REPO" config user.name "Test"
  # base commit to anchor the range
  git -C "$REPO" commit --allow-empty -q -m "chore(init): initial commit"
  BASE=$(git -C "$REPO" rev-parse HEAD)
  export REPO BASE SCRIPT
}

teardown() {
  rm -rf "$REPO"
}

@test "check: accepts range with valid commits" {
  git -C "$REPO" commit --allow-empty -q -m "feat(widget): add widget"
  run env COMMIT_VALIDATOR_NO_JIRA=1 bash -c "cd '$REPO' && bash '$SCRIPT' '$BASE..HEAD'"
  [ "$status" -eq 0 ]
}

@test "check: rejects range containing invalid commit" {
  git -C "$REPO" commit --allow-empty -q -m "bad commit message"
  run env COMMIT_VALIDATOR_NO_JIRA=1 bash -c "cd '$REPO' && bash '$SCRIPT' '$BASE..HEAD'"
  [ "$status" -ne 0 ]
}

@test "check: empty range succeeds" {
  run env COMMIT_VALIDATOR_NO_JIRA=1 bash -c "cd '$REPO' && bash '$SCRIPT' '$BASE..$BASE'"
  [ "$status" -eq 0 ]
}
