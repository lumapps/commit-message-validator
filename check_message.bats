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

@test "check_message: strips the commit.verbose diff below the scissors line" {
  # With `commit.verbose = true`, git appends the staged diff below a scissors
  # line. The diff isn't comment-prefixed, so a naive `sed '/^#/d'` leaves it
  # in the message, right after the header with no blank line in between.
  cat > "$TMPFILE" << 'EOF'
feat(scope): valid subject
# Please enter the commit message for your changes. Lines starting
# with '#' will be ignored, and an empty message aborts the commit.
#
# ------------------------ >8 ------------------------
# Do not modify or remove the line above.
# Everything below it will be ignored.
diff --git c/foo.tf i/foo.tf
index 0000000..1111111 100644
--- c/foo.tf
+++ i/foo.tf
@@ -1 +1 @@
-old
+new
EOF
  run bash "$SCRIPT" --no-jira "$TMPFILE"
  [ "$status" -eq 0 ]
}

@test "check_message: preserves the body when stripping the commit.verbose diff" {
  cat > "$TMPFILE" << 'EOF'
feat(scope): valid subject

this body line must survive
# Please enter the commit message for your changes. Lines starting
# with '#' will be ignored, and an empty message aborts the commit.
#
# ------------------------ >8 ------------------------
# Do not modify or remove the line above.
# Everything below it will be ignored.
diff --git c/foo.tf i/foo.tf
index 0000000..1111111 100644
--- c/foo.tf
+++ i/foo.tf
@@ -1 +1 @@
-old
+new
EOF
  run bash "$SCRIPT" --no-jira "$TMPFILE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"this body line must survive"* ]]
}

@test "check_message: does not truncate a body line that merely contains '>8'" {
  cat > "$TMPFILE" << 'EOF'
feat(scope): valid subject

# not a scissors line, just a comment mentioning >8 characters
this body line must survive too
EOF
  run bash "$SCRIPT" --no-jira "$TMPFILE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"this body line must survive too"* ]]
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
