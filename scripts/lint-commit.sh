#!/bin/sh
set -eu
if [ "$#" -eq 0 ]; then
  echo "Usage: lint-commit.sh <title> | --file <message-file>" >&2
  exit 2
fi
file=
if [ "$1" = --file ]; then
  file=${2:?usage: lint-commit.sh --file <message-file>}
  msg=$(head -n1 "$file" | tr -d '\r')
  case $msg in
    'Revert "'*|'Merge '*|'fixup!'*|'squash!'*) exit 0 ;;
  esac
else
  msg=$(printf '%s\n' "$1" | head -n1 | tr -d '\r')
fi
case $msg in
  [!a-z]*) echo "Start with a lowercase type: type(scope): summary, for example feat(app): add x." >&2; exit 1 ;;
esac
if ! printf '%s\n' "$msg" | grep -Eq '^[a-z]+\([^()]+\)!?: '; then
  echo "A scope is required: type(scope): summary." >&2
  exit 1
fi
case $msg in
  *.) echo "Drop the trailing period from the summary." >&2; exit 1 ;;
esac
if [ -n "$file" ]; then
  exec cog verify --file "$file"
fi
exec cog verify "$msg"
