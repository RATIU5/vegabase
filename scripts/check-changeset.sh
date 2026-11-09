#!/bin/sh
set -eu
base=${1:?usage: check-changeset.sh <base>}
if [ "${AUTHOR_TYPE:-}" = Bot ]; then
  exit 0
fi
range="origin/$base...HEAD"
if ! git rev-parse --verify -q "origin/$base" > /dev/null; then
  echo "origin/$base not found. Fetch it with full history (fetch-depth: 0)." >&2
  exit 2
fi
if git diff --name-only --diff-filter=A "$range" -- '.changeset/*.md' ':!.changeset/README.md' | grep -q .; then
  exit 0
fi
if git diff "$range" -- '*CHANGELOG.md' | grep -Eq '^\+## [0-9]+\.[0-9]+\.[0-9]+'; then
  if git ls-tree -r --name-only HEAD .changeset/ | grep -v '/README\.md$' | grep -q '\.md$'; then
    echo "CHANGELOG.md has a new version but changesets are still pending. Run mise run changelog." >&2
    exit 1
  fi
  exit 0
fi
echo "Add a changeset file .changeset/<name>.md or record the changelog. See docs/WORKFLOW.md." >&2
exit 1
