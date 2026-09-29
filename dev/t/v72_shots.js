// v72 sharp rendering: same scene at 2560×1440 with ⚙️ ภาพคมชัดสูง on/off (town, map 3, battle). Run: cd /tmp/mw && NODE_PATH=$(npm root -g) node t/v72_shots.js
const { chromium } = require("playwright");
(async () => {
  const br = await chromium.launch();
  const errs = [];
  for(const sharp of [true, false]){
    const pg = await br.newPage({ viewport: { width: 2560, height: 1440 } });
    pg.on("pageerror", e => errs.push(String(e)));
    await pg.goto("http://localhost:8765/index.html"); await pg.waitForTimeout(800);
    await pg.evaluate((sharp) => { localStorage.clear(); OPT.sharp = sharp; startGame("คมชัด", { ...look }, "sword"); document.getElementById("coachModal").hidden = true; game.player.tutorialDone = true; closeTutorial && closeTutorial(); hideArtSplash && hideArtSplash(); if(talk.open) closeTalk(); document.querySelectorAll(".panel").forEach(p => p.hidden = true); resizeCanvas(); }, sharp);
    await pg.waitForTimeout(1500);
    const info = await pg.evaluate(() => ({ S: RENDER_SCALE, lw: canvas.width, lh: canvas.height, cw: canvas.clientWidth }));
    console.log("sharp", sharp, info);
    await pg.screenshot({ path: `t/v72/town_${sharp ? "sharp" : "old"}.png` });
    await pg.evaluate(() => { warpToMap(3); hideArtSplash && hideArtSplash(); }); await pg.waitForTimeout(1500);
    await pg.screenshot({ path: `t/v72/map3_${sharp ? "sharp" : "old"}.png` });
    await pg.evaluate(() => { const m = game.monsters.find(m => m.alive); enterBattle(m); }); await pg.waitForTimeout(1800);
    await pg.screenshot({ path: `t/v72/battle_${sharp ? "sharp" : "old"}.png` });
    await pg.close();
  }
  console.log("errors", errs); await br.close();
})();
