#!/usr/bin/env bash
set -euo pipefail

TEAM_ID=$1

MASTER_KEY=$(kubectl --context eks-hackathon -n litellm get secret litellm-masterkey -o jsonpath='{.data.masterkey}' | base64 -d)

RESPONSE=$(curl -sS --fail-with-body https://llm.hackathon.pluvivanto.win/team/delete \
	-H "Authorization: Bearer $MASTER_KEY" \
	-H "Content-Type: application/json" \
	-d "{\"team_ids\": [\"$TEAM_ID\"]}") ||
	{
		echo "$RESPONSE" >&2
		exit 1
	}
