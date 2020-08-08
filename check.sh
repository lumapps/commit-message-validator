#!/bin/bash -e

source ./validator.sh

COMMITS=`git log --no-merges --pretty="%H" --no-decorate $1`

while IFS= read -r COMMIT
do
   MESSAGE=`git log -1 --pretty='%B' $COMMIT`
   echo "checking commit ${COMMIT}..."
   validate "$MESSAGE"
done <<< $COMMITS

echo "All commits succesfully checked"
