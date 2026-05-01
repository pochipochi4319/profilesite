#!/bin/zsh
set -u

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
REMOTE="${GIT_AUTOSYNC_REMOTE:-origin}"

cd "$REPO_DIR" || exit 1

LOCK_DIR="$REPO_DIR/.git/auto-sync.lock"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') auto-sync already running"
  exit 0
fi
trap 'rmdir "$LOCK_DIR"' EXIT

if [ -d ".git/rebase-merge" ] || [ -d ".git/rebase-apply" ] || [ -f ".git/MERGE_HEAD" ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') skipped: merge or rebase in progress"
  exit 1
fi

BRANCH="$(git branch --show-current)"
if [ -z "$BRANCH" ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') skipped: detached HEAD"
  exit 1
fi

git add -A

if ! git diff --cached --quiet; then
  git commit -m "Auto sync: $(date '+%Y-%m-%d %H:%M:%S')"
fi

if git ls-remote --exit-code --heads "$REMOTE" "$BRANCH" >/dev/null 2>&1; then
  git fetch "$REMOTE" "$BRANCH"

  REMOTE_REF="$REMOTE/$BRANCH"
  LOCAL_SHA="$(git rev-parse HEAD)"
  REMOTE_SHA="$(git rev-parse "$REMOTE_REF")"
  BASE_SHA="$(git merge-base HEAD "$REMOTE_REF")"

  if [ "$LOCAL_SHA" = "$REMOTE_SHA" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') already synced"
  elif [ "$LOCAL_SHA" = "$BASE_SHA" ]; then
    git merge --ff-only "$REMOTE_REF"
    echo "$(date '+%Y-%m-%d %H:%M:%S') pulled latest changes"
  elif [ "$REMOTE_SHA" = "$BASE_SHA" ]; then
    git push "$REMOTE" "$BRANCH"
    echo "$(date '+%Y-%m-%d %H:%M:%S') pushed local changes"
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') skipped: local and remote histories diverged"
    exit 1
  fi
else
  git push -u "$REMOTE" "$BRANCH"
  echo "$(date '+%Y-%m-%d %H:%M:%S') pushed new branch"
fi
