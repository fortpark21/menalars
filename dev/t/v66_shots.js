// v66 🎣 fishing screenshots: pier button, reeling with a tug, catch card, fish book. Run: cd /tmp/mw && NODE_PATH=$(npm root -g) node t/v66_shots.js
const { chromium } = require("playwright");
(async () => {
  const br = await chromium.launch(); const pg = await br.newPage({ viewport: { width: 1600, height: 900 } });
  const errs = []; pg.on("pageerror", e => errs.push(String(e)));
  await pg.goto("http://localhost:8765/index.html"); await pg.waitForTimeout(800);
  await pg.evaluate(() => { localStorage.clear(); startGame("ชาวประมง", { ...look }, "sword"); document.getElementById("coachModal").hidden = true; game.player.tutorialDone = true; closeTutorial && closeTutorial();
    warpToMap(TOWN_TIER); hideArtSplash && hideArtSplash(); game.player.x = FISH_SPOTS[0].x; game.player.y = FISH_SPOTS[0].y; }); await pg.waitForTimeout(300); await pg.evaluate(() => { if(talk.open) closeTalk(); document.querySelectorAll(".panel").forEach(p => p.hidden = true); });
  await pg.waitForTimeout(1500); await pg.screenshot({ path: "t/v66_pier.png" });
  await pg.evaluate(() => { startFishing(); fishing.biteAt = 0.3; });
  await pg.waitForTimeout(900);
  await pg.evaluate(() => { fishing.fish = FISH_DEFS.find(f => f.id === "fish_koi"); fishing.progress = 0.46; fishing.strain = 1; fishing.power = fishing.zoneC; fishing.hold = true;
    fishing.tug = { side: "right", start: fishing.t - 0.9, warn: 0.72, ok: 0 }; fishing.nextTugAt = 1e9; fishing.keyL = true; });
  await pg.waitForTimeout(120); await pg.screenshot({ path: "t/v66_reel.png" });
  await pg.evaluate(() => { fishing.tug = { side: "right", start: fishing.t - 0.3, warn: 0.72, ok: 0 }; fishing.keyL = false; });
  await pg.waitForTimeout(100); await pg.screenshot({ path: "t/v68_tug_right.png" });
  await pg.evaluate(() => { fishing.tug = null; fishing.progress = 1; fishFinish(true); });
  await pg.waitForTimeout(600); await pg.screenshot({ path: "t/v66_catch.png" });
  await pg.click("#frBook"); await pg.waitForTimeout(300); await pg.screenshot({ path: "t/v68_book_from_card.png" });
  await pg.click("#fbClose"); await pg.waitForTimeout(200);
  await pg.evaluate(() => { ["fish_siw","fish_kad","fish_tu","fish_fugu","fish_maguro","fish_buek","fish_unagi"].forEach((id, i) => fishBook()[id] = { n: i + 1, best: FISH_BY_ID[id].size[1] }); openFishBook(); });
  await pg.waitForTimeout(300); await pg.hover(".fb-card:nth-child(12)"); await pg.waitForTimeout(200); await pg.screenshot({ path: "t/v66_book.png" });
  console.log("errors", errs); await br.close();
})();
