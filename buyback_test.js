// v45: NPC buy-back through the real game code (harness) + the real save_game on local Postgres.
const { loadGame } = require("./harness");
const { execFileSync } = require("child_process");
const DB = process.env.DB || "b1", UID = "00000000-0000-0000-0000-0000000000b1", SESS = "33333333-3333-3333-3333-3333333333b1";
const psql = sql => execFileSync("psql", ["-h", "/tmp", "-p", "5433", "-U", "postgres", "-d", DB, "-At", "-q", "-v", "ON_ERROR_STOP=1"], { input: sql, encoding: "utf8", maxBuffer: 1 << 26 }).trim();
const asMe = body => psql(`begin; set local role authenticated; select set_config('request.jwt.claim.sub', '${UID}', true) \\g /dev/null\n${body};\ncommit;`);
const g = loadGame("game.html"); const R = s => g.run(s), G = s => g.get(s);
const results = []; const check = (n, c, info) => results.push((c ? "PASS " : "FAIL ") + n + (c ? "" : " " + JSON.stringify(info)));
R(`startGame("BB", { ...look }, "sword"); closeTutorial && closeTutorial(); document.getElementById("coachModal").hidden = true; game.player.tutorialDone = true; warpToMap(TOWN_TIER);`);
R(`game.player.level = 20; game.player.expNeeded = 2000; game.player.gold = 1000; game.maxMapTierReached = 3; game.maxMapTierReachedDim1 = 3;
   ["sword_5_t3","armor_5","headgear_2"].forEach(d => { const e = rollEquipmentInstance(d); game.inventory.push(e); });
   game.inventory.push({ id:"potion", qty:5 }); game.inventory.push({ id:"mana_stone", qty:4 });`);
psql(`delete from auth.users where id = '${UID}'; insert into auth.users (id) values ('${UID}');`);
let rev = 5;
psql(`insert into public.saves (user_id, data, rev, session_id, updated_at) values ('${UID}', $J$${G("JSON.stringify(buildSaveData())")}$J$::jsonb, 5, '${SESS}', now() - interval '30 seconds')`);
function save(tag, data){
  const json = data ? JSON.stringify(data) : G("JSON.stringify(buildSaveData())");
  psql(`update public.saves set updated_at = now() - interval '30 seconds' where user_id = '${UID}'`);
  const r = JSON.parse(asMe(`select public.save_game('${SESS}', ${rev}, $J$${json}$J$::jsonb)`).split("\n").pop());
  if(r.ok) rev = r.rev;
  return r;
}
const inv = () => JSON.parse(G("JSON.stringify(game.inventory.map(e => e.defId || e.id))"));
const idxOf = d => G(`game.inventory.findIndex(e => (e.defId || e.id) === ${JSON.stringify(d)})`);
const gold = () => G("game.player.gold");

