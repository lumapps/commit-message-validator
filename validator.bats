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
  [[ $GLOBAL_FOOTER == "- plop"$'\n'"- plop"$'\n' ]]
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
  [[ $GLOBAL_FOOTER == "- plop"$'\n'"- plop"$'\n' ]]
}

@test "structure: valid commit message with header and body" {
  COMMIT="plop plop

hello"

  validate_overall_structure "$COMMIT"
  [[ $GLOBAL_HEADER == "plop plop" ]]
  [[ $GLOBAL_BODY == "hello"$'\n' ]]
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
  [[ $GLOBAL_BODY == "hello"$'\n'"plopplop"$'\n'"plopplop"$'\n'"toto"$'\n' ]]
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
  [[ $GLOBAL_BODY == "hello"$'\n'"plopplop"$'\n'"plopplop"$'\n'"toto"$'\n' ]]
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
  [[ $GLOBAL_BODY == "hello"$'\n'"plopplop"$'\n'"plopplop"$'\n'"toto"$'\n' ]]
  [[ $GLOBAL_JIRA == "" ]]
  [[ $GLOBAL_FOOTER == "- plop"$'\n'"- plop"$'\n' ]]
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
  [[ $GLOBAL_BODY == "hello"$'\n'"plopplop"$'\n'"plopplop"$'\n'"toto"$'\n' ]]
  [[ $GLOBAL_JIRA == "ABC-1234" ]]
  [[ $GLOBAL_FOOTER == "- plop"$'\n'"- plop"$'\n' ]]
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

@test "header overall should allow 'revert: type(scope): message'" {
  validate_header "revert: type(scope): message"
  [[ $GLOBAL_TYPE == "revert" ]]
}

@test "header overall should allow 'Revert \#type(scope): message\"'" {
  validate_header "Revert \"type(scope): message\""
  [[ $GLOBAL_TYPE == "revert" ]]
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

@test "unknown commit type 'plop' should be rejected" {
  run validate_type "plop"
  [ "$status" -eq $ERROR_TYPE ]
}

@test "known commit type with trailing space should be rejected" {
  run validate_type "feat "
  [ "$status" -eq $ERROR_TYPE ]
}

@test "known commit type with capitalized letter should be rejected" {
  run validate_type "Feat"
  [ "$status" -eq $ERROR_TYPE ]
}

@test "commit type 'feat' should be ok" {
  run validate_type "feat"
  [ "$status" -eq 0 ]
}

@test "scope cannot be empty" {
  run validate_scope ""
  [ "$status" -eq $ERROR_SCOPE ]
}

@test "scope cannot be capitalized" {
  run validate_scope "plopPlop"
  [ "$status" -eq $ERROR_SCOPE ]
}

@test "scope cannot have space" {
  run validate_scope "plop plop"
  [ "$status" -eq $ERROR_SCOPE ]
}

@test "scope cannot have trailing space" {
  run validate_scope "plop "
  [ "$status" -eq $ERROR_SCOPE ]
}

@test "scope should allow simple kebab-case" {
  run validate_scope "p2"
  [ "$status" -eq 0 ]
}

@test "scope should allow kebab-case" {
  run validate_scope "pl2op-plop1-plop-0001"
  [ "$status" -eq 0 ]
}

@test "subject cannot be empty" {
  run validate_subject ""
  [ "$status" -eq $ERROR_SUBJECT ]
}

@test "subject cannot have trailing space" {
  run validate_subject "plop "
  [ "$status" -eq $ERROR_SUBJECT ]
}

@test "subject cannot start with a capitalized letter" {
  run validate_subject "Plop"
  [ "$status" -eq $ERROR_SUBJECT ]
}

@test "subject cannot end with a point" {
  run validate_subject "plop."
  [ "$status" -eq $ERROR_SUBJECT ]
}

@test "subject should allow sentences" {
  run validate_subject "0002 dedezf ef zefzef zfeze fzef zf zef"
  [ "$status" -eq 0 ]
}

@test "body with 101 line length should be rejected" {
  MESSAGE='
12345678 012345678 012345678 012345678 012345678 012345678 012345678 012345678 012345678 012345678 01

LUM-2345'

  run validate_body_length "$MESSAGE"
  [[ "$status" -eq $ERROR_BODY_LENGTH ]]
}

@test "body with 100 line length should be valid" {
  MESSAGE='
1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890
12345678 012345678 012345678 012345678 012345678 012345678 012345678 012345678 012345678 012345678 0

1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890

LUM-2345'

  run validate_body_length "$MESSAGE"
  [[ "$status" -eq 0 ]]
}

@test "body with trailing space on line should not be valid" {
  MESSAGE='pdzofjzf '

  run validate_trailing_space "$MESSAGE"
  [[ "$status" -eq $ERROR_TRAILING_SPACE ]]
}

@test "body with trailing space on new line should not be valid" {
  MESSAGE='
rerer

  
LUM-2345'

  run validate_trailing_space "$MESSAGE"
  [[ "$status" -eq $ERROR_TRAILING_SPACE ]]
}

@test "body without trailing space should be valid" {
  MESSAGE='
rerer


LUM-2345'

  run validate_trailing_space "$MESSAGE"
  [[ "$status" -eq 0 ]]
}

@test "revert body without commit sha1 should be refused" {
  MESSAGE='rerer

LUM-2345'

  run validate_revert "$MESSAGE"
  [[ "$status" -eq $ERROR_REVERT ]]
}

@test "revert body with commit sha1 should be valid" {
  MESSAGE='rerer

This reverts commit 1234567890.

LUM-2345'

  run validate_revert "$MESSAGE"
  [[ "$status" -eq 0 ]]
}

@test "features and fixes commits need jira reference" {
  [[ `need_jira "feat"` -eq 1 ]]
  [[ `need_jira "fix"` -eq 1 ]]
}

@test "other commits don't need jira reference" {
  [[ `need_jira "docs"` -eq 0 ]]
  [[ `need_jira "test"` -eq 0 ]]
}

@test "feat without jira ref should be rejected" {
  run validate_jira "feat" ""
  [[ "$status" -eq $ERROR_JIRA ]]
}

@test "lint without jira ref should be validated" {
  run validate_jira "lint" ""
  [[ "$status" -eq 0 ]]
}

@test "feat with jira ref should be validated" {
  run validate_jira "feat" "ABC-123"
  [[ "$status" -eq 0 ]]
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

@test "overall validation invalid type" {
  MESSAGE='Feat(scope1): subject

Commit about stuff\"plop \"

LUM-2345'

  run validate "$MESSAGE"
  [[ "$status" -eq $ERROR_TYPE ]]
}

@test "overall validation invalid scope" {
  MESSAGE='feat(scope 1): subject

Commit about stuff\"plop \"

LUM-2345'

  run validate "$MESSAGE"
  [[ "$status" -eq $ERROR_SCOPE ]]
}

@test "overall validation invalid subject" {
  MESSAGE='feat(scope1): Subject

Commit about stuff\"plop \"

LUM-2345'

  run validate "$MESSAGE"
  [[ "$status" -eq $ERROR_SUBJECT ]]
}

@test "overall validation invalid body length" {
  MESSAGE='feat(scope1): subject

12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901

LUM-2345'

  run validate "$MESSAGE"
  [[ "$status" -eq $ERROR_BODY_LENGTH ]]
}

@test "overall validation invalid body trailing space" {
  MESSAGE='chore(scope1): subject

123456789012345678901234567890123456789012 '

  run validate "$MESSAGE"
  [[ "$status" -eq $ERROR_TRAILING_SPACE ]]
}

@test "overall validation invalid footer length" {
  MESSAGE='feat(scope1): subject

plop

LUM-2345
BROKEN:
- 12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901'

  run validate "$MESSAGE"
  [[ "$status" -eq $ERROR_BODY_LENGTH ]]
}

@test "overall validation invalid footer trailing space" {
  MESSAGE='feat(scope1): subject

plop

LUM-2345
BROKEN:
- 123456 '

  run validate "$MESSAGE"
  [[ "$status" -eq $ERROR_TRAILING_SPACE ]]
}

@test "overall validation missing jira" {
  MESSAGE='feat(scope1): subject

Commit about stuff\"plop \"

2345'

  run validate "$MESSAGE"
  [[ "$status" -eq $ERROR_JIRA ]]
}

@test "overall validation" {
  MESSAGE='feat(scope1): subject

Commit about stuff\"plop \" dezd

12345678901234567890123456789012345678901234567890
12345678901234567890123456789012345678901234567890

LUM-2345
BROKEN:
- plop
- plop'

  run validate "$MESSAGE"
  [[ "$status" -eq 0 ]]
}

@test "overall revert validation" {
  MESSAGE='Revert "feat(scope1): subject"

This reverts commit 12345678900.
Commit about stuff\"plop \" dezd

12345678901234567890123456789012345678901234567890
12345678901234567890123456789012345678901234567890

LUM-2345
BROKEN:
- plop
- plop'

  run validate "$MESSAGE"
  [[ "$status" -eq 0 ]]
}
