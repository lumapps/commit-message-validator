#!/usr/bin/env bash

set -eu

if [[ -v ZSH_NAME ]]; then
  setopt BASH_REMATCH
  setopt RE_MATCH_PCRE
  setopt KSH_ARRAYS
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $DIR/validator.sh

MESSAGE=$(<"$1")
echo "checking commit message: '${MESSAGE}'"
validate "$MESSAGE"

echo "Message succesfully checked"
