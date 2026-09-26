const { chromium } = require("playwright");
(async () => {
  const br = await chromium.launch(); const pg = await br.newPage({ viewport: { width: 1280, height: 720 } });
  const errs=[]; pg.on("pageerror", e=>errs.push(String(e)));
  await pg.goto("http://localhost:8765/index.html"); await pg.waitForTimeout(800);
  await pg.evaluate(() => { startGame("Shot", { ...look }, "orb"); document.getElementById("coachModal").hidden = true; game.player.tutorialDone = true; closeTutorial && closeTutorial(); warpToMap(TOWN_TIER); });
  await pg.waitForTimeout(500);
  for(const i of [7,10,12]){ await pg.evaluate(i=>{ openTutorial(); tutorialStep=i; renderTutorialStep(); }, i); await pg.waitForTimeout(300); await pg.screenshot({ path: `t/sys04_guide${i+1}.png` }); await pg.evaluate(()=>closeTutorial()); }
  await pg.evaluate(()=>{ document.getElementById("statusBtn").click(); }); await pg.waitForTimeout(400); await pg.screenshot({ path: "t/sys04_stat.png" });
  const btn = await pg.evaluate(()=>[...document.querySelectorAll("button")].filter(b=>/สกิล/.test(b.textContent)).map(b=>b.id+"|"+b.textContent.trim()).slice(0,6));
  console.log(btn); console.log("errors", errs); await br.close();
})();
