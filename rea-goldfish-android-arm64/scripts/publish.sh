#!/data/data/com.termux/files/usr/bin/env bash
# Publish the merged project to a NEW public GitHub repository.
# Usage: bash scripts/publish.sh <YOUR-GITHUB-USERNAME> [repo-name]
# Requires: gh auth login (or a git credential helper) beforehand.
set -euo pipefail
USERNAME="${1:-}"
REPO="${2:-rea-goldfish-android-arm64}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ -z "$USERNAME" ]; then
  echo "Usage: bash scripts/publish.sh <YOUR-GITHUB-USERNAME> [repo-name]"
  exit 2
fi
cd "$ROOT"

if ! gh auth status >/dev/null 2>&1; then
  echo "GitHub auth missing. Run 'gh auth login' first (or configure a credential helper)."
  exit 2
fi

git branch -M main
if gh repo view "$USERNAME/$REPO" >/dev/null 2>&1; then
  echo "Repository exists — pushing to it."
  git remote remove origin 2>/dev/null || true
  git remote add origin "https://github.com/$USERNAME/$REPO.git"
  git push -u origin main
else
  echo "Creating public repository $USERNAME/$REPO and pushing."
  gh repo create "$USERNAME/$REPO" --public --source=. --remote=origin --push
fi
echo "Published: https://github.com/$USERNAME/$REPO"
