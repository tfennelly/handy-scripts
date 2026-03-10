#!/usr/bin/env bash

# Create or update a file in a GitHub repository using a GitHub App.
#
# This script commits files to GitHub with verified signatures by using
# GitHub App authentication and the Contents API.
#
# Usage:
#   ./gh-app-commit.sh <file_path> <branch_name> <file_contents> [commit_message]
#
# Arguments:
#   file_path: Path to the file in the repository (e.g., "config.json")
#   branch_name: Branch to commit to (e.g., "main", "develop")
#   file_contents: Content to write to the file
#   commit_message: (Optional) Custom commit message. If not provided, generates a default message.
#
# Required environment variables:
#   GH_APP_ID: GitHub App ID
#   GH_APP_PRIVATE_KEY or GH_APP_PRIVATE_KEY_PATH:
#     - GH_APP_PRIVATE_KEY: Private key content (recommended for CI/CD)
#     - GH_APP_PRIVATE_KEY_PATH: Path to private key file (for local use)
#   GH_APP_INSTALLATION_ID: (Optional) Installation ID - will auto-detect if not provided
#
# Example:
#   export GH_APP_ID=123456
#   export GH_APP_PRIVATE_KEY_PATH=/path/to/private-key.pem
#   ./gh-app-commit.sh "data/config.json" "main" "$(cat config.json)" "Update configuration"

set -e

