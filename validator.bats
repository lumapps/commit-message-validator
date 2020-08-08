#!/usr/bin/env bats

source $BATS_TEST_DIRNAME/validator.sh

@test "structure: one trailing line" {
  COMMIT="plop plop
"
  run validate_overall_structure "$COMMIT"
  [ "$status" -eq $ERROR_STRUCTURE ]
}

@test "structure: missing empty line after the header" {
  COMMIT="plop plop
plop

plop
"
  run validate_overall_structure "$COMMIT"
  [ "$status" -eq $ERROR_STRUCTURE ]
}

@test "structure: missing empty line after the header for jira" {
  COMMIT="plop plop
ABC-1234
"
  run validate_overall_structure "$COMMIT"
  [ "$status" -eq $ERROR_STRUCTURE ]
}

@test "structure: missing empty line after the header for broken" {
  COMMIT="plop plop
BROKEN:
"
  run validate_overall_structure "$COMMIT"
  [ "$status" -eq $ERROR_STRUCTURE ]
}

@test "structure: missing empty line after the body with jira ref" {
  COMMIT="plop plop

plop
plop
plop
plop
LUM-1234
"
  run validate_overall_structure "$COMMIT"
  [ "$status" -eq $ERROR_STRUCTURE ]
}

@test "structure: missing empty line after the body with broken stuff" {
  COMMIT="plop plop

plop
plop
plop
plop
BROKEN:
"
  run validate_overall_structure "$COMMIT"
  [ "$status" -eq $ERROR_STRUCTURE ]
}


@test "structure: empty line after the body" {
  COMMIT="plop plop

plop
plop
plop
plop

"
  run validate_overall_structure "$COMMIT"
  [ "$status" -eq $ERROR_STRUCTURE ]
}

@test "structure: valid commit message with header only" {
  COMMIT="plop plop"

  validate_overall_structure "$COMMIT"
  [[ $GLOBAL_HEADER == "plop plop" ]]
  [[ $GLOBAL_BODY == "" ]]
  [[ $GLOBAL_JIRA == "" ]]
  [[ $GLOBAL_FOOTER == "" ]]
}

@test "structure: valid commit message with header and JIRA" {
  COMMIT="plop plop

ABC-1234"

  validate_overall_structure "$COMMIT"
  [[ $GLOBAL_HEADER == "plop plop" ]]
  [[ $GLOBAL_BODY == "" ]]
  [[ $GLOBAL_JIRA == "ABC-1234" ]]
  [[ $GLOBAL_FOOTER == "" ]]
}

@test "structure: valid commit message with header and multiple JIRA" {
  COMMIT="plop plop

ABC-1234 DEF-1234"

  validate_overall_structure "$COMMIT"
  [[ $GLOBAL_HEADER == "plop plop" ]]
  [[ $GLOBAL_BODY == "" ]]
  [[ $GLOBAL_JIRA == "ABC-1234 DEF-1234" ]]
  [[ $GLOBAL_FOOTER == "" ]]
}

@test "structure: valid commit message with header and broken" {
  COMMIT="plop plop

BROKEN:
- plop
- plop"

  validate_overall_structure "$COMMIT"
  [[ $GLOBAL_HEADER == "plop plop" ]]
  [[ $GLOBAL_BODY == "" ]]
  [[ $GLOBAL_JIRA == "" ]]
  [[ $GLOBAL_FOOTER == "- plop\n- plop\n" ]]
}

@test "structure: valid commit message with header, jira and broken" {
  COMMIT="plop plop

ABC-1234
BROKEN:
- plop
- plop"

  validate_overall_structure "$COMMIT"
  [[ $GLOBAL_HEADER == "plop plop" ]]
  [[ $GLOBAL_BODY == "" ]]
  [[ $GLOBAL_JIRA == "ABC-1234" ]]
  [[ $GLOBAL_FOOTER == "- plop\n- plop\n" ]]
}

@test "structure: valid commit message with header and body" {
  COMMIT="plop plop

hello"

  validate_overall_structure "$COMMIT"
  [[ $GLOBAL_HEADER == "plop plop" ]]
  [[ $GLOBAL_BODY == "hello\n" ]]
  [[ $GLOBAL_JIRA == "" ]]
  [[ $GLOBAL_FOOTER == "" ]]
}

@test "structure: valid commit message with header and multiline body" {
  COMMIT="plop plop

hello

plopplop
plopplop

toto"

  validate_overall_structure "$COMMIT"
  [[ $GLOBAL_HEADER == "plop plop" ]]
  [[ $GLOBAL_BODY == "hello\nplopplop\nplopplop\ntoto\n" ]]
  [[ $GLOBAL_JIRA == "" ]]
  [[ $GLOBAL_FOOTER == "" ]]
}

@test "structure: valid commit message with header, multiline body and jira" {
  COMMIT="plop plop

hello

plopplop
plopplop

toto

ABC-1234"

  validate_overall_structure "$COMMIT"
  [[ $GLOBAL_HEADER == "plop plop" ]]
  [[ $GLOBAL_BODY == "hello\nplopplop\nplopplop\ntoto\n" ]]
  [[ $GLOBAL_JIRA == "ABC-1234" ]]
  [[ $GLOBAL_FOOTER == "" ]]
}

@test "structure: valid commit message with header, multiline body and broken" {
  COMMIT="plop plop

hello

plopplop
plopplop

toto

BROKEN:
- plop
- plop"

  validate_overall_structure "$COMMIT"
  [[ $GLOBAL_HEADER == "plop plop" ]]
  [[ $GLOBAL_BODY == "hello\nplopplop\nplopplop\ntoto\n" ]]
  [[ $GLOBAL_JIRA == "" ]]
  [[ $GLOBAL_FOOTER == "- plop\n- plop\n" ]]
}

@test "structure: valid commit message with header, multiline body, jira and broken" {
  COMMIT="plop plop

hello

plopplop
plopplop

toto

ABC-1234
BROKEN:
- plop
- plop"

  validate_overall_structure "$COMMIT"
  [[ $GLOBAL_HEADER == "plop plop" ]]
  [[ $GLOBAL_BODY == "hello\nplopplop\nplopplop\ntoto\n" ]]
  [[ $GLOBAL_JIRA == "ABC-1234" ]]
  [[ $GLOBAL_FOOTER == "- plop\n- plop\n" ]]
}

@test "overall validation invalid structure" {
  MESSAGE='plop
plop'

  run validate "$MESSAGE"
  [[ "$status" -eq $ERROR_STRUCTURE ]]
}

@test "overall validation" {
  MESSAGE='feat(scope1): subject

Commit about stuff\"plop \" dezd

plop

LUM-2345
BROKEN:
- plop
- plop'

  run validate "$MESSAGE"
  [[ "$status" -eq 0 ]]
}
