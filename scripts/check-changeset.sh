#!/bin/sh
set -eu
base=$1
if [ "${AUTHOR_TYPE:-}" = Bot ]; then
  exit 0
fi
range="origin/$base...HEAD"
if git diff --name-only --diff-filter=A "$range" -- '.changeset/*.md' | grep -q .; then
  exit 0
fi
recorded=$(git diff --name-only --diff-filter=D "$range" -- '.changeset/*.md')
added=$(git diff --numstat "$range" -- '*CHANGELOG.md' | awk '{ n += $1 } END { print n + 0 }')
if [ -n "$recorded" ] && [ "$added" -gt 0 ]; then
  exit 0
fi
echo "Add a changeset file .changeset/<name>.md or record the changelog. See docs/WORKFLOW.md." >&2
exit 1
