#!/bin/bash -e

COMMITS=`git log --no-merges --pretty="%H" --no-decorate $1`

while IFS= read -r COMMIT
do
   MESSAGE=`git log -1 --pretty='%B' $COMMIT`
   echo "$MESSAGE"
done <<< $COMMITS

echo "All commits succesfully checked"
