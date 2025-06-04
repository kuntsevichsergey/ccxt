#!/usr/bin/env bash
set -euo pipefail

# usage: ./rebase-patch.sh <commit-sha>
BASE_COMMIT=${1:-}

if [ -z "$BASE_COMMIT" ]; then
    echo "❌ Error: You must provide a base commit SHA."
    echo "Usage: $0 <commit-sha>"
    exit 1
fi

PATCH_BRANCH="slim-patched-python"

echo "=== Fetching upstream ==="
git fetch upstream

echo "=== Updating local main ==="
git checkout master
git pull upstream master

echo "=== Checking out $PATCH_BRANCH ==="
git checkout "$PATCH_BRANCH"

echo "=== Rebasing onto $BASE_COMMIT ==="
# Automate conflict resolution: prefer 'theirs' changes during rebase
GIT_SEQUENCE_EDITOR=: \
git rebase --strategy-option=theirs "$BASE_COMMIT" || {
    echo "⚠️ Rebase had conflicts, attempting auto-resolve..."
    git add -A
    git rebase --continue || {
        echo "❌ Rebase still failed. Manual intervention needed."
        exit 1
    }
}

echo "✅ Rebase complete. Don't forget to force push:"
echo "    git push origin $PATCH_BRANCH --force"

