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

# Directories you always want removed
ALWAYS_REMOVE=("cs" "dist" "examples" "go" "js" "php" "ts")

echo "=== Fetching upstream ==="
git fetch upstream

echo "=== Updating local master ==="
git checkout master
git pull upstream master

echo "=== Checking out $PATCH_BRANCH ==="
git checkout "$PATCH_BRANCH"

echo "=== Rebasing onto $BASE_COMMIT ==="
GIT_SEQUENCE_EDITOR=: \
git rebase --strategy-option=theirs "$BASE_COMMIT" || {
    echo "⚠️ Rebase had conflicts, attempting auto-resolve..."

    # Delete everything inside the ALWAYS_REMOVE directories to avoid modify/delete conflicts
    for dir in "${ALWAYS_REMOVE[@]}"; do
        if [ -d "$dir" ]; then
            echo "Deleting all contents of $dir to resolve conflicts"
            git rm -r "$dir"/*
        fi
    done

    git rebase --continue || {
        echo "❌ Rebase still failed. Manual intervention needed."
        exit 1
    }
}

# Post-rebase cleanup: remove any leftover ALWAYS_REMOVE directories
for dir in "${ALWAYS_REMOVE[@]}"; do
    if [ -d "$dir" ]; then
        echo "Removing leftover unwanted directory: $dir"
        git rm -r "$dir"
    fi
done

# Commit deletions if there are staged changes
if ! git diff --cached --quiet; then
    git commit -m "Ensure unwanted directories removed after rebase onto $BASE_COMMIT"
fi

# Optional: update pyproject.toml
TOML_FILE="python/pyproject.toml"

if [ -f "$TOML_FILE" ]; then
    echo "=== Opening $TOML_FILE for manual edit ==="
    ${EDITOR:-vim} "$TOML_FILE"

    if ! git diff --quiet "$TOML_FILE"; then
        echo "Changes detected in $TOML_FILE. Committing..."
        git add "$TOML_FILE"
        git commit -m "Update pyproject.toml after rebase onto $BASE_COMMIT"
    else
        echo "No changes in $TOML_FILE, skipping commit."
    fi
else
    echo "⚠️ $TOML_FILE not found, skipping."
fi

echo "✅ Rebase complete"
echo "Force pushing into remote"

git push origin $PATCH_BRANCH --force

echo "✅ Done."

