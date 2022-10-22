if [[ -v ZSH_NAME ]]; then
  setopt BASH_REMATCH
  setopt RE_MATCH_PCRE
  setopt KSH_ARRAYS
fi

readonly HEADER_PATTERN="^([^\(]+)\(([^\)]+)\)!??: (.+)$"
readonly HEADER_BROKEN_PATTERN="^([^\(]+)\(([^\)]+)\)!: (.+)$"
readonly TYPE_PATTERN="^(feat|fix|docs|gen|lint|refactor|test|chore)$"
readonly SCOPE_PATTERN="^([a-z][a-z0-9]*)(-[a-z0-9]+)*$"
readonly SUBJECT_PATTERN="^([a-z0-9].*[^ ^\.])$"
readonly JIRA_PATTERN="^([A-Z]{2,6}[0-9]{0,6}-[0-9]{1,6} ?)+$"
readonly JIRA_HEADER_PATTERN="^.*([A-Z]{3,4}-[0-9]{1,6}).*$"
readonly BROKE_PATTERN="^BROKEN:$"
readonly TRAILING_SPACE_PATTERN=" +$"
readonly REVERT_HEADER_PATTERN="^[R|r]evert[: ].*$"
readonly REVERT_COMMIT_PATTERN="^This reverts commit ([a-f0-9]+)"
readonly TEMP_HEADER_PATTERN="^(fixup!|squash!).*$"

readonly ERROR_STRUCTURE=1
readonly ERROR_HEADER=2
readonly ERROR_HEADER_LENGTH=3
readonly ERROR_TYPE=4
readonly ERROR_SCOPE=5
readonly ERROR_SUBJECT=6
readonly ERROR_BODY_LENGTH=7
readonly ERROR_TRAILING_SPACE=8
readonly ERROR_JIRA=9
readonly ERROR_REVERT=10
readonly ERROR_BROKEN=11

GLOBAL_HEADER=""
GLOBAL_BODY=""
GLOBAL_JIRA=""
GLOBAL_FOOTER=""

# Overridable variables
GLOBAL_JIRA_TYPES="${GLOBAL_JIRA_TYPES:-feat fix}"
GLOBAL_MAX_LENGTH="${GLOBAL_MAX_LENGTH:-100}"
GLOBAL_JIRA_IN_HEADER="${GLOBAL_JIRA_IN_HEADER:-}"

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
      if [[ -n "${GLOBAL_JIRA_IN_HEADER:-}" ]] && [[ $LINE =~ $JIRA_HEADER_PATTERN ]]; then
        GLOBAL_JIRA=${BASH_REMATCH[1]}
      fi

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
        GLOBAL_BODY=$GLOBAL_BODY$LINE$'\n'
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
        GLOBAL_BODY=$GLOBAL_BODY$LINE$'\n'
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

      GLOBAL_FOOTER=$GLOBAL_FOOTER$LINE$'\n'

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

  if [[ ! -z "${COMMIT_VALIDATOR_ALLOW_TEMP:-}" && $HEADER =~ $TEMP_HEADER_PATTERN ]]; then
     GLOBAL_TYPE="temp"
  elif [[ $HEADER =~ $REVERT_HEADER_PATTERN ]]; then
     GLOBAL_TYPE="revert"
  elif [[ $HEADER =~ $HEADER_PATTERN ]]; then
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
  if [[ ${#HEADER} -gt ${GLOBAL_MAX_LENGTH} ]]; then
      echo -e "commit header length is more than ${GLOBAL_MAX_LENGTH} characters"
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
    # Skip lines with no spaces as they can't be split
    $(echo -n "$LINE" | grep -q "\s") || continue

    local LENGTH

    LENGTH="$(echo -n "$LINE" | wc -c)"

    if [[ $LENGTH -gt 100 ]]; then
        echo -e "body message line length is more than 100 charaters"
        exit $ERROR_BODY_LENGTH
    fi
  done <<< "$BODY"
}

validate_trailing_space() {
  local BODY=$1
  local LINE=""

  while IFS= read -r LINE ;
  do
    if [[ $LINE =~ $TRAILING_SPACE_PATTERN ]]; then
        echo -e "body message must not have trailing spaces"
        exit $ERROR_TRAILING_SPACE
    fi
  done <<< "$BODY"
}

need_jira() {
  local TYPE=$1

  if [[ ! -z "${COMMIT_VALIDATOR_NO_JIRA:-}" ]]; then
    return 1
  else
    for type in ${GLOBAL_JIRA_TYPES}; do
        if [[ "${TYPE}" == "${type}" ]]; then
            return 0
        fi
    done
    return 1
  fi
}

validate_jira() {
  local TYPE=$1
  local JIRA=$2



  if need_jira "$TYPE" && [[ -z "${JIRA:-}" ]]; then
     echo -e "commits with type '${TYPE}' need to include a reference to a JIRA ticket, by adding the project prefix and the issue number to the commit message, this could be done easily with: git commit -m 'feat(widget): add a wonderful widget' -m LUM-1234"
     exit $ERROR_JIRA
  fi
}

validate_broken() {
  local HEADER="$1"
  local FOOTER="$2"

  if [[ $HEADER =~ $HEADER_BROKEN_PATTERN && ! $FOOTER =~ $BROKE_PATTERN ]];then
    echo -e "When using type(scope)!: subject,  you must also provide BROKEN: in the footer"
    exit $ERROR_BROKEN
  fi
}

validate_revert() {
  local BODY=$1
  local LINE=""
  local REVERTED_COMMIT=""

  if [[ ! -z "${COMMIT_VALIDATOR_NO_REVERT_SHA1:-}" ]]; then
    exit 0
  fi

  while IFS= read -r LINE ;
  do
    if [[ $LINE =~ $REVERT_COMMIT_PATTERN ]]; then
      REVERTED_COMMIT=${BASH_REMATCH[1]}
    fi
  done <<< "$BODY"

  if [[ "$REVERTED_COMMIT" = "" ]]; then
    echo -e "revert commit should contain the reverted sha1"
    exit $ERROR_REVERT
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

   local TYPE="$GLOBAL_TYPE"
   local SCOPE="$GLOBAL_SCOPE"
   local SUBJECT="$GLOBAL_SUBJECT"

   if [[ $TYPE = "temp" ]]; then
     echo "ignoring temporary commit"
   elif [[ $TYPE = "revert" ]]; then
     validate_revert "$BODY"
   else
     validate_header_length "$HEADER"

     validate_type "$TYPE"
     validate_scope "$SCOPE"
     validate_subject "$SUBJECT"

     validate_body_length "$BODY"
     validate_body_length "$FOOTER"

     validate_trailing_space "$BODY"
     validate_trailing_space "$FOOTER"

     validate_jira "$TYPE" "$JIRA"
     validate_broken "$HEADER" "$FOOTER"
   fi
}
