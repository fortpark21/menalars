// v62 boss signature moves — screenshots: combo start message + "เปิดช่อง!" pause callout (map 9 boss)
// Run: cd /tmp/mw && NODE_PATH=$(npm root -g) node t/v62_shots.js
const { chromium } = require("playwright");
(async () => {
  const br = await chromium.launch(); const pg = await br.newPage({ viewport: { width: 1600, height: 900 } });
  const errs = []; pg.on("pageerror", e => errs.push(String(e)));
  await pg.goto("http://localhost:8765/index.html"); await pg.waitForTimeout(800);
  const TIER = +(process.env.TIER || 9);
  await pg.evaluate(t => { localStorage.clear(); startGame("ทดสอบบอส", { ...look }, "sword"); document.getElementById("coachModal").hidden = true; game.player.tutorialDone = true; closeTutorial && closeTutorial();
    warpToMap(t); game.player.level = t * 10; game.player.maxHp = game.player.hp = 99999;
    enterBattle(game.monsters.find(m => m.alive && MONSTER_DEFS[m.type].isBoss)); game.battle.monster.hp = game.battle.monster.maxHp = 1e9; }, TIER);
  await pg.waitForFunction(() => game.battle && game.battle.comboActive && game.battle.telegraphSide, null, { timeout: 15000 });
  await pg.waitForTimeout(250); await pg.screenshot({ path: "t/v62_combo_start.png" });
  await pg.waitForFunction(() => game.battle && game.battle.comboPauseUntil > 0, null, { timeout: 15000 });
  await pg.waitForTimeout(250); await pg.screenshot({ path: "t/v62_pause.png" });
  console.log("hint:", await pg.evaluate(() => document.getElementById("hint").textContent));
  console.log("errors", errs); await br.close();
})();
