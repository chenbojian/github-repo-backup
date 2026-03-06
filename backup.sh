#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <repo-url> [branch]"
  echo "  repo-url  GitHub repo URL (e.g. https://github.com/owner/repo)"
  echo "  branch    Branch to backup (default: repo's default branch)"
  exit 1
}

REPO_URL="${1:-}"
BRANCH="${2:-}"

[[ -z "$REPO_URL" ]] && usage

# Parse owner/repo from URL
REPO_PATH=$(echo "$REPO_URL" | sed -E 's|https?://github\.com/||; s|\.git$||')
OWNER=$(echo "$REPO_PATH" | cut -d'/' -f1)
REPO=$(echo "$REPO_PATH" | cut -d'/' -f2)

if [[ -z "$OWNER" || -z "$REPO" ]]; then
  echo "Error: could not parse owner/repo from: $REPO_URL"
  exit 1
fi

# Resolve default branch if not provided
if [[ -z "$BRANCH" ]]; then
  echo "Fetching default branch for $OWNER/$REPO..."
  BRANCH=$(gh api "repos/$OWNER/$REPO" --jq '.default_branch')
  echo "Default branch: $BRANCH"
fi

DATE=$(date +%Y-%m-%d)
RELEASE_TAG="backup-${REPO}-${DATE}"
ZIP_FILENAME="${OWNER}-${REPO}-${BRANCH}-${DATE}.zip"
ZIP_URL="https://github.com/${OWNER}/${REPO}/archive/refs/heads/${BRANCH}.zip"
TMP_ZIP="/tmp/${ZIP_FILENAME}"

echo "Downloading $ZIP_URL..."
curl -fsSL "$ZIP_URL" -o "$TMP_ZIP"

# Use BACKUP_REPO env var if set (e.g. in CI), otherwise default to this repo
BACKUP_REPO="${BACKUP_REPO:-chenbojian/github-repo-backup}"

# If a release with this tag already exists on the same date, append a counter
FINAL_TAG="$RELEASE_TAG"
COUNTER=1
while gh release view "$FINAL_TAG" --repo "$BACKUP_REPO" &>/dev/null; do
  COUNTER=$((COUNTER + 1))
  FINAL_TAG="${RELEASE_TAG}-${COUNTER}"
done

echo "Creating release: $FINAL_TAG"
gh release create "$FINAL_TAG" \
  --repo "$BACKUP_REPO" \
  --title "$FINAL_TAG" \
  --notes "Backup of \`${OWNER}/${REPO}\` branch \`${BRANCH}\` on ${DATE}." \
  "${TMP_ZIP}#${ZIP_FILENAME}"

rm -f "$TMP_ZIP"
echo "Done: https://github.com/${BACKUP_REPO}/releases/tag/${FINAL_TAG}"
