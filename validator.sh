#!/bin/bash -e

readonly HEADER_PATTERN="^([^\(]+)\(([^\)]+)\): (.+)$"
readonly TYPE_PATTERN="^(feat|fix|docs|refactor|test|chore|revert)$"
readonly SCOPE_PATTERN="^([a-z][a-z0-9]*)(-[a-z0-9]+)*$"
readonly SUBJECT_PATTERN="^([a-z0-9].*[^ ^\.])$"
readonly JIRA_PATTERN="^([A-Z]{2,4}-[0-9]{1,6} ?)+$"
readonly BROKE_PATTERN="^BROKEN:$"

readonly ERROR_STRUCTURE=1
readonly ERROR_HEADER=2
readonly ERROR_HEADER_LENGTH=3
readonly ERROR_TYPE=4
readonly ERROR_SCOPE=5
readonly ERROR_SUBJECT=6
readonly ERROR_BODY_LENGTH=7
readonly ERROR_JIRA=8

GLOBAL_HEADER=""
GLOBAL_BODY=""
GLOBAL_JIRA=""
GLOBAL_FOOTER=""

GLOBAL_TYPE=""
GLOBAL_SCOPE=""
GLOBAL_SUBJECT=""

validate_overall_structure() {
  local MESSAGE="$1"

  local WAITING_HEADER=0
  local WAITING_EMPTY=1
  local START_TEXT=2
  local READING_BODY=3
  local READING_BROKEN=4
  local READING_FOOTER=5

  local STATE="$WAITING_HEADER"

  while IFS= read -r LINE ; do

    if [[ $STATE -eq $WAITING_HEADER ]]; then
      GLOBAL_HEADER="$LINE"
      STATE="$WAITING_EMPTY"

    elif [[ $STATE -eq $WAITING_EMPTY ]]; then
      if [[ $LINE != "" ]]; then
	echo -e "missing empty line in commit message between header and body or body and footer"
        exit $ERROR_STRUCTURE
      fi
      STATE="$START_TEXT"

    elif [[ $STATE -eq $START_TEXT ]]; then
      if [[ $LINE = "" ]]; then
	echo -e "double empty line is not allowed"
        exit $ERROR_STRUCTURE
      fi

      if [[ $LINE =~ $BROKE_PATTERN ]]; then
	STATE="$READING_FOOTER"
      elif [[ $LINE =~ $JIRA_PATTERN ]]; then
	STATE="$READING_BROKEN"
	GLOBAL_JIRA=${BASH_REMATCH[0]}
      else
	STATE="$READING_BODY"
	GLOBAL_BODY="${GLOBAL_BODY}${LINE}\n"
      fi

    elif [[ $STATE -eq $READING_BODY ]]; then
      if [[ $LINE =~ $BROKE_PATTERN ]]; then
	echo -e "missing empty line before broke part"
        exit $ERROR_STRUCTURE
      fi

      if [[ $LINE =~ $JIRA_PATTERN ]]; then
	echo -e "missing empty line before JIRA reference"
        exit $ERROR_STRUCTURE
      fi

      if [[ $LINE = "" ]]; then
	STATE=$START_TEXT
      else
	GLOBAL_BODY="${GLOBAL_BODY}${LINE}\n"
      fi

    elif [[ $STATE -eq $READING_BROKEN ]]; then
      if [[ $LINE =~ $BROKE_PATTERN ]]; then
	STATE="$READING_FOOTER"
      else
	echo -e "only broken part could be after the JIRA reference"
        exit $ERROR_STRUCTURE
      fi

    elif [[ $STATE -eq $READING_FOOTER ]]; then
      if [[ $LINE = "" ]]; then
	echo -e "no empty line allowed in broken part"
        exit $ERROR_STRUCTURE
      fi

      GLOBAL_FOOTER="${GLOBAL_FOOTER}${LINE}\n"

    else
      echo -e "unknown state in parsing machine"
      exit $ERROR_STRUCTURE
    fi

  done <<< "$MESSAGE"

  if [[ $STATE -eq $START_TEXT ]]; then
    echo -e "new line at the end of the commit is not allowed"
    exit $ERROR_STRUCTURE
  fi
}

validate_header() {
  local HEADER="$1"

  if [[ $HEADER =~ $HEADER_PATTERN ]]; then
     GLOBAL_TYPE=${BASH_REMATCH[1]}
     GLOBAL_SCOPE=${BASH_REMATCH[2]}
     GLOBAL_SUBJECT=${BASH_REMATCH[3]}
  else
     echo -e "commit header doesn't match overall header pattern: 'type(scope): message'"
     exit $ERROR_HEADER
  fi
}

validate_header_length() {
  local HEADER="$1"
  local LENGTH=`echo -n "$HEADER" | wc -c`

  if [ $LENGTH -gt 70 ]; then
      echo -e "commit header length is more than 70 charaters"
      exit $ERROR_HEADER_LENGTH
  fi
}

validate_type() {
  local TYPE=$1

  if [[ ! $TYPE =~ $TYPE_PATTERN ]]; then
     echo -e "commit type '$TYPE' is unknown"
     exit $ERROR_TYPE
  fi
}

validate_scope() {
  local SCOPE=$1

  if [[ ! $SCOPE =~ $SCOPE_PATTERN ]]; then
     echo -e "commit scope '$SCOPE' is not kebab-case"
     exit $ERROR_SCOPE
  fi
}

validate_subject() {
  local SUBJECT=$1

  if [[ ! $SUBJECT =~ $SUBJECT_PATTERN ]]; then
     echo -e "commit subject '$SUBJECT' should start with a lower case and not end with a '.'"
     exit $ERROR_SUBJECT
  fi
}

validate_body_length() {
  local BODY=$1
  local LINE=""

  while IFS= read -r LINE ;
  do
    local LENGTH=`echo -n "$LINE" | wc -c`

    if [ $LENGTH -gt 100 ]; then
        echo -e "body message line length is more than 100 charaters"
        exit $ERROR_BODY_LENGTH
    fi
  done <<< "$BODY"
}

need_jira() {
  local TYPE=$1

  case $TYPE in
    feat)
      echo 1
      ;;
    fix)
      echo 1
      ;;
    *)
      echo 0
  esac
}

validate_jira() {
  local TYPE=$1
  local JIRA=$2

  if [[ `need_jira "$TYPE"` -eq 1 && $JIRA = "" ]]; then
     echo -e "${TYPE} need a jira reference"
     exit $ERROR_JIRA
  fi
}

validate() {
   local COMMIT_MSG="$1"

   validate_overall_structure "$COMMIT_MSG"

   local HEADER="$GLOBAL_HEADER"
   local BODY="$GLOBAL_BODY"
   local JIRA="$GLOBAL_JIRA"
   local FOOTER="$GLOBAL_FOOTER"

   validate_header "$HEADER"
   validate_header_length "$HEADER"

   local TYPE="$GLOBAL_TYPE"
   local SCOPE="$GLOBAL_SCOPE"
   local SUBJECT="$GLOBAL_SUBJECT"

   validate_type "$TYPE"
   validate_scope "$SCOPE"
   validate_subject "$SUBJECT"

   validate_body_length "$BODY"

   validate_jira "$TYPE" "$JIRA"
}
