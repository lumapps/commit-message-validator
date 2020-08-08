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

@test "header overall should not allow 'type'" {
  run validate_header "type"
  [ "$status" -eq $ERROR_HEADER ]
}

@test "header overall should not allow 'type(scope)'" {
  run validate_header "type(scope)"
  [ "$status" -eq $ERROR_HEADER ]
}

@test "header overall should not allow 'type(scope) message'" {
  run validate_header "type(scope) message"
  [ "$status" -eq $ERROR_HEADER ]
}

@test "header overall should not allow 'type(scope) : message'" {
  run validate_header "type(scope) : message"
  [ "$status" -eq $ERROR_HEADER ]
}

@test "header overall should not allow 'type(scope: message'" {
  run validate_header "type(scope: message"
  [ "$status" -eq $ERROR_HEADER ]
}

@test "header overall should not allow 'type scope: message'" {
  run validate_header "type scope: message"
  [ "$status" -eq $ERROR_HEADER ]
}

@test "header overall should not allow 'type(scope):message'" {
  run validate_header "type(scope):message"
  [ "$status" -eq $ERROR_HEADER ]
}

@test "header overall should allow 'type(scope): message'" {
  validate_header "type(scope): message"
  [[ $GLOBAL_TYPE == "type" ]]
  [[ $GLOBAL_SCOPE == "scope" ]]
  [[ $GLOBAL_SUBJECT == "message" ]]
}

@test "header overall should allow 'type 1(scope 2): message 3'" {
  validate_header "type 1(scope 2): message 3"
  [[ $GLOBAL_TYPE == "type 1" ]]
  [[ $GLOBAL_SCOPE == "scope 2" ]]
  [[ $GLOBAL_SUBJECT == "message 3" ]]
}

@test "header length cannot be more than 70" {
  run validate_header_length "01234567890123456789012345678901234567890123456789012345678901234567891"
  [ "$status" -eq $ERROR_HEADER_LENGTH ]
}

@test "header length cannot be more than 70 with spaces" {
  run validate_header_length "012345678 012345678 012345678 012345678 012345678 012345678 012345678 1"
  [ "$status" -eq $ERROR_HEADER_LENGTH ]
}

@test "header length can be 70" {
  run validate_header_length "0123456789012345678901234567890123456789012345678901234567890123456789"
  [ "$status" -eq 0 ]
}

@test "header length can be 70 with spaces" {
  run validate_header_length "012345678 012345678 012345678 012345678 012345678 012345678 012345678 "
  [ "$status" -eq 0 ]
}

@test "overall validation invalid structure" {
  MESSAGE='plop
plop'

  run validate "$MESSAGE"
  [[ "$status" -eq $ERROR_STRUCTURE ]]
}

@test "overall validation invalid header" {
  MESSAGE='plop'

  run validate "$MESSAGE"
  [[ "$status" -eq $ERROR_HEADER ]]
}

@test "overall validation invalid header length" {
  MESSAGE='feat(plop): 01234567890123456789012345678901234567890123456789012345678901234567890'

  run validate "$MESSAGE"
  [[ "$status" -eq $ERROR_HEADER_LENGTH ]]
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
