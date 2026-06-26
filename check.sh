#!/usr/bin/env bash

set -eu

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $DIR/validator.sh

NO_MERGES_FLAG="--no-merges"
if [[ -n "${COMMIT_VALIDATOR_NO_MERGE:-}" ]]; then
  NO_MERGES_FLAG=""
fi

git log $NO_MERGES_FLAG --pretty="%H" --no-decorate $1 |
while IFS= read -r COMMIT
do
  MESSAGE=`git log -1 --pretty='%B' $COMMIT`
  echo "checking commit ${COMMIT}..."
  FIRST_WORD=$(echo "${MESSAGE%% *}" | tr '[:upper:]' '[:lower:]')
  if [[ "${FIRST_WORD}" == merge ]]; then
    echo "error: merge commits are not allowed"
    exit 1
  fi
  validate "$MESSAGE"
done

echo "All commits successfully checked"
