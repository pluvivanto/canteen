#!/usr/bin/env bash
set -euo pipefail

TEAM_ID=$1
DISPLAY_NAME=$2
MAX_BUDGET=10
RPM_LIMIT=60

if [[ ! $TEAM_ID =~ ^team-[a-z0-9-]+$ || $TEAM_ID == *- || ${#TEAM_ID} -gt 63 ]]; then
	echo "invalid team id: $TEAM_ID" >&2
	exit 1
fi

MASTER_KEY=$(kubectl --context eks-hackathon -n litellm get secret litellm-masterkey -o jsonpath='{.data.masterkey}' | base64 -d)

RESPONSE=$(curl -sS --fail-with-body https://llm.hackathon.pluvivanto.win/team/new \
	-H "Authorization: Bearer $MASTER_KEY" \
	-H "Content-Type: application/json" \
	-d "{\"team_id\": \"$TEAM_ID\", \"team_alias\": \"$DISPLAY_NAME\", \"max_budget\": $MAX_BUDGET, \"rpm_limit\": $RPM_LIMIT}") ||
	{
		echo "$RESPONSE" >&2
		exit 1
	}

curl -sS --fail-with-body https://llm.hackathon.pluvivanto.win/key/generate \
	-H "Authorization: Bearer $MASTER_KEY" \
	-H "Content-Type: application/json" \
	-d "{\"team_id\": \"$TEAM_ID\"}" |
	jq -r .key
