import http from "k6/http";
import { check } from "k6";
import exec from "k6/execution";

const DOMAIN = "example.com";
const TEAM_ADMIN_API = `https://team-admin.${DOMAIN}`;
const LLM_API = `https://llm.${DOMAIN}`;
const TOKEN = __ENV.TOKEN;
const MODEL = __ENV.MODEL || "mock-slow";
const TEAMS = Number(__ENV.TEAMS || 30);
const RATE = Number(__ENV.RATE || 25);

export const options = {
  scenarios: {
    teams: {
      executor: "constant-arrival-rate",
      rate: RATE,
      timeUnit: "1s",
      duration: __ENV.DURATION || "5m",
      preAllocatedVUs: 400,
    },
  },
  thresholds: {
    http_req_failed: ["rate<0.001"],
    http_req_duration: ["p(95)<4000"],
  },
};

const admin = { headers: { Authorization: `Bearer ${TOKEN}` } };

export function setup() {
  const teams = [];
  for (let i = 1; i <= TEAMS; i++) {
    const id = http.post(`${TEAM_ADMIN_API}/teams`, JSON.stringify({ display_name: `Load Test ${i}` }), admin).json("id");
    const key = http.post(`${TEAM_ADMIN_API}/teams/${id}/keys`, null, admin).json("key");
    teams.push({ id, key });
  }
  return teams;
}

export default function (teams) {
  const team = teams[exec.scenario.iterationInTest % teams.length];
  const res = http.post(
    `${LLM_API}/v1/chat/completions`,
    JSON.stringify({ model: MODEL, max_tokens: 50, messages: [{ role: "user", content: "Say hi" }] }),
    { headers: { Authorization: `Bearer ${team.key}`, "Content-Type": "application/json" } },
  );
  check(res, { 200: (r) => r.status === 200 });
}

export function teardown(teams) {
  for (const team of teams) {
    http.del(`${TEAM_ADMIN_API}/teams/${team.id}`, null, admin);
  }
}
