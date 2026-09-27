// v66 🎣 fishing against the real server rules (local Postgres, see story_db_test.js for the setup):
// honest fishing + selling is accepted, fish faster than possible / fish out of thin air are refused.
// Run: cd /tmp/mw/t && DB=b2 node fish_db_test.js
const { loadGame } = require("./harness");
const g = loadGame(process.env.GAME || "game.html");
const R = s => g.run(s), G = s => g.get(s);
const { execFileSync } = require("child_process");
const DB = process.env.DB || "b2", UID = "00000000-0000-0000-0000-000000000066", SESSION = "11111111-1111-1111-1111-111111111166";
const psql = sql => execFileSync("psql", ["-h", "/tmp", "-p", "5433", "-U", "postgres", "-d", DB, "-At", "-q", "-v", "ON_ERROR_STOP=1"], { input: sql, encoding: "utf8", maxBuffer: 1 << 26 }).trim();
const asMe = body => psql(`begin; set local role authenticated; select set_config('request.jwt.claim.sub', '${UID}', true) \\g /dev/null\n${body};\ncommit;`);
psql(`delete from public.saves where user_id = '${UID}'; delete from auth.users where id = '${UID}'; insert into auth.users (id) values ('${UID}');`);
asMe(`select public.claim_session('${SESSION}')`);
let rev = 0, lastClock = null;
function save(json, dtOverride){
  json = json || G("JSON.stringify(buildSaveData())");
  const dt = dtOverride != null ? dtOverride : (lastClock == null ? 0 : (g.clock.t - lastClock) / 1000);
  psql(`update public.saves set updated_at = now() - make_interval(secs => ${dt.toFixed(3)}) where user_id = '${UID}';`);
  const r = JSON.parse(asMe(`select public.save_game('${SESSION}', ${rev}, $J$${json}$J$::jsonb)`).split("\n").pop());
  if(r.ok) rev = r.rev;
  lastClock = g.clock.t;
  return r;
}
const fails = [];
R(`startGame("Angler", { ...look }, "sword"); closeTutorial && closeTutorial(); document.getElementById("coachModal").hidden = true; game.player.tutorialDone = true; warpToMap(TOWN_TIER);`);
R("game.player.x = FISH_SPOTS[0].x; game.player.y = FISH_SPOTS[0].y");
let r = save(); if(!r.ok) fails.push("first save " + JSON.stringify(r));
let rejects = 0, n = 0;
for(let i = 0; i < 16; i++){ // honest angler: real time passes (harness clock), one save per catch (the game saves right after a catch)
  R("startFishing(); document.getElementById('fishResult').hidden = true");
  let t = 0;
  while(G("fishing.phase") !== "done" && t < 60){
    const st = JSON.parse(G("JSON.stringify({ p: fishing.power, z: fishing.zoneC, v: fishing.vel, tug: fishing.tug && fishing.tug.side })"));
    R(`fishing.hold = ${st.p + st.v * 0.25 < st.z}; fishing.keyL = ${st.tug === "right"}; fishing.keyR = ${st.tug === "left"}`);
    R("fishStep(0.05)"); g.clock.advance(50); t += 0.05;
  }
  R("closeFishing()"); n++;
  r = save(); if(!r.ok){ rejects++; fails.push("honest catch " + i + " " + JSON.stringify(r)); }
}
console.log("honest fishing:", G("game.stats.fishCaught"), "fish,", rejects, "rejects, titles", G("JSON.stringify([...game.unlockedTitles].filter(t => t.startsWith('fish')))"));
// sell every fish to the merchant
const before = G("game.player.gold");
R("for(let i = game.inventory.length - 1; i >= 0; i--){ const e = game.inventory[i]; if(FISH_BY_ID[e.id]) sellItem(i, e.qty); }");
console.log("sold fish for", G("game.player.gold") - before, "gold");
g.clock.advance(3000); r = save(); if(!r.ok) fails.push("sell " + JSON.stringify(r));
// cheat 1: 60 fish in 5 seconds
g.clock.advance(5000);
const cheat = JSON.parse(G("JSON.stringify(buildSaveData())"));
cheat.stats.fishCaught += 60; cheat.inventory.push({ id: "fish_maguro", qty: 60 });
r = save(JSON.stringify(cheat)); console.log("cheat 60 fish in 5 s →", JSON.stringify(r)); if(r.ok) fails.push("fast fish accepted");
// cheat 2: fish items without catching them
const cheat2 = JSON.parse(G("JSON.stringify(buildSaveData())")); cheat2.inventory.push({ id: "fish_maguro", qty: 30 });
r = save(JSON.stringify(cheat2), 600); console.log("cheat 30 fish, no catches →", JSON.stringify(r)); if(r.ok) fails.push("free fish accepted");
// cheat 3: the fish title without fishing
const cheat3 = JSON.parse(G("JSON.stringify(buildSaveData())")); cheat3.unlockedTitles.push("fish_master");
r = save(JSON.stringify(cheat3), 60); console.log("cheat title →", JSON.stringify(r)); if(r.ok) fails.push("fish title accepted");
console.log("fails", JSON.stringify(fails));
console.log("errors:", JSON.stringify(g.errors().slice(0, 5)));
