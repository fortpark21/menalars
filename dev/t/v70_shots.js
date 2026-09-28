// v70: skills of another weapon greyed out on the skill bar + monster levels shown before a first fight.
// Run: cd /tmp/mw && NODE_PATH=$(npm root -g) node t/v70_shots.js
const { chromium } = require("playwright");
(async () => {
  const br = await chromium.launch(); const pg = await br.newPage({ viewport: { width: 1600, height: 900 } });
  const errs = []; pg.on("pageerror", e => errs.push(String(e)));
  await pg.goto("http://localhost:8765/index.html"); await pg.waitForTimeout(800);
  await pg.evaluate(() => { localStorage.clear(); startGame("ทดสอบ", { ...look }, "sword"); document.getElementById("coachModal").hidden = true; game.player.tutorialDone = true; closeTutorial && closeTutorial();
    warpToMap(1); hideArtSplash && hideArtSplash(); if(talk.open) closeTalk(); document.querySelectorAll(".panel").forEach(p => p.hidden = true);
    const bowSkill = Object.keys(SKILL_DEFS).find(k => SKILL_DEFS[k].weaponType === "bow"), swordSkill = Object.keys(SKILL_DEFS).find(k => SKILL_DEFS[k].weaponType === "sword");
    game.player.skillBarSlots[4] = bowSkill; game.player.skillBarSlots[5] = swordSkill;
    const m = game.monsters.find(m => m.alive && m.type === 4); game.player.x = m.x - 120; game.player.y = m.y + 20; game.player.path = null; game.player.targetX = null; });
  await pg.waitForTimeout(1500);
  const r = await pg.evaluate(() => [...document.querySelectorAll("#skillBar .skill-btn")].map(b => (b.classList.contains("weapon-locked") ? "🔒" : "") + (b.textContent || "").trim().slice(0, 12)));
  console.log(r.join(" | "));
  await pg.screenshot({ path: "t/v70_world.png" });
  const bar = await pg.$("#skillBar"); await bar.screenshot({ path: "t/v70_skillbar.png" });
  console.log("errors", errs); await br.close();
})();
