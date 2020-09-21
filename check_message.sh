#!/usr/bin/env bash

set -eu

OPTIONS=$(getopt --long no-jira allow-temp -- "$@")
[ $? -eq 0 ] || {
    echo "Incorrect options provided"
    exit 1
}

COMMIT_VALIDATOR_ALLOW_TEMP=
COMMIT_VALIDATOR_NO_JIRA=

while true; do
  case "$1" in
    --no-jira ) COMMIT_VALIDATOR_NO_JIRA=1; shift ;;
    --allow-temp ) COMMIT_VALIDATOR_ALLOW_TEMP=1; shift ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
# shellcheck source=validator.sh
source "$DIR/validator.sh"


if [[ "$1" == *MERGE_MSG ]]
then
  # ignore merge message (merge with --no-ff without conflict)
  exit
fi

# removing comment lines from message
MESSAGE=$(sed '/^#/d' "$1")

FIRST_WORD=${MESSAGE%% *}
if [[ "${FIRST_WORD,,}" == merge ]]
then
   # ignore merge commits (merge after conflict resolution)
  exit

fi

# print message so you don't lose it in case of errors
# (in case you are not using `-m` option)
echo "Options: JIRA=$COMMIT_VALIDATOR_NO_JIRA, TEMP=$COMMIT_VALIDATOR_ALLOW_TEMP"
printf "checking commit message:\n\n#BEGIN#\n%s\n#END#\n\n" "$MESSAGE"

validate "$MESSAGE"
