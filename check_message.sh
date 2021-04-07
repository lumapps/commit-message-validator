#!/usr/bin/env bash

set -eu

OPTIONS=$(getopt --long no-jira,allow-temp,jira-in-header,header-length:,jira-types: -- "$@")

unset COMMIT_VALIDATOR_ALLOW_TEMP COMMIT_VALIDATOR_NO_JIRA COMMIT_VALIDATOR_NO_REVERT_SHA1 GLOBAL_JIRA_IN_HEADER GLOBAL_MAX_LENGTH GLOBAL_JIRA_TYPES

# this edits the currents args
eval set -- $OPTIONS
while true; do
  case "$1" in
    --no-jira ) COMMIT_VALIDATOR_NO_JIRA=1; shift ;;
    --allow-temp ) COMMIT_VALIDATOR_ALLOW_TEMP=1; shift ;;
    --no-revert-sha1 ) COMMIT_VALIDATOR_NO_REVERT_SHA1=1; shift ;;
    --jira-in-header ) GLOBAL_JIRA_IN_HEADER=1; shift ;;
    --header-length ) GLOBAL_MAX_LENGTH="$2"; shift 2 ;;
    --jira-types ) GLOBAL_JIRA_TYPES="$2"; shift 2 ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
# shellcheck source=validator.sh
source "$DIR/validator.sh"

# usually this is the first arg, now it's forth. See OPTIONS
MESSAGE_FILE=$4
if [[ "$MESSAGE_FILE" == *MERGE_MSG ]]
then
  # ignore merge message (merge with --no-ff without conflict)
  exit
fi

# removing comment lines from message
MESSAGE=$(sed '/^#/d' "$MESSAGE_FILE")

FIRST_WORD=${MESSAGE%% *}
if [[ "${FIRST_WORD,,}" == merge ]]
then
   # ignore merge commits (merge after conflict resolution)
  exit

fi

# print message so you don't lose it in case of errors
# (in case you are not using `-m` option)
echo "Options: "
echo "  JIRA=${COMMIT_VALIDATOR_NO_JIRA:-}"
echo "  TEMP=${COMMIT_VALIDATOR_ALLOW_TEMP:-}"
echo "  NO_REVERT_SHA1=${COMMIT_VALIDATOR_NO_REVERT_SHA1:-}"
printf "checking commit message:\n\n#BEGIN#\n%s\n#END#\n\n" "$MESSAGE"

validate "$MESSAGE"
