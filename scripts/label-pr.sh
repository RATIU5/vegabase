#!/bin/sh
set -eu
type=$(printf '%s' "$TITLE" | sed -nE 's/^([a-z]+)(\([^)]*\))?!?: .*/\1/p')
case $type in
  feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert) ;;
  *) exit 0 ;;
esac
gh label create "$type" > /dev/null 2>&1 || true
for old in $(gh pr view "$PR" --json labels --jq '.labels[].name'); do
  case $old in
    feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)
      if [ "$old" != "$type" ]; then
        gh pr edit "$PR" --remove-label "$old"
      fi ;;
  esac
done
gh pr edit "$PR" --add-label "$type"
