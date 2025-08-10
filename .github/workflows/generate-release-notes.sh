#!/bin/bash
set -e

# This script generates release notes for the application.
# It finds the date and commit of the last 'latest' tag, lists commits since then, and closed issues since that date.

# Get the commit hash and date for the 'latest' tag
tag_commit=$(git rev-list -n 1 latest)
tag_date=$(git show -s --format=%cI "$tag_commit")

# echo "Last 'latest' tag commit: $tag_commit ($tag_date)"

# Get the date in ISO 8601 format for GitHub API
since_date=$(date -u -j -f "%Y-%m-%dT%H:%M:%S%z" "${tag_date//Z/+0000}" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "$tag_date")

# Get closed issues since the tag date using GitHub API
REPO="l2fprod/flitro"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

echo "<b>🚀 Closed issues</b>"
echo "<ul>"
page=1
while :; do
  if [ -n "$GITHUB_TOKEN" ]; then
    auth_header="-H \"Authorization: Bearer $GITHUB_TOKEN\""
  else
    auth_header=""
  fi
  # Use GitHub Search API to find issues closed after the tag date
  search_url="https://api.github.com/search/issues?q=repo:$REPO+is:issue+is:closed+closed:>$since_date&sort=closed&order=asc&per_page=100&page=$page"
  issues=$(curl -s $auth_header "$search_url")
  # Check if the response contains items
  count=$(echo "$issues" | jq '.items | length' 2>/dev/null || echo 0)
  if ! [[ "$count" =~ ^[0-9]+$ ]]; then
    echo "[Error] Unexpected API response or rate limit exceeded."
    break
  fi
  if [ "$count" -eq 0 ]; then
    break
  fi
  echo "$issues" | jq -r --arg repo "$REPO" '
    .items[] |
    "<li>\(.title) <a href=\"https://github.com/\($repo)/issues/\(.number)\">#\(.number)</a></li>"
  '
  total_count=$(echo "$issues" | jq '.total_count' 2>/dev/null || echo 0)
  shown=$((page * 100))
  if [ "$shown" -ge "$total_count" ]; then
    break
  fi
  page=$((page+1))
done
echo "</ul>"
echo "<br/>"
echo "<b>💻 Commits</b>"
echo "<ul>"
git --no-pager log $tag_commit..main --pretty=format:'<li>%s <a href="https://github.com/'$REPO'/commit/%h">#%h</a></li>' --no-merges
echo "
</ul>"
