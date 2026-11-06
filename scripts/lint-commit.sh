#!/bin/sh
set -eu
if [ "$#" -eq 0 ]; then
  echo "Usage: lint-commit.sh <title> | --file <message-file>" >&2
  exit 2
fi
file=
if [ "$1" = --file ]; then
  file=$2
  msg=$(head -n1 "$file")
  case $msg in
    'Revert "'*|'Merge '*|'fixup!'*|'squash!'*) exit 0 ;;
  esac
else
  msg=$1
fi
case $msg in
  [!a-z]*) echo "Start with a lowercase type: type(scope): summary, for example feat(app): add x." >&2; exit 1 ;;
esac
case $msg in
  [a-z]*'('?*')'*:\ *|[a-z]*'('?*')!'*:\ *) ;;
  *) echo "A scope is required: type(scope): summary." >&2; exit 1 ;;
esac
case $msg in
  *.) echo "Drop the trailing period from the summary." >&2; exit 1 ;;
esac
if [ -n "$file" ]; then
  exec cog verify --file "$file"
fi
exec cog verify "$msg"
