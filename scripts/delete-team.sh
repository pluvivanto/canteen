#!/usr/bin/env bash
set -euo pipefail

TEAM_ID=$1

MASTER_KEY=$(kubectl --context kind-hackathon -n litellm get secret litellm-masterkey -o jsonpath='{.data.masterkey}' | base64 -d)

RESPONSE=$(curl -sS --fail-with-body http://llm.localtest.me/team/delete \
	-H "Authorization: Bearer $MASTER_KEY" \
	-H "Content-Type: application/json" \
	-d "{\"team_ids\": [\"$TEAM_ID\"]}") ||
	{
		echo "$RESPONSE" >&2
		exit 1
	}
