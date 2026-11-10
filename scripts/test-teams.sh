#!/usr/bin/env bash
set -e

DOMAIN=hackathon.pluvivanto.win
TEAM_API=https://team.$DOMAIN
LLM_API=https://llm.$DOMAIN
TOKEN=$(kubectl --context eks-hackathon -n team-manager get secret team-manager-admin -o jsonpath='{.data.token}' | base64 -d)
MASTER_KEY=$(kubectl --context eks-hackathon -n litellm get secret litellm-masterkey -o jsonpath='{.data.masterkey}' | base64 -d)

call() {
	curl -s -o /dev/null -w '%{http_code}' $LLM_API/v1/chat/completions \
		-H "Authorization: Bearer $1" \
		-H "Content-Type: application/json" \
		-d '{"model": "mock", "messages": [{"role": "user", "content": "hi"}]}'
}

echo -n "invalid display name: "
RESULT=success
for NAME in "" "   " "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"; do
	CODE=$(curl -s -o /dev/null -w '%{http_code}' $TEAM_API/teams \
		-H "Authorization: Bearer $TOKEN" \
		-d "{\"display_name\": \"$NAME\"}")
	if [ "$CODE" != 400 ]; then
		RESULT="fail ('$NAME': $CODE)"
	fi
done
echo "$RESULT"

echo -n "no admin token: "
CODE=$(curl -s -o /dev/null -w '%{http_code}' $TEAM_API/teams -d '{"display_name": "No Token"}')
if [ "$CODE" = 401 ]; then
	echo "success"
else
	echo "fail ($CODE)"
fi

echo -n "rate limit: "
TEAM_ID=$(curl -s $TEAM_API/teams -H "Authorization: Bearer $TOKEN" -d '{"display_name": "RPM Test"}' | jq -r .id)
KEY=$(curl -s -X POST $TEAM_API/teams/$TEAM_ID/keys -H "Authorization: Bearer $TOKEN" | jq -r .key)
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
curl -s -o /dev/null -X DELETE $TEAM_API/teams/$TEAM_ID -H "Authorization: Bearer $TOKEN"

echo -n "budget: "
TEAM_ID=$(curl -s $TEAM_API/teams -H "Authorization: Bearer $TOKEN" -d '{"display_name": "Budget Test"}' | jq -r .id)
KEY=$(curl -s -X POST $TEAM_API/teams/$TEAM_ID/keys -H "Authorization: Bearer $TOKEN" | jq -r .key)
curl -s -o /dev/null $LLM_API/team/update \
	-H "Authorization: Bearer $MASTER_KEY" \
	-H "Content-Type: application/json" \
	-d "{\"team_id\": \"$TEAM_ID\", \"max_budget\": 0.00001}"
FIRST=$(call "$KEY")
sleep 2
SECOND=$(curl -s $LLM_API/v1/chat/completions \
	-H "Authorization: Bearer $KEY" \
	-H "Content-Type: application/json" \
	-d '{"model": "mock", "messages": [{"role": "user", "content": "hi"}]}')
if [ "$FIRST" = 200 ] && echo "$SECOND" | grep -q "Budget has been exceeded"; then
	echo "success"
else
	echo "fail (first: $FIRST, second: $SECOND)"
fi
curl -s -o /dev/null -X DELETE $TEAM_API/teams/$TEAM_ID -H "Authorization: Bearer $TOKEN"

echo -n "reissued key: "
TEAM_ID=$(curl -s $TEAM_API/teams -H "Authorization: Bearer $TOKEN" -d '{"display_name": "Reissue Test"}' | jq -r .id)
OLD_KEY=$(curl -s -X POST $TEAM_API/teams/$TEAM_ID/keys -H "Authorization: Bearer $TOKEN" | jq -r .key)
NEW_KEY=$(curl -s -X POST $TEAM_API/teams/$TEAM_ID/keys -H "Authorization: Bearer $TOKEN" | jq -r .key)
OLD=$(call "$OLD_KEY")
NEW=$(call "$NEW_KEY")
if [ "$OLD" = 401 ] && [ "$NEW" = 200 ]; then
	echo "success"
else
	echo "fail (old: $OLD, new: $NEW)"
fi

echo -n "deleted team: "
curl -s -o /dev/null -X DELETE $TEAM_API/teams/$TEAM_ID -H "Authorization: Bearer $TOKEN"
CODE=$(call "$NEW_KEY")
if [ "$CODE" = 401 ]; then
	echo "success"
else
	echo "fail ($CODE)"
fi

echo -n "team code: "
CREATED=$(curl -s $TEAM_API/teams -H "Authorization: Bearer $TOKEN" -d '{"display_name": "Code Test"}')
TEAM_ID=$(echo "$CREATED" | jq -r .id)
OLD_CODE=$(echo "$CREATED" | jq -r .code)
TYPED=$(echo "$OLD_CODE" | tr -d - | tr a-z A-Z)
ME=$(curl -s $TEAM_API/me -H "Authorization: Bearer $TYPED" | jq -r .display_name)
RENAMED=$(curl -s -X PATCH $TEAM_API/me -H "Authorization: Bearer $OLD_CODE" -d '{"display_name": "Foo Bar"}' | jq -r .display_name)
KEY=$(curl -s -X POST $TEAM_API/me/keys -H "Authorization: Bearer $OLD_CODE" | jq -r .key)
LLM=$(call "$KEY")
WRONG=$(curl -s -o /dev/null -w '%{http_code}' $TEAM_API/me -H "Authorization: Bearer wrong-code")
ADMIN=$(curl -s -o /dev/null -w '%{http_code}' $TEAM_API/teams/$TEAM_ID -H "Authorization: Bearer $OLD_CODE")
NEW_CODE=$(curl -s -X POST $TEAM_API/teams/$TEAM_ID/code -H "Authorization: Bearer $TOKEN" | jq -r .code)
OLD=$(curl -s -o /dev/null -w '%{http_code}' $TEAM_API/me -H "Authorization: Bearer $OLD_CODE")
NEW=$(curl -s -o /dev/null -w '%{http_code}' $TEAM_API/me -H "Authorization: Bearer $NEW_CODE")
if [ "$ME" = "Code Test" ] && [ "$RENAMED" = "Foo Bar" ] && [ "$LLM" = 200 ] && [ "$WRONG" = 401 ] && [ "$ADMIN" = 401 ] && [ "$OLD" = 401 ] && [ "$NEW" = 200 ]; then
	echo "success"
else
	echo "fail (me: $ME, renamed: $RENAMED, llm: $LLM, wrong: $WRONG, admin: $ADMIN, old: $OLD, new: $NEW)"
fi
curl -s -o /dev/null -X DELETE $TEAM_API/teams/$TEAM_ID -H "Authorization: Bearer $TOKEN"
