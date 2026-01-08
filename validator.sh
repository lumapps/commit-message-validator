if [[ -v ZSH_NAME ]]; then
  setopt BASH_REMATCH
  setopt RE_MATCH_PCRE
  setopt KSH_ARRAYS
fi

readonly HEADER_PATTERN="^([^\(]+)\(([^\)]+)\): (.+)$"
readonly TYPE_PATTERN="^(feat|fix|docs|gen|lint|refactor|test|chore)$"
readonly SCOPE_PATTERN="^([a-z][a-z0-9]*)(-[a-z0-9]+)*$"
readonly SUBJECT_PATTERN="^([A-Za-z0-9].*[^ ^\.])$"
readonly JIRA_PATTERN="[A-Z]{2,7}[0-9]{0,6}-[0-9]{1,6}"
readonly JIRA_FOOTER_PATTERN="^(${JIRA_PATTERN} ?)+$"
readonly JIRA_HEADER_PATTERN="^.*[^A-Z](${JIRA_PATTERN}).*$"
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

GLOBAL_HEADER=""
GLOBAL_BODY=""
GLOBAL_JIRA=""
GLOBAL_FOOTER=""

# Overridable variables
GLOBAL_JIRA_TYPES="${GLOBAL_JIRA_TYPES:-feat fix}"
GLOBAL_MAX_LENGTH="${GLOBAL_MAX_LENGTH:-100}"
GLOBAL_BODY_MAX_LENGTH="${GLOBAL_BODY_MAX_LENGTH:-100}"
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
  local LINE_NUM=0

  while IFS= read -r LINE ; do
    LINE_NUM=$((LINE_NUM + 1))

    if [[ $STATE -eq $WAITING_HEADER ]]; then
      GLOBAL_HEADER="$LINE"
      STATE="$WAITING_EMPTY"
      if [[ -n "${GLOBAL_JIRA_IN_HEADER:-}" ]] && [[ $LINE =~ $JIRA_HEADER_PATTERN ]]; then
        GLOBAL_JIRA=${BASH_REMATCH[1]}
      fi

    elif [[ $STATE -eq $WAITING_EMPTY ]]; then
      if [[ $LINE != "" ]]; then
        echo -e "ERROR: Missing empty line at line ${LINE_NUM}"
        echo -e "Expected: blank line between header and body (or body and footer)"
        echo -e "Found: '${LINE}'"
        exit $ERROR_STRUCTURE
      fi
      STATE="$START_TEXT"

    elif [[ $STATE -eq $START_TEXT ]]; then
      if [[ $LINE = "" ]]; then
        echo -e "ERROR: Double empty line found at line ${LINE_NUM}"
        echo -e "Only one blank line is allowed between sections"
        exit $ERROR_STRUCTURE
      fi

      if [[ $LINE =~ $BROKE_PATTERN ]]; then
        STATE="$READING_FOOTER"
      elif [[ $LINE =~ $JIRA_FOOTER_PATTERN ]]; then
        STATE="$READING_BROKEN"
        GLOBAL_JIRA=${BASH_REMATCH[0]}
      else
        STATE="$READING_BODY"
        GLOBAL_BODY=$GLOBAL_BODY$LINE$'\n'
      fi

    elif [[ $STATE -eq $READING_BODY ]]; then
      if [[ $LINE =~ $BROKE_PATTERN ]]; then
        echo -e "ERROR: Missing empty line before BROKEN section at line ${LINE_NUM}"
        echo -e "Add a blank line before 'BROKEN:'"
        exit $ERROR_STRUCTURE
      fi

      if [[ $LINE =~ $JIRA_FOOTER_PATTERN ]]; then
        echo -e "ERROR: Missing empty line before JIRA reference at line ${LINE_NUM}"
        echo -e "JIRA reference found: '${LINE}'"
        echo -e "Add a blank line before the JIRA reference"
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
        echo -e "ERROR: Invalid content after JIRA reference at line ${LINE_NUM}"
        echo -e "Found: '${LINE}'"
        echo -e "Only 'BROKEN:' section is allowed after JIRA reference"
        exit $ERROR_STRUCTURE
      fi

    elif [[ $STATE -eq $READING_FOOTER ]]; then
      if [[ $LINE = "" ]]; then
        echo -e "ERROR: Empty line found in BROKEN section at line ${LINE_NUM}"
        echo -e "No empty lines are allowed within the BROKEN section"
        exit $ERROR_STRUCTURE
      fi

      GLOBAL_FOOTER=$GLOBAL_FOOTER$LINE$'\n'

    else
      echo -e "ERROR: Unknown state in parsing machine"
      exit $ERROR_STRUCTURE
    fi

  done <<< "$MESSAGE"

  if [[ $STATE -eq $START_TEXT ]]; then
    echo -e "ERROR: Trailing newline at end of commit message"
    echo -e "Remove the extra blank line at the end"
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
     echo -e "ERROR: Invalid commit header format"
     echo -e "Header: '${HEADER}'"
     echo -e "Expected format: type(scope): subject"
     echo -e "Example: feat(user-auth): add login functionality"
     exit $ERROR_HEADER
  fi
}

