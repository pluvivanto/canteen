#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"

RUN_ID=$(date +%s)
MASTER_KEY=$(kubectl --context eks-hackathon -n litellm get secret litellm-masterkey -o jsonpath='{.data.masterkey}' | base64 -d)

call() {
	curl -s -o /dev/null -w '%{http_code}' https://llm.hackathon.pluvivanto.win/v1/chat/completions \
		-H "Authorization: Bearer $1" \
		-H "Content-Type: application/json" \
		-d '{"model": "mock", "messages": [{"role": "user", "content": "hi"}]}'
}

echo -n "invalid team id: "
RESULT=success
for TEAM_ID in Team-a team_a team-a- team- foo-a team-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa; do
	if ! ./create-team.sh "$TEAM_ID" test 2>&1 | grep -q "invalid team id"; then
		RESULT="fail ($TEAM_ID)"
	fi
done
echo "$RESULT"

echo -n "rate limit: "
TEAM_ID=team-test-rpm-$RUN_ID
KEY=$(./create-team.sh "$TEAM_ID" "RPM Test")
OK=0
LIMITED=0
for i in $(seq 65); do
	case $(call "$KEY") in
	200) OK=$((OK + 1)) ;;
	429) LIMITED=$((LIMITED + 1)) ;;
	esac
done
if [ "$OK" = 60 ] && [ "$LIMITED" = 5 ]; then
	echo "success"
else
	echo "fail (200: $OK, 429: $LIMITED)"
fi
./delete-team.sh "$TEAM_ID"

echo -n "budget: "
TEAM_ID=team-test-budget-$RUN_ID
KEY=$(./create-team.sh "$TEAM_ID" "Budget Test")
curl -s -o /dev/null https://llm.hackathon.pluvivanto.win/team/update \
	-H "Authorization: Bearer $MASTER_KEY" \
	-H "Content-Type: application/json" \
	-d "{\"team_id\": \"$TEAM_ID\", \"max_budget\": 0.00001}"
FIRST=$(call "$KEY")
sleep 2
SECOND=$(curl -s https://llm.hackathon.pluvivanto.win/v1/chat/completions \
	-H "Authorization: Bearer $KEY" \
	-H "Content-Type: application/json" \
	-d '{"model": "mock", "messages": [{"role": "user", "content": "hi"}]}')
if [ "$FIRST" = 200 ] && echo "$SECOND" | grep -q "Budget has been exceeded"; then
	echo "success"
else
	echo "fail (first: $FIRST, second: $SECOND)"
fi
./delete-team.sh "$TEAM_ID"

echo -n "revoked key: "
TEAM_ID=team-test-revoke-$RUN_ID
KEY=$(./create-team.sh "$TEAM_ID" "Revoke Test")
./delete-team.sh "$TEAM_ID"
if [ "$(call "$KEY")" = 401 ]; then
	echo "success"
else
	echo "fail"
fi
