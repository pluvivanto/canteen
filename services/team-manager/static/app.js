const $ = (id) => document.getElementById(id);
let teamID;

async function api(method, path, body) {
  const res = await fetch(path, {
    method,
    headers: { Authorization: `Bearer ${teamID}`, "Content-Type": "application/json" },
    body: body && JSON.stringify(body),
  });
  const data = await res.json();
  if (!res.ok) {
    throw Object.assign(new Error(data.error), { status: res.status });
  }
  return data;
}

function showTeam(team) {
  $("login").hidden = true;
  $("team").hidden = false;
  $("team-name").textContent = team.display_name;
}

$("login").addEventListener("submit", async (e) => {
  e.preventDefault();
  teamID = `team-${$("team-input").value}`;
  try {
    showTeam(await api("GET", "/me"));
  } catch (err) {
    $("login-error").textContent = err.status === 401 ? "Unknown team ID." : "Something went wrong. Try again.";
  }
});

$("rename").addEventListener("submit", async (e) => {
  e.preventDefault();
  $("rename-error").textContent = "";
  try {
    showTeam(await api("PATCH", "/me", { display_name: $("new-name").value }));
  } catch (err) {
    $("rename-error").textContent = err.message;
  }
});

$("issue").addEventListener("click", async () => {
  $("issue-error").textContent = "";
  try {
    const { key } = await api("POST", "/me/keys");
    $("key").value = key;
    $("new-key").hidden = false;
  } catch (err) {
    $("issue-error").textContent = err.message;
  }
});
