#!/bin/bash -e

if [[ $ZSH_NAME != "" ]]; then
  setopt BASH_REMATCH
  setopt RE_MATCH_PCRE
  setopt KSH_ARRAYS
fi

source ./validator.sh

COMMITS=`git log --no-merges --pretty="%H" --no-decorate $1`

while IFS= read -r COMMIT
do
   MESSAGE=`git log -1 --pretty='%B' $COMMIT`
   echo "checking commit ${COMMIT}..."
   validate "$MESSAGE"
done <<< $COMMITS

echo "All commits succesfully checked"
