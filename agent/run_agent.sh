#!/bin/bash
set -e

# ─────────────────────────────────────────
# Validate required environment variables
# ─────────────────────────────────────────
REQUIRED_VARS=(
  ANTHROPIC_API_KEY
  GITHUB_REPO
  GITHUB_TOKEN
  JIRA_API_TOKEN
  JIRA_BASE_URL
  JIRA_EMAIL
  JIRA_TICKET
)

MISSING=()
for VAR in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!VAR}" ]]; then
    MISSING+=("$VAR")
  fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "❌ ERROR: The following required environment variables are missing or empty:"
  for VAR in "${MISSING[@]}"; do
    echo "   - $VAR"
  done
  echo ""
  echo "Make sure your .env file is complete and passed to the container."
  exit 1
fi

echo "✅ All required environment variables are present."

# ─────────────────────────────────────────
# Main agent logic
# ─────────────────────────────────────────
echo "=== Agent starting for ticket: $JIRA_TICKET ==="

git config --global user.email "$JIRA_EMAIL"
git config --global user.name "AI Dev Agent"

echo "$GITHUB_TOKEN" | gh auth login --with-token 2>/dev/null || true

REPO_DIR="/home/agent/workspace"
git clone "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPO}.git" "$REPO_DIR"
cd "$REPO_DIR"

claude --dangerously-skip-permissions -p "
  Read your instructions in CLAUDE.md.
  Your assigned Jira ticket is: $JIRA_TICKET
  The GitHub repo is: $GITHUB_REPO
  Complete the full workflow described in CLAUDE.md for this ticket.
"

echo "=== Agent finished for ticket: $JIRA_TICKET ==="