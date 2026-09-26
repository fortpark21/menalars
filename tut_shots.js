const { chromium } = require("playwright");
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport:{ width:1280, height:720 } });
  const errs = []; p.on("pageerror", e => errs.push(String(e)));
  await p.goto("http://localhost:8765/index.html");
  await p.waitForTimeout(500);
  await p.evaluate(() => { startGame("T2", { ...look }, "bow"); });
  await p.click("#cmSkipBtn"); // skip as a new char
  const skipped = await p.evaluate(() => ({ done: game.player.tutorialDone, active: TUT.active }));
  await p.waitForTimeout(2500);
  await p.evaluate(() => { closeTalk && talk.open && closeTalk(); openTutorial(); });
  await p.waitForTimeout(300);
  await p.screenshot({ path: "/tmp/mw/t/tut/help_card.png" });
  await p.click("#tutorialTrainBtn"); await p.waitForTimeout(300);
  await p.screenshot({ path: "/tmp/mw/t/tut/replay_intro.png" });
  await p.click("#cmGoBtn"); await p.waitForTimeout(800);
  const s1 = await p.evaluate(() => ({ step: tutStep().id, inBattle: game.inBattle }));
  await p.evaluate(() => { TUT.i = TUT.steps.findIndex(s => s.id === "input") - 1; tutNext(); });
  await p.waitForTimeout(600);
  await p.screenshot({ path: "/tmp/mw/t/tut/bow_input.png" });
  await p.evaluate(() => { TUT.i = TUT.steps.findIndex(s => s.id === "dodge") - 1; tutNext(); });
  for(let i = 0; i < 80; i++){ const t = await p.evaluate(() => game.battle && game.battle.telegraphSide && (performance.now() - game.battle.telegraphStart) / game.battle.telegraphTotalMs); if(t && t > 0.5) break; await p.waitForTimeout(80); }
  await p.screenshot({ path: "/tmp/mw/t/tut/dodge_tele.png" });
  await p.evaluate(() => { TUT.i = TUT.steps.findIndex(s => s.id === "counter") - 1; tutNext(); });
  for(let i = 0; i < 80; i++){ const t = await p.evaluate(() => game.battle && game.battle.telegraphSide && (game.battle.telegraphStart + game.battle.telegraphTotalMs - performance.now())); if(t && t < 260) break; await p.waitForTimeout(30); }
  await p.screenshot({ path: "/tmp/mw/t/tut/counter_now.png" });
  await p.evaluate(() => { TUT.i = TUT.steps.findIndex(s => s.id === "stun") - 1; tutNext(); });
  await p.waitForTimeout(500);
  await p.screenshot({ path: "/tmp/mw/t/tut/stun_label.png" });
  // quit mid-fight: back to overworld, nothing changed
  const hpBefore = await p.evaluate(() => TUT.savedHp);
  await p.click("#coachQuitBtn"); await p.waitForTimeout(600);
  const after = await p.evaluate(() => ({ inBattle: game.inBattle, active: TUT.active, coach: document.getElementById("coach").hidden, ptr: document.querySelectorAll(".coach-pointer").length, hp: game.player.hp, done: game.player.tutorialDone }));
  // a low-sanity replay is refused
  await p.evaluate(() => { game.player.sanity = 40; tutBegin({}); });
  const low = await p.evaluate(() => ({ modal: !document.getElementById("coachModal").hidden, toast: document.getElementById("toast").textContent }));
  console.log(JSON.stringify({ skipped, s1, hpBefore, after, low, errs }, null, 1));
  await b.close();
})();
