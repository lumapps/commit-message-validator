#!/bin/bash -e

readonly JIRA_PATTERN="^([A-Z]{2,4}-[0-9]{1,6} ?)+$"
readonly BROKE_PATTERN="^BROKEN:$"

readonly ERROR_STRUCTURE=1

GLOBAL_HEADER=""
GLOBAL_BODY=""
GLOBAL_JIRA=""
GLOBAL_FOOTER=""

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

validate() {
   local COMMIT_MSG="$1"

   validate_overall_structure "$COMMIT_MSG"

   local HEADER="$GLOBAL_HEADER"
   local BODY="$GLOBAL_BODY"
   local JIRA="$GLOBAL_JIRA"
   local FOOTER="$GLOBAL_FOOTER"
}