let r = save("base"); check("baseline save", r.ok, r);
// open the sell window the way the game does
R(`openServicePanel("sellPanel", renderSellPanel)`);
const g0 = gold();
R(`sellItem(${idxOf("armor_5")}, 1)`);
check("sold legendary +400", gold() === g0 + 400, gold());
check("in buy-back list", G("game.buyback.length") === 1 && G("game.buyback[0].bbPrice") === 400, G("JSON.stringify(game.buyback)"));
r = save("after sell"); check("save after sell accepted", r.ok, r);
const cheat = JSON.parse(G("JSON.stringify(buildSaveData())"));
R(`buyBackItem(0)`);
check("bought back −400, same item", gold() === g0 && inv().includes("armor_5") && G("game.buyback.length") === 0, [gold(), inv()]);
r = save("after buyback"); check("save after buy-back accepted (same instanceId)", r.ok, r);
// cheat: move from buy-back to bag without paying (from the post-sell state)
psql(`update public.saves set data = $J$${JSON.stringify(cheat)}$J$::jsonb where user_id = '${UID}'`);
const free = JSON.parse(JSON.stringify(cheat)); const it = free.buyback.shift(); delete it.bbPrice; free.inventory.push(it);
r = save("free rebuy", free); check("free rebuy of a legendary refused", !r.ok, r);
// restore honest state
R(`sellItem(${idxOf("armor_5")}, 1)`); r = save("resell"); psql(`update public.saves set data = $J$${G("JSON.stringify(buildSaveData())")}$J$::jsonb where user_id = '${UID}'`);
// stacks: sell 3 potions, save, buy back
R(`sellItem(${idxOf("potion")}, 3)`);
r = save("sell potions"); check("sell potions accepted", r.ok, r);
R(`buyBackItem(game.buyback.findIndex(b => b.id === "potion"))`);
check("potions back to 5", G(`game.inventory.find(e => e.id === "potion").qty`) === 5, inv());
r = save("rebuy potions"); check("rebuy potions accepted", r.ok, r);
// cheat: mana stones appear in the buy-back list from nowhere
const inj = JSON.parse(G("JSON.stringify(buildSaveData())")); inj.buyback.push({ id:"mana_stone", qty:50, bbPrice:600 });
r = save("inject", inj); check("stacks injected into buy-back refused", !r.ok && r.detail === "buyback", r);
// cheat: same equipment in bag and buy-back
const dup = JSON.parse(G("JSON.stringify(buildSaveData())")); const sw = dup.inventory.find(e => e.defId === "sword_5_t3"); dup.buyback.push(Object.assign({}, sw, { bbPrice: 80 }));
r = save("dup", dup); check("bag + buy-back copy = dupe", !r.ok && r.reason === "dupe", r);
// cheat: 13 entries
const big = JSON.parse(G("JSON.stringify(buildSaveData())")); big.buyback = Array.from({ length: 13 }, () => ({ id:"potion", qty:0 }));
r = save("big", big); check("more than 12 refused", !r.ok, r);
// a new session empties the list — the items are gone for good
R(`sellItem(${idxOf("headgear_2")}, 1)`); r = save("sell hat"); check("sell hat accepted", r.ok, r);
const hat = JSON.parse(G("JSON.stringify(game.buyback.find(b => b.defId === 'headgear_2'))"));
const g2 = loadGame("game.html"); g2.run(`continueGame(JSON.parse(${JSON.stringify(G("JSON.stringify(buildSaveData())"))}))`);
check("reload empties buy-back", g2.get("game.buyback.length") === 0);
const after = JSON.parse(g2.get("JSON.stringify(buildSaveData())"));
r = save("after reload", after); check("save after reload accepted", r.ok, r);
const back = JSON.parse(JSON.stringify(after)); delete hat.bbPrice; back.inventory.push(hat); back.player.gold -= 35;
r = save("hat from nowhere", back); check("item gone after reload can't return", !r.ok && r.reason === "dupe", r);
// stable window: selling leaves a gap, the next item keeps its square
R(`closeAllPanels(); openServicePanel("sellPanel", renderSellPanel)`);
const before = G(`stableLayout("sell", itemDisplayOrder(game.inventory), true).map(e => e ? (e.defId || e.id) : null).join(",")`);
const first = G("itemDisplayOrder(game.inventory).findIndex(e => isSellable(e))");
R(`sellItem(game.inventory.indexOf(itemDisplayOrder(game.inventory)[${first}]), 999)`);
const afterL = G(`stableLayout("sell", itemDisplayOrder(game.inventory), true).map(e => e ? (e.defId || e.id) : null)`);
check("sold item leaves a gap in place", afterL[first] === null && afterL.length === before.split(",").length, [before, afterL]);
R(`document.getElementById("sellPanel").hidden = true; delete stableSlots.sell; openServicePanel("sellPanel", renderSellPanel)`);
check("reopen = tidy again", !G(`stableLayout("sell", itemDisplayOrder(game.inventory), true).includes(null)`));
console.log(results.join("\n"));
console.log("errors:", g.errors().concat(g2.errors()).slice(0, 5));
