const { chromium } = require("playwright");
(async () => {
  const br = await chromium.launch(); const pg = await br.newPage({ viewport: { width: 1920, height: 1080 } });
  const errs=[]; pg.on("pageerror", e=>errs.push(String(e)));
  await pg.goto("http://localhost:8765/index.html"); await pg.waitForTimeout(800);
  await pg.evaluate(() => { localStorage.clear(); startGame("ค้อนศึก", { ...look }, "heavy"); document.getElementById("coachModal").hidden = true; game.player.tutorialDone = true; closeTutorial && closeTutorial(); warpToMap(TOWN_TIER); });
  await pg.waitForTimeout(1200);
  await pg.screenshot({ path: "t/v61_town.png" });
  const p = await pg.evaluate(() => { const p = game.player; return { x: p.x - game.camera.x, y: p.y - game.camera.y, W: canvas.width }; });
  const k = 1080/720; await pg.screenshot({ path: "t/v61_name.png", clip: { x: Math.max(0,p.x*k-160), y: Math.max(0,p.y*k-260), width: 320, height: 200 } });
  await pg.screenshot({ path: "t/v61_hud.png", clip: { x: 0, y: 0, width: 520, height: 260 } });
  console.log("errors", errs); await br.close();
})();
