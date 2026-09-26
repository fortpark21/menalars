// v65 battle text lanes — a burst of every message kind at once. Run: cd /tmp/mw && NODE_PATH=$(npm root -g) node t/v65_shots.js
const { chromium } = require("playwright");
(async () => {
  const br = await chromium.launch(); const pg = await br.newPage({ viewport: { width: 1600, height: 900 } });
  const errs = []; pg.on("pageerror", e => errs.push(String(e)));
  await pg.goto("http://localhost:8765/index.html"); await pg.waitForTimeout(800);
  const TIER = +(process.env.TIER || 3);
  await pg.evaluate(t => { localStorage.clear(); startGame("ทดสอบ", { ...look }, "sword"); document.getElementById("coachModal").hidden = true; game.player.tutorialDone = true; closeTutorial && closeTutorial();
    warpToMap(t); game.player.level = t * 10; game.player.maxHp = game.player.hp = 99999;
    if(game.inBattle) exitBattle("win"); document.getElementById("victoryPanel").hidden = true;
    enterBattle(game.monsters.find(m => m.alive && MONSTER_DEFS[m.type].isBoss)); game.battle.monster.hp = game.battle.monster.maxHp = 1e9;
    game.battle.nextAttackAt = performance.now() + 1e7; hideArtSplash && hideArtSplash(); }, TIER);
  await pg.waitForTimeout(2600);
  await pg.evaluate(() => {
    spawnBattleMsg("«หินถล่มคู่» ●● ｜ ●●", "#ffb84d", "info");
    spawnBattleMsg("-412", "#ffdd55", "normal");
    spawnBattleMsg("เพอร์เฟกต์คริ! -1834 (x3)", "#7CFFB2", "perfectCrit"); spawnCallout("PERFECT!", "#7CFFB2"); spawnCallout("CRITICAL!", "#ff5f5f");
    spawnBattleMsg("⚡ -96", "#7fd8ff", "lightning");
    spawnBattleMsg("สวนกลับ! -955", "#ffb84d", "counter");
    spawnBattleMsg("โดน! -57", "#ff8080", "playerHurt");
    spawnBattleMsg("🩸+23", "#ff9dc4", "heal");
    spawnBattleMsg("อีก 2 จังหวะตามมา!", "#ffb84d", "info");
  });
  await pg.waitForTimeout(230); await pg.screenshot({ path: "t/v65_burst.png" });
  await pg.waitForTimeout(450); await pg.screenshot({ path: "t/v65_burst_late.png" });
  await pg.evaluate(() => { spawnBattleMsg("พลาด!", "#cfcfcf", "miss"); spawnBattleMsg("หลบเฉียบขาด!", "#bff6ff", "perfectDodge"); spawnCallout("PERFECT DODGE!", "#bff6ff"); spawnBattleMsg("คริ! -640", "#ff5f5f", "crit"); });
  await pg.waitForTimeout(200); await pg.screenshot({ path: "t/v65_dodge.png" });
  console.log("errors", errs); await br.close();
})();
