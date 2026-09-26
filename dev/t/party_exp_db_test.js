// v67 👥 party EXP bonus vs the server's EXP guard (local Postgres): with 3 mates on the map the +30% EXP saves
// are accepted while the server knows the party; the same bonus without a party is refused.
// Run: cd /tmp/mw/t && DB=b2 node party_exp_db_test.js
const { loadGame } = require("./harness");
const { execFileSync } = require("child_process");
const DB = process.env.DB || "b2";
const psql = sql => execFileSync("psql", ["-h", "/tmp", "-p", "5433", "-U", "postgres", "-d", DB, "-At", "-q", "-v", "ON_ERROR_STOP=1"], { input: sql, encoding: "utf8", maxBuffer: 1 << 26 }).trim();
const U = n => "00000000-0000-0000-0000-0000000068" + String(n).padStart(2, "0");
function run(inParty){
  const g = loadGame(process.env.GAME || "game.html"), R = s => g.run(s), G = s => g.get(s);
  const UID = U(inParty ? 1 : 9), SESSION = "11111111-1111-1111-1111-1111111168" + (inParty ? "01" : "09");
  const asMe = body => psql(`begin; set local role authenticated; select set_config('request.jwt.claim.sub', '${UID}', true) \\g /dev/null\n${body};\ncommit;`);
  psql(`delete from public.saves where user_id = '${UID}'; delete from auth.users where id in ('${UID}', '${U(2)}', '${U(3)}', '${U(4)}');
        insert into auth.users (id) values ('${UID}'), ('${U(2)}'), ('${U(3)}'), ('${U(4)}');`);
  asMe(`select public.claim_session('${SESSION}')`);
  if(inParty) psql(`with p as (insert into public.parties (leader) values ('${UID}') returning id)
                    insert into public.party_members (user_id, party_id) select u, p.id from p, unnest(array['${UID}', '${U(2)}', '${U(3)}', '${U(4)}']::uuid[]) u;
                    select public.party_touch((select party_id from public.party_members where user_id = '${UID}'));`);
  let rev = 0, last = null; const rejects = [];
  const save = () => {
    const json = G("JSON.stringify(buildSaveData())"), dt = last == null ? 0 : (g.clock.t - last) / 1000;
    psql(`update public.saves set updated_at = now() - make_interval(secs => ${dt.toFixed(3)}) where user_id = '${UID}';`);
    const r = JSON.parse(asMe(`select public.save_game('${SESSION}', ${rev}, $J$${json}$J$::jsonb)`).split("\n").pop());
    if(r.ok) rev = r.rev; else { rejects.push(r.detail); psql(`update public.saves set data = $J$${json}$J$::jsonb, rev = rev + 1 where user_id = '${UID}';`); rev++; }
    last = g.clock.t;
  };
  R(`startGame("Exp", { ...look }, "sword"); closeTutorial && closeTutorial(); document.getElementById("coachModal").hidden = true; game.player.tutorialDone = true;`);
  save();
  R(`partyAvailable = () => true; net.user = { id: "${UID}" };
     party.data = { id: 1, leader: "${UID}", members: ["${UID}", "${U(2)}", "${U(3)}", "${U(4)}"].map((id, i) => ({ id, name: "P" + i, level: 1, online: true, map: 1, dim: 1 })) };
     warpToMap(1); ["${U(2)}", "${U(3)}", "${U(4)}"].forEach(id => rtPeerUpdate({ id, x: 300, y: 300, name: "M", mapTier: 1, dimension: 1, level: 5 }));
`);
  save();
  for(let k = 0; k < 30; k++){ // 10 kills per save: the +30% must be more than the guard's fixed slack
    R(`["${U(2)}", "${U(3)}", "${U(4)}"].forEach(id => rt.peers.get(id) && (rt.peers.get(id).seen = performance.now()))`);
    R(`(()=>{ const m = game.monsters.find(m => m.type === 4); m.alive = true; m.hp = 1; enterBattle(m); exitBattle("win"); closeSummaryPanel();
         if(document.getElementById('battleCanvas').style.display === 'block') returnToOverworldView(); })()`);
    g.clock.advance(6000); if(k % 10 === 9) save();
  }
  return { mult: G("partyExpMult()"), rejects };
}
const a = run(true), b = run(false);
console.log("in party:", JSON.stringify(a), " no party:", JSON.stringify(b));
const fails = [];
if(a.mult < 1.29 || a.rejects.length) fails.push("party bonus saves should pass");
if(!b.rejects.includes("exp")) fails.push("bonus without a party should be refused");
console.log("fails", JSON.stringify(fails));