# Parse command line arguments
if [ $# -lt 3 ] || [ $# -gt 4 ]; then
  echo "Error: Wrong number of arguments"
  echo ""
  echo "Usage: $0 <file_path> <branch_name> <file_contents> [commit_message]"
  echo ""
  echo "Example:"
  echo "  $0 'config.json' 'main' 'Hello World'"
  echo "  $0 'data/file.txt' 'develop' '\$(cat file.txt)' 'Custom commit message'"
  exit 1
fi

TARGET_FILE_PATH="$1"
TARGET_BRANCH_NAME="$2"
FILE_CONTENT="$3"
CUSTOM_COMMIT_MESSAGE="${4:-}"

# Convert to URL-safe base64 (base64url encoding per RFC 4648)
base64UrlEncode() {
  openssl base64 -e -A | tr '+/' '-_' | tr -d '='
}

if [ -z "$GH_APP_ID" ]; then
  echo "Error: GH_APP_ID not set"
  exit 1
fi

# Load private key - either from env var directly or from file path
if [ -n "$GH_APP_PRIVATE_KEY" ]; then
  echo "Using GH_APP_PRIVATE_KEY from environment variable"
elif [ -n "$GH_APP_PRIVATE_KEY_PATH" ]; then
  echo "Reading private key from: $GH_APP_PRIVATE_KEY_PATH"
  GH_APP_PRIVATE_KEY=$(cat "$GH_APP_PRIVATE_KEY_PATH")
  if [ -z "$GH_APP_PRIVATE_KEY" ]; then
    echo "Error: Could not read private key from $GH_APP_PRIVATE_KEY_PATH"
    exit 1
  fi
else
  echo "Error: Neither GH_APP_PRIVATE_KEY nor GH_APP_PRIVATE_KEY_PATH is set"
  echo ""
  echo "Usage:"
  echo "  Option 1 - Use a file path:"
  echo "    export GH_APP_ID=123456"
  echo "    export GH_APP_PRIVATE_KEY_PATH=/path/to/private-key.pem"
  echo ""
  echo "  Option 2 - Set the key directly (for CI):"
  echo "    export GH_APP_ID=123456"
  echo "    export GH_APP_PRIVATE_KEY='-----BEGIN RSA PRIVATE KEY-----...'"
  exit 1
fi

echo "========================================"
echo "GitHub App File Commit"
echo "========================================"
echo "App ID: $GH_APP_ID"
echo "Target File: $TARGET_FILE_PATH"
echo "Target Branch: $TARGET_BRANCH_NAME"
echo "✓ Private key loaded"
echo ""

# Get repository information from git remote
REPO_OWNER=$(git remote get-url origin | sed -n 's/.*github.com[:/]\(.*\)\/\(.*\)\.git/\1/p')
REPO_NAME=$(git remote get-url origin | sed -n 's/.*github.com[:/]\(.*\)\/\(.*\)\.git/\2/p')

echo "Repository: $REPO_OWNER/$REPO_NAME"
echo ""

# Generate JWT for GitHub App authentication
echo "Generating JWT..."
NOW=$(date +%s)
IAT=$((NOW - 60))
EXP=$((NOW + 600))

JWT_HEADER=$(echo -n '{"alg":"RS256","typ":"JWT"}' | base64UrlEncode)
JWT_PAYLOAD=$(echo -n "{\"iat\":$IAT,\"exp\":$EXP,\"iss\":\"$GH_APP_ID\"}" | base64UrlEncode)
JWT_SIGNATURE=$(echo -n "${JWT_HEADER}.${JWT_PAYLOAD}" | openssl dgst -sha256 -sign <(echo "$GH_APP_PRIVATE_KEY") | base64UrlEncode)
JWT="${JWT_HEADER}.${JWT_PAYLOAD}.${JWT_SIGNATURE}"

echo "✓ JWT generated"
echo ""

# Get installation ID if not provided
if [ -z "$GH_APP_INSTALLATION_ID" ]; then
  echo "Getting installation ID..."
  GH_APP_INSTALLATION_ID=$(curl -s -H "Authorization: Bearer $JWT" -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/installation" | jq -r '.id')

  if [ "$GH_APP_INSTALLATION_ID" = "null" ] || [ -z "$GH_APP_INSTALLATION_ID" ]; then
    echo "Error: Could not get installation ID. Is the app installed on this repository?"
    exit 1
  fi
  echo "✓ Installation ID: $GH_APP_INSTALLATION_ID"
  echo ""
fi

# Get installation access token
echo "Getting installation access token..."
TOKEN_RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer $JWT" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/app/installations/$GH_APP_INSTALLATION_ID/access_tokens")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.token')

if [ "$ACCESS_TOKEN" = "null" ] || [ -z "$ACCESS_TOKEN" ]; then
  echo "Error: Could not get access token"
  echo "Response: $TOKEN_RESPONSE"
  exit 1
fi

echo "✓ Access token obtained"
echo ""

# Get GitHub App details
echo "Getting GitHub App details..."
APP_RESPONSE=$(curl -s -H "Authorization: Bearer $JWT" -H "Accept: application/vnd.github+json" \
  "https://api.github.com/app")

APP_SLUG=$(echo "$APP_RESPONSE" | jq -r '.slug')
APP_NAME=$(echo "$APP_RESPONSE" | jq -r '.name')

if [ "$APP_SLUG" = "null" ] || [ -z "$APP_SLUG" ]; then
  echo "Error: Could not get app slug"
  exit 1
fi

echo "✓ App: $APP_NAME (slug: $APP_SLUG)"
echo ""

echo "Checking if file exists..."
echo "File: $TARGET_FILE_PATH"
echo "Branch: $TARGET_BRANCH_NAME"
echo ""

# Try to get the existing file
GET_RESPONSE=$(curl -s -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/contents/$TARGET_FILE_PATH?ref=$TARGET_BRANCH_NAME")

FILE_SHA=$(echo "$GET_RESPONSE" | jq -r '.sha')

if [ "$FILE_SHA" = "null" ] || [ -z "$FILE_SHA" ]; then
  echo "File does not exist, will create it"
  ACTION="create"
else
  echo "✓ File exists with SHA: $FILE_SHA"
  ACTION="update"
fi
echo ""

# Encode content as base64
FILE_CONTENT_BASE64=$(echo -n "$FILE_CONTENT" | base64 | tr -d '\n')

# Create commit message
if [ -n "$CUSTOM_COMMIT_MESSAGE" ]; then
  COMMIT_MESSAGE="$CUSTOM_COMMIT_MESSAGE"
else
  # Generate default commit message
  if [ "$ACTION" = "create" ]; then
    COMMIT_MESSAGE="Create $TARGET_FILE_PATH"
  else
    COMMIT_MESSAGE="Update $TARGET_FILE_PATH"
  fi
fi

echo "${ACTION^}ing file via GitHub Contents API..."

# Create/update the file using the Contents API
if [ "$FILE_SHA" = "null" ] || [ -z "$FILE_SHA" ]; then
  # Create new file (no sha needed)
  CONTENTS_PAYLOAD=$(jq -n \
    --arg message "$COMMIT_MESSAGE" \
    --arg content "$FILE_CONTENT_BASE64" \
    --arg branch "$TARGET_BRANCH_NAME" \
    '{message: $message, content: $content, branch: $branch}')
else
  # Update existing file (sha required)
  CONTENTS_PAYLOAD=$(jq -n \
    --arg message "$COMMIT_MESSAGE" \
    --arg content "$FILE_CONTENT_BASE64" \
    --arg branch "$TARGET_BRANCH_NAME" \
    --arg sha "$FILE_SHA" \
    '{message: $message, content: $content, branch: $branch, sha: $sha}')
fi

CONTENTS_RESPONSE=$(curl -s -X PUT \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/contents/$TARGET_FILE_PATH" \
  -d "$CONTENTS_PAYLOAD")

COMMIT_SHA=$(echo "$CONTENTS_RESPONSE" | jq -r '.commit.sha')

if [ "$COMMIT_SHA" = "null" ] || [ -z "$COMMIT_SHA" ]; then
  echo "Error: Could not ${ACTION} file"
  echo "Response: $CONTENTS_RESPONSE"
  exit 1
fi

echo "✓ File ${ACTION}d: $COMMIT_SHA"
echo ""
echo "✓ Successfully committed to branch: $TARGET_BRANCH_NAME"
echo ""
