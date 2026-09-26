// v64: real-browser check — no fanfare after a normal monster (map music carries on), boss fanfare stops at 7 s,
// new bgm_map02 / bgm_boss load and play. Run: cd /tmp/mw && NODE_PATH=$(npm root -g) node t/v64_audio.js
const { chromium } = require("playwright");
(async () => {
  const br = await chromium.launch({ args:["--autoplay-policy=no-user-gesture-required"] }); const pg = await br.newPage({ viewport:{ width:1600, height:900 } });
  const errs = []; pg.on("pageerror", e => errs.push(String(e)));
  await pg.goto("http://localhost:8765/index.html"); await pg.waitForTimeout(800); await pg.mouse.click(10, 10);
  await pg.evaluate(() => { localStorage.clear(); unlockAudio(); startGame("เสียง", { ...look }, "sword"); document.getElementById("coachModal").hidden = true; game.player.tutorialDone = true; closeTutorial && closeTutorial(); warpToMap(2); game.player.maxHp = game.player.hp = 99999; });
  const st = () => pg.evaluate(() => ({ key: music.key, jingle: !!music.jingle, audible: music.els.filter(e => e && !e.paused && e.volume > 0.01).map(e => e.dataset.key + "@" + Math.round(e.currentTime)) }));
  await pg.waitForTimeout(3000); console.log("map2", JSON.stringify(await st()));
  await pg.evaluate(() => { if(!game.inBattle) enterBattle(game.monsters.find(m => m.alive && !MONSTER_DEFS[m.type].isBoss)); });
  await pg.waitForTimeout(2500); console.log("mob fight", JSON.stringify(await st()));
  await pg.evaluate(() => exitBattle("win")); await pg.waitForTimeout(1500);
  console.log("mob win +1.5s", JSON.stringify(await st()));
  await pg.evaluate(() => { closeSummaryPanel(); if(document.getElementById("battleCanvas").style.display === "block") returnToOverworldView(); });
  await pg.waitForTimeout(500);
  await pg.evaluate(() => { if(game.inBattle) exitBattle("win"); enterBattle(game.monsters.find(m => m.alive && MONSTER_DEFS[m.type].isBoss)); });
  await pg.waitForTimeout(4000); console.log("boss fight", JSON.stringify(await st()));
  await pg.evaluate(() => exitBattle("win")); const t0 = Date.now();
  let stopAt = null;
  for(let i = 0; i < 60; i++){ await pg.waitForTimeout(250); if(!(await pg.evaluate(() => !!music.jingle))){ stopAt = (Date.now() - t0) / 1000; break; } }
  console.log("boss jingle stopped after", stopAt, "s");
  await pg.waitForTimeout(3000); console.log("after boss jingle", JSON.stringify(await st()));
  console.log("failed files", await pg.evaluate(() => [...music.failed]));
  console.log("errors", errs); await br.close();
})();
