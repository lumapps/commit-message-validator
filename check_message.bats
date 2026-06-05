#!/usr/bin/env bats

setup() {
  TMPFILE=$(mktemp)
  SCRIPT="$BATS_TEST_DIRNAME/check_message.sh"
}

teardown() {
  rm -f "$TMPFILE"
}

@test "check_message: skips MERGE_MSG path" {
  echo "Merge branch 'foo' into 'bar'" > "$TMPFILE"
  run bash "$SCRIPT" "/some/path/MERGE_MSG"
  [ "$status" -eq 0 ]
}

@test "check_message: skips message starting with 'merge'" {
  echo "Merge branch 'foo' into 'bar'" > "$TMPFILE"
  run bash "$SCRIPT" "$TMPFILE"
  [ "$status" -eq 0 ]
}

@test "check_message: skips message starting with 'Merge' (capital)" {
  echo "Merge pull request #1" > "$TMPFILE"
  run bash "$SCRIPT" "$TMPFILE"
  [ "$status" -eq 0 ]
}

@test "check_message: skips message starting with 'MERGE' (all caps)" {
  echo "MERGE branch 'feature' into 'main'" > "$TMPFILE"
  run bash "$SCRIPT" "$TMPFILE"
  [ "$status" -eq 0 ]
}

@test "check_message: skips message starting with 'MeRgE' (mixed case)" {
  echo "MeRgE branch 'test'" > "$TMPFILE"
  run bash "$SCRIPT" "$TMPFILE"
  [ "$status" -eq 0 ]
}

@test "check_message: strips comment lines before validating" {
  printf "# This is a comment\nfeat(scope): valid subject\n" > "$TMPFILE"
  run bash "$SCRIPT" --no-jira "$TMPFILE"
  [ "$status" -eq 0 ]
}

@test "check_message: accepts valid commit message" {
  echo "feat(widget): add a wonderful widget" > "$TMPFILE"
  run bash "$SCRIPT" --no-jira "$TMPFILE"
  [ "$status" -eq 0 ]
}

@test "check_message: rejects invalid commit message" {
  echo "this is not valid" > "$TMPFILE"
  run bash "$SCRIPT" --no-jira "$TMPFILE"
  [ "$status" -ne 0 ]
}

@test "check_message: --jira-types=feat requires JIRA for feat commits" {
  echo "feat(widget): add a wonderful widget" > "$TMPFILE"
  run bash "$SCRIPT" --jira-types=feat "$TMPFILE"
  [ "$status" -ne 0 ]
}

@test "check_message: --jira-types=feat does not require JIRA for fix commits" {
  echo "fix(widget): correct a bug" > "$TMPFILE"
  run bash "$SCRIPT" --jira-types=feat "$TMPFILE"
  [ "$status" -eq 0 ]
}
