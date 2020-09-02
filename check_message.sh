#!/usr/bin/env bash

set -eu

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
# shellcheck source=validator.sh
source "$DIR/validator.sh"


if [[ "$1" == *MERGE_MSG ]]
then
  # ignore merge message (merge with --no-ff without conflict)
  exit
fi

MESSAGE=$(<"$1")

FIRST_WORD=${MESSAGE%% *}
if [[ "${FIRST_WORD,,}" == merge ]]
then
   # ignore merge commits (merge after conflict resolution)
  exit

fi

# print message so you don't lose it in case of errors
# (in case you are not using `-m` option)
printf "checking commit message:\n\n#BEGIN#\n%s\n#END#\n\n" "$(grep -v "#" <<< "$MESSAGE")"

COMMIT_VALIDATOR_ALLOW_TEMP=1 COMMIT_VALIDATOR_NO_JIRA=1 validate "$MESSAGE"
