// v52 hand-held training: drive every lesson with real mouse/keyboard input, screenshot each step.
const { chromium } = require("playwright");
const WEAPON = process.env.W || "sword";
const OUT = "/tmp/mw/t/tut/";
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport:{ width:1280, height:720 } });
  const errs = []; p.on("pageerror", e => errs.push(String(e))); p.on("console", m => { if(m.type()==="error" && !/Failed to load resource|assets/.test(m.text())) errs.push(m.text()); });
  await p.goto("http://localhost:8765/index.html");
  await p.waitForTimeout(600);
  await p.evaluate(w => { startGame("Trainee", { ...look }, w); }, WEAPON);
  await p.waitForTimeout(800);
  const log = [];
  const state = () => p.evaluate(() => ({ active: TUT.active, step: tutStep() && tutStep().id, count: TUT.count, passing: TUT.passing, inBattle: game.inBattle,
    modal: !document.getElementById("coachModal").hidden, tip: document.getElementById("coachTip").hidden ? "" : document.getElementById("coachTip").textContent }));
  log.push(["start", await state()]);
  await p.screenshot({ path: OUT + WEAPON + "_0_intro.png" });
  await p.click("#cmGoBtn");
  await p.waitForTimeout(3500); // map intro splash
  await p.screenshot({ path: OUT + WEAPON + "_1_walk.png" });
  // click the marker on screen
  const toScreen = (x, y) => p.evaluate(([x, y]) => { const r = canvas.getBoundingClientRect(); return { x: r.left + (x - game.camera.x) * r.width / canvas.width, y: r.top + (y - game.camera.y) * r.height / canvas.height }; }, [x, y]);
  let mk = await p.evaluate(() => TUT.marker);
  let s = await toScreen(mk.x, mk.y); await p.mouse.click(s.x, s.y);
  await p.waitForTimeout(3500);
  log.push(["after walk", await state()]);
  await p.screenshot({ path: OUT + WEAPON + "_2_engage.png" });
  const dm = await p.evaluate(() => TUT.dummy);
  s = await toScreen(dm.x, dm.y - 20); await p.mouse.click(s.x, s.y);
  await p.waitForTimeout(4000);
  log.push(["after engage", await state()]);
  await p.screenshot({ path: OUT + WEAPON + "_3_gauge.png" });

  const canvasBox = await p.evaluate(() => { const r = battleCanvas.getBoundingClientRect(); return { x: r.left, y: r.top, w: r.width, h: r.height, cw: battleCanvas.width, ch: battleCanvas.height }; });
  const cv = (x, y) => ({ x: canvasBox.x + x * canvasBox.w / canvasBox.cw, y: canvasBox.y + y * canvasBox.h / canvasBox.ch });
  // gauge ratio now and the zone
  const gaugeInfo = () => p.evaluate(() => { const b = game.battle, st = computePlayerBattleStats(game.player.level), now = performance.now();
    const cd = now < b.hasteUntil ? st.cooldown * 0.6 : st.cooldown; return { r: (now - b.lastPlayerAttack) / cd, zs: getPerfectZoneStart(st.zoneWiden, cd), ze: st.perfectZoneEnd, cd }; });
  const waitRatio = async target => { for(let i = 0; i < 200; i++){ const g = await gaugeInfo(); if(g.r >= target) return g; await p.waitForTimeout(Math.max(5, Math.min(60, (target - g.r) * g.cd - 20))); } };
  await p.evaluate(() => {
    window.__cv = (x, y) => { const r = battleCanvas.getBoundingClientRect(); return { clientX: r.left + x * r.width / battleCanvas.width, clientY: r.top + y * r.height / battleCanvas.height }; };
    window.__ev = (target, type, x, y) => target.dispatchEvent(new MouseEvent(type, { bubbles: true, button: 0, ...window.__cv(x, y) }));
    window.__zone = () => { const b = game.battle, st = computePlayerBattleStats(game.player.level), now = performance.now();
      const cd = now < b.hasteUntil ? st.cooldown * 0.6 : st.cooldown; return { r: (now - b.lastPlayerAttack) / cd, zs: getPerfectZoneStart(st.zoneWiden, cd), ze: st.perfectZoneEnd }; };
    // wait (rAF) until the gauge is mid-Perfect-zone, then run the gesture synchronously
    window.__atZone = (gesture) => new Promise(res => { const tick = () => { if(!game.battle) return res(false); const z = window.__zone();
      if(z.r > z.ze + 0.01){ window.__ev(battleCanvas, "mousedown", 700, 300); window.__ev(window, "mouseup", 700, 300); window.__ev(battleCanvas, "click", 700, 300); } // overshot: swing to reset
      if(z.r >= (z.zs + z.ze) / 2 - 0.02 && z.r <= z.ze){ gesture(); return res(true); } requestAnimationFrame(tick); }; tick(); });
    window.__plain = () => window.__atZone(() => { window.__ev(battleCanvas, "mousedown", 700, 300); window.__ev(window, "mouseup", 700, 300); window.__ev(battleCanvas, "click", 700, 300); });
  });
  const hitPerfect = async (prep) => { if(prep) await prep(); else await p.evaluate(() => window.__plain()); await p.waitForTimeout(120); };

  // lesson: gauge — one early click (should tip), then 3 normal hits
  { const c = cv(700, 300); await p.waitForTimeout(100); await p.mouse.click(c.x, c.y); log.push(["early tip", (await state()).tip]); }
  for(let i = 0; i < 3; i++){ await waitRatio(1.0); const c = cv(700, 300); await p.mouse.click(c.x, c.y); await p.waitForTimeout(200); }
  await p.waitForTimeout(1500);
  log.push(["after gauge", await state()]);
  await p.screenshot({ path: OUT + WEAPON + "_4_perfect.png" });
  for(let i = 0; i < 3; i++) await hitPerfect();
  await p.waitForTimeout(1500);
  log.push(["after perfect", await state()]);
  await p.screenshot({ path: OUT + WEAPON + "_5_input.png" });
  // weapon input
  for(let i = 0; i < 4 && (await state()).step === "input"; i++){
    await p.evaluate(W => window.__atZone(() => {
      const b = game.battle, ev = window.__ev;
      if(W === "sword"){ const d = { up:[0,-1], down:[0,1], left:[-1,0], right:[1,0] }[b.swordSwipeDirection];
        ev(battleCanvas, "mousedown", 640, 330); ev(window, "mousemove", 640 + d[0]*60, 330 + d[1]*60); ev(window, "mousemove", 640 + d[0]*120, 330 + d[1]*120);
        ev(window, "mouseup", 640 + d[0]*120, 330 + d[1]*120); ev(battleCanvas, "click", 640 + d[0]*120, 330 + d[1]*120); }
      else if(W === "bow"){ const mx = battleCanvas.width * 0.62, my = battleCanvas.height * battleMonYFrac; const c = getBowZoneCircles(b, mx, my)[b.bowTargetZone][0];
        ev(battleCanvas, "mousedown", c.x, c.y); ev(window, "mouseup", c.x, c.y); ev(battleCanvas, "click", c.x, c.y); }
      else if(W === "orb"){ const shape = b.orbGestureShape, full = shape === "circle", start = full ? 0 : (shape === "semicircle" ? Math.PI : 0), deg = full ? 330 : 175;
        const pts = []; for(let k = 0; k <= 30; k++){ const a = start + (deg * Math.PI / 180) * k / 30; pts.push([640 + 90 * Math.cos(a), 330 + 90 * Math.sin(a)]); }
        ev(battleCanvas, "mousedown", ...pts[0]); pts.forEach(q => ev(window, "mousemove", ...q)); ev(window, "mouseup", ...pts[pts.length-1]); ev(battleCanvas, "click", ...pts[pts.length-1]); }
      else if(W === "heavy"){ // hammer: the press must START early — fake it by rewinding the recorded press ratio
        ev(battleCanvas, "mousedown", 700, 300); battleHoldStartRatio = 0.1; ev(window, "mouseup", 700, 300); ev(battleCanvas, "click", 700, 300); }
    }), WEAPON);
    await p.waitForTimeout(150);
    log.push(["input try", await state()]);
  }
  await p.waitForTimeout(1500);
  log.push(["after input", await state()]);
  await p.screenshot({ path: OUT + WEAPON + "_6_skill.png" });
  const key = await p.evaluate(() => String(TUT.skillSlot + 1));
  await p.keyboard.press("Digit" + key);
  await p.waitForTimeout(1500);
  log.push(["after skill", await state()]);
  // dodge lesson: react to telegraphs with the right key
  const dodgeLoop = async (untilStep, late) => {
    for(let i = 0; i < 400; i++){
      const t = await p.evaluate(() => { const b = game.battle; if(!b) return null; return { side: b.telegraphSide, left: b.telegraphSide ? b.telegraphStart + b.telegraphTotalMs - performance.now() : 0, cw: performance.now() < b.counterWindowUntil, step: tutStep() && tutStep().id }; });
      if(!t || t.step !== untilStep) return;
      if(t.cw){ const c = cv(700, 300); await p.mouse.click(c.x, c.y); }
      else if(t.side && (!late || t.left < 180)){
        if(i === 3) await p.screenshot({ path: OUT + WEAPON + "_" + untilStep + "_tele.png" });
        await p.keyboard.press(t.side === "left" ? "KeyD" : "KeyA"); await p.waitForTimeout(250);
      }
      await p.waitForTimeout(40);
    }
  };
  await p.screenshot({ path: OUT + WEAPON + "_7_dodge.png" });
  await dodgeLoop("dodge", false);
  await p.waitForTimeout(1400);
  log.push(["after dodge", await state()]);
  await dodgeLoop("counter", true);
  await p.waitForTimeout(1400);
  log.push(["after counter", await state()]);
  await p.screenshot({ path: OUT + WEAPON + "_8_stun.png" });
  for(let i = 0; i < 40 && (await state()).step === "stun"; i++){
    const stunned = await p.evaluate(() => performance.now() < game.battle.stunnedUntil);
    if(stunned){ const c = cv(700, 300); await p.mouse.click(c.x, c.y); await p.waitForTimeout(110); }
    else await hitPerfect();
  }
  await p.waitForTimeout(1500);
  log.push(["after stun", await state()]);
  await p.screenshot({ path: OUT + WEAPON + "_9_final.png" });
  // final — hit perfects + dodge until done
  for(let i = 0; i < 120; i++){
    const st = await state(); if(st.step !== "final") break;
    const t = await p.evaluate(() => { const b = game.battle; return b && { side: b.telegraphSide, left: b.telegraphSide ? b.telegraphStart + b.telegraphTotalMs - performance.now() : 0, stunned: performance.now() < b.stunnedUntil }; });
    if(!t) break;
    if(t.side && t.left < 500){ await p.keyboard.press(t.side === "left" ? "KeyD" : "KeyA"); await p.waitForTimeout(300); continue; }
    if(t.stunned){ const c = cv(700, 300); await p.mouse.click(c.x, c.y); await p.waitForTimeout(110); continue; }
    await hitPerfect();
  }
  await p.waitForTimeout(2500);
  log.push(["after final", await state()]);
  await p.screenshot({ path: OUT + WEAPON + "_10_done.png" });
  const after = await p.evaluate(() => ({ done: game.player.tutorialDone, stats: game.stats.perfectHits, kills: game.stats.kills, best: game.stats.bestPerfectStreak, mastery: game.player.mastery, sanity: game.player.sanity, gold: game.player.gold, exp: game.player.exp, inv: game.inventory.length, hp: game.player.hp, story: !!storyPendingScene, encountered: [...game.encounteredMonsters] }));
  console.log(JSON.stringify({ log, after }, null, 1));
  if(await p.isVisible("#cmGoBtn")) await p.click("#cmGoBtn"); await p.waitForTimeout(1200);
  const storyOpen = await p.evaluate(() => talk.open);
  await p.screenshot({ path: OUT + WEAPON + "_11_story.png" });
  console.log(JSON.stringify({ log, after, storyOpen, errs: errs.slice(0, 6) }, null, 1));
  await b.close();
})();
