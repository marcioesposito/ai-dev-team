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
  JIRA_PROJECT_KEY
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
  echo "Make sure your .env file is complete before running the orchestrator."
  exit 1
fi

echo "✅ All required environment variables are present."

# ─────────────────────────────────────────
# Functions
# ─────────────────────────────────────────

# Fetches open "To Do" tickets from Jira and returns
# their keys one per line, using parse_tickets.py to
# parse the JSON response.
fetch_jira_tickets() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  local response
  response=$(curl -s \
    -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
    -H "Content-Type: application/json" \
    "https://${JIRA_BASE_URL#https://}/rest/api/3/search/jql?jql=project%20%3D%20${JIRA_PROJECT_KEY}+AND+status%20%3D%20'To%20Do'+ORDER+BY+created+ASC&maxResults=10&fields=key,summary")

  if [[ -z "$response" ]]; then
    echo "❌ ERROR: Empty response from Jira API. Check your JIRA_BASE_URL and credentials." >&2
    exit 1
  fi

  echo "$response" | python3 "$script_dir/parse_tickets.py"
}

# ─────────────────────────────────────────
# Main
# ─────────────────────────────────────────
echo ""
echo "=== Fetching open tickets from Jira project: $JIRA_PROJECT_KEY ==="

TICKETS=$(fetch_jira_tickets)

if [[ -z "$TICKETS" ]]; then
  echo "No 'To Do' tickets found in project $JIRA_PROJECT_KEY. Exiting."
  exit 0
fi

echo "Found tickets:"
echo "$TICKETS"
echo ""

# Assign tickets to agents
TICKET_ARRAY=($TICKETS)
TICKET_1="${TICKET_ARRAY[0]:-}"
TICKET_2="${TICKET_ARRAY[1]:-}"

if [[ -z "$TICKET_1" ]]; then
  echo "❌ ERROR: Could not assign ticket to agent 1."
  exit 1
fi

echo "=== Launching agents ==="
echo "Agent 1 → $TICKET_1"

if [[ -n "$TICKET_2" ]]; then
  echo "Agent 2 → $TICKET_2"
else
  echo "Agent 2 → no ticket available (only one ticket found)"
fi

echo ""
TICKET_1=$TICKET_1 TICKET_2=$TICKET_2 docker compose up --build