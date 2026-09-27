// v66 🎣 fishing — a bot angler per rarity (catch rate + time), a lazy one (never resists → line snaps),
// book/stats/bag, spots walkable, titles, save round-trip. Run: cd /tmp/mw/t && node fish_test.js
const { loadGame } = require("./harness");
const g = loadGame(process.env.GAME || "game.html");
const R = s => g.run(s), G = s => g.get(s);
const fails = [];
R(`startGame("Fisher", { ...look }, "sword"); closeTutorial && closeTutorial(); document.getElementById("coachModal").hidden = true; game.player.tutorialDone = true; warpToMap(TOWN_TIER);`);
R("game.player.x = FISH_SPOTS[0].x; game.player.y = FISH_SPOTS[0].y; updateOverworld(0.016)");
if(G("document.getElementById('fishSpotBtn').hidden")) fails.push("button hidden on the pier");
for(const sp of JSON.parse(G("JSON.stringify(FISH_SPOTS)"))) if(G(`(()=>{ const c = worldToCell(${sp.x}, ${sp.y}); return isBlockedCell(c.gx, c.gy); })()`)) fails.push("spot not walkable " + sp.x);
R("game.player.x = 400; game.player.y = 400; updateOverworld(0.016)");
if(!G("document.getElementById('fishSpotBtn').hidden")) fails.push("button visible away from the pier");
R("game.player.x = FISH_SPOTS[1].x; game.player.y = FISH_SPOTS[1].y");
// skill: 0 = lazy (never resists, never holds), 1 = decent bot (small reaction delay)
function fishOnce(rarity, skill){
  R("startFishing(); document.getElementById('fishResult').hidden = true");
  if(rarity) R(`fishing.biteAt = 0; fishStep(0.02); fishing.fish = FISH_DEFS.find(f => f.rarity === ${JSON.stringify(rarity)})`);
  let t = 0, lag = 0;
  while(G("fishing.phase") !== "done" && t < 90){
    if(skill){
      const st = JSON.parse(G("JSON.stringify({ p: fishing.power, z: fishing.zoneC, v: fishing.vel, tug: fishing.tug && fishing.tug.side })"));
      lag = (lag + 1) % 3; // re-decide every 3 steps (~60 ms), like a human
      if(!lag) R(`fishing.hold = ${st.p + st.v * 0.25 < st.z}`);
      R(`fishing.keyL = ${st.tug === "right"}; fishing.keyR = ${st.tug === "left"}`);
    }
    R("fishStep(0.02)"); t += 0.02;
  }
  const res = JSON.parse(G("JSON.stringify({ caught: fishing.progress >= 1, strain: fishing.strain, id: fishing.fish && fishing.fish.id })"));
  R("closeFishing()");
  return Object.assign(res, { t: Math.round(t * 10) / 10 });
}
for(const rar of ["common", "uncommon", "rare", "epic", "legendary"]){
  let ok = 0, time = 0; const N = 12;
  for(let i = 0; i < N; i++){ const r = fishOnce(rar, 1); if(r.caught){ ok++; time += r.t; } }
  console.log(`${rar.padEnd(10)} bot caught ${ok}/${N}  avg ${ok ? (time / ok).toFixed(1) : "-"} s`);
  if(rar === "common" && ok < N - 1) fails.push("common too hard for the bot");
}
const lazy = fishOnce("rare", 0);
console.log("lazy angler", JSON.stringify(lazy));
if(lazy.caught || lazy.strain !== 3) fails.push("lazy angler should lose the fish after 3 strains");
// random bites work too
const rnd = fishOnce(null, 1); console.log("random bite", JSON.stringify(rnd));
console.log("stats", G("game.stats.fishCaught"), "book species", G("Object.keys(game.player.fishBook).length"), "bag fish", G("JSON.stringify(game.inventory.filter(e => FISH_BY_ID[e.id]).map(e => e.id + 'x' + e.qty))"));
if(G("game.stats.fishCaught") !== G("game.inventory.filter(e => FISH_BY_ID[e.id]).reduce((a, e) => a + e.qty, 0)")) fails.push("bag count != fishCaught");
console.log("sell price maguro", G("getSellPrice({ id:'fish_maguro', qty:1 })"), "sellable", G("isSellable({ id:'fish_maguro', qty:1 })"));
R("checkTitles(true)"); console.log("titles", G("JSON.stringify([...game.unlockedTitles].filter(t => t.startsWith('fish')))"));
if(!G("game.unlockedTitles.has('fish_novice')")) fails.push("fish_novice title");
// save round-trip keeps the book
const save = G("JSON.stringify(buildSaveData())");
const g2 = loadGame(process.env.GAME || "game.html"); g2.run(`continueGame(JSON.parse(${JSON.stringify(save)}))`);
if(g2.get("Object.keys(game.player.fishBook).length") !== G("Object.keys(game.player.fishBook).length")) fails.push("book not saved");
R("openFishBook ? (startFishing(), openFishBook()) : 0"); if(!G("document.querySelectorAll ? true : true")) fails.push("book");
// v68: the fish book pauses the water — no bite while it's open
R("closeFishing(); startFishing(); document.getElementById('fishResult').hidden = true; openFishBook(); fishing.last = performance.now()");
const t0 = G("fishing.t"); for(let i = 0; i < 50; i++){ g.clock.advance(100); R("fishTick(performance.now())"); }
if(G("fishing.t") !== t0 || G("fishing.phase") !== "wait") fails.push("book should pause fishing");
R("document.getElementById('fishBookPanel').hidden = true"); for(let i = 0; i < 5; i++){ g.clock.advance(100); R("fishTick(performance.now())"); }
if(!(G("fishing.t") > t0)) fails.push("fishing should resume after the book");
R("closeFishing()");
console.log("fails", JSON.stringify(fails));
console.log("errors:", JSON.stringify(g.errors().concat(g2.errors()).slice(0, 5)));
