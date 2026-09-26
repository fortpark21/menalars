// v63: real-browser check — music is silent under the victory jingle, reward sounds queue, map track returns. Run: cd /tmp/mw && NODE_PATH=$(npm root -g) node t/v63_audio.js
const { chromium } = require("playwright");
(async () => {
  const br = await chromium.launch({ args:["--autoplay-policy=no-user-gesture-required"] }); const pg = await br.newPage({ viewport:{ width:1600, height:900 } });
  const errs = []; pg.on("pageerror", e => errs.push(String(e)));
  await pg.goto("http://localhost:8765/index.html"); await pg.waitForTimeout(800);
  await pg.mouse.click(10, 10);
  await pg.evaluate(() => { localStorage.clear(); unlockAudio(); startGame("เสียง", { ...look }, "sword"); document.getElementById("coachModal").hidden = true; game.player.tutorialDone = true; closeTutorial && closeTutorial(); warpToMap(1); });
  await pg.waitForTimeout(3000);
  const st = () => pg.evaluate(() => ({ key: music.key, jingle: !!music.jingle, audible: music.els.filter(e => e && !e.paused && e.volume > 0.01).map(e => e.dataset.key), queue: sfxHold.queue.slice() }));
  console.log("map", JSON.stringify(await st()));
  await pg.evaluate(() => { enterBattle(game.monsters.find(m => m.alive && MONSTER_DEFS[m.type].isBoss)); });
  await pg.waitForTimeout(3500); console.log("boss", JSON.stringify(await st()));
  await pg.evaluate(() => { game.player.exp = game.player.expNeeded - 1; exitBattle("win"); });
  await pg.waitForTimeout(1500); console.log("win+1.5s", JSON.stringify(await st()));
  await pg.screenshot({ path: "t/v63_win.png" });
  await pg.waitForTimeout(12000); console.log("win+13.5s", JSON.stringify(await st()));
  console.log("errors", errs); await br.close();
})();