validate_header_length() {
  local HEADER="$1"
  if [[ ${#HEADER} -gt ${GLOBAL_MAX_LENGTH} ]]; then
      echo -e "ERROR: Commit header is too long"
      echo -e "Header: '${HEADER}'"
      echo -e "Length: ${#HEADER} characters (max: ${GLOBAL_MAX_LENGTH})"
      echo -e "Shorten the header by $((${#HEADER} - ${GLOBAL_MAX_LENGTH})) characters"
      exit $ERROR_HEADER_LENGTH
  fi
}

validate_type() {
  local TYPE=$1

  if [[ ! $TYPE =~ $TYPE_PATTERN ]]; then
     echo -e "ERROR: Invalid commit type"
     echo -e "Type: '${TYPE}'"
     echo -e "Allowed types: feat, fix, docs, gen, lint, refactor, test, chore"
     exit $ERROR_TYPE
  fi
}

validate_scope() {
  local SCOPE=$1

  if [[ ! $SCOPE =~ $SCOPE_PATTERN ]]; then
     echo -e "ERROR: Invalid scope format"
     echo -e "Scope: '${SCOPE}'"
     echo -e "Scope must be in kebab-case (lowercase, hyphens only)"
     echo -e "Examples: user-auth, api-service, data-layer"
     exit $ERROR_SCOPE
  fi
}

validate_subject() {
  local SUBJECT=$1

  if [[ ! $SUBJECT =~ $SUBJECT_PATTERN ]]; then
     echo -e "ERROR: Invalid subject format"
     echo -e "Subject: '${SUBJECT}'"
     echo -e "Subject must not:"
     echo -e "  - End with a period (.)"
     echo -e "  - End with a space"
     echo -e "  - Start with a capital letter (use imperative mood)"
     exit $ERROR_SUBJECT
  fi
}

validate_body_length() {
  local BODY=$1
  local LINE=""
  local LINE_NUM=0

  while IFS= read -r LINE ;
  do
    LINE_NUM=$((LINE_NUM + 1))
    # Skip lines with no spaces as they can't be split
    $(echo -n "$LINE" | grep -q "\s") || continue

    local LENGTH

    LENGTH="$(echo -n "$LINE" | wc -c)"

    if [[ $LENGTH -gt ${GLOBAL_BODY_MAX_LENGTH} ]]; then
        echo -e "ERROR: Line too long in body"
        echo -e "Line ${LINE_NUM}: '${LINE}'"
        echo -e "Length: ${LENGTH} characters (max: ${GLOBAL_BODY_MAX_LENGTH})"
        echo -e "Split this line into multiple lines"
        exit $ERROR_BODY_LENGTH
    fi
  done <<< "$BODY"
}

validate_trailing_space() {
  local BODY=$1
  local LINE=""
  local LINE_NUM=0

  while IFS= read -r LINE ;
  do
    LINE_NUM=$((LINE_NUM + 1))
    if [[ $LINE =~ $TRAILING_SPACE_PATTERN ]]; then
        echo -e "ERROR: Trailing space found"
        echo -e "Line ${LINE_NUM}: '${LINE}'"
        echo -e "Remove trailing spaces from this line"
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
     echo -e "ERROR: Missing JIRA reference"
     echo -e "Commit type '${TYPE}' requires a JIRA ticket reference"
     echo -e ""
     echo -e "Add the JIRA reference as a separate line in the footer:"
     echo -e "  git commit -m 'feat(widget): add wonderful widget' -m 'PROJ-1234'"
     echo -e ""
     echo -e "Or include it in your commit message:"
     echo -e "  feat(widget): add wonderful widget"
     echo -e "  "
     echo -e "  Description of the change."
     echo -e "  "
     echo -e "  PROJ-1234"
     exit $ERROR_JIRA
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
    echo -e "ERROR: Missing reverted commit SHA"
    echo -e "Revert commits must contain the reverted commit SHA"
    echo -e "Expected format: 'This reverts commit <sha1>'"
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
   fi
}