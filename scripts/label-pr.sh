#!/bin/sh
set -eu
type=$(printf '%s' "$TITLE" | sed -nE 's/^([a-z]+)(\([^)]*\))?!?: .*/\1/p')
if [ -z "$type" ]; then
  exit 0
fi
gh label create "$type" --force > /dev/null
for old in $(gh pr view "$PR" --json labels --jq '.labels[].name'); do
  case $old in
    feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)
      if [ "$old" != "$type" ]; then
        gh pr edit "$PR" --remove-label "$old"
      fi ;;
  esac
done
gh pr edit "$PR" --add-label "$type"
