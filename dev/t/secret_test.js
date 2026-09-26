const { chromium } = require("playwright");
(async () => {
  const br = await chromium.launch(); const pg = await br.newPage({ viewport: { width: 1280, height: 720 } });
  const errs=[]; pg.on("pageerror", e=>errs.push(String(e)));
  await pg.goto("http://localhost:8765/index.html"); await pg.waitForTimeout(800);
  await pg.evaluate(() => { localStorage.clear(); startGame("Sec", { ...look }, "sword"); document.getElementById("coachModal").hidden = true; game.player.tutorialDone = true; closeTutorial && closeTutorial(); warpToMap(1); });
  await pg.waitForTimeout(400);
  const gen = await pg.evaluate(() => {
    const r = { counts:{}, maxLetters:0, sizes:new Set() };
    for(let i=0;i<3000;i++){ const L = generateRandomSecretLocations(1); r.sizes.add(L.length);
      const lt = L.filter(l => SECRET_LOCATION_DEFS[l.defId].letter).length; r.maxLetters = Math.max(r.maxLetters, lt);
      const ids = L.map(l=>l.defId); if(new Set(ids).size !== ids.length) r.dup = true;
      ids.forEach(id => r.counts[id] = (r.counts[id]||0)+1); }
    r.sizes = [...r.sizes]; return r; });
  console.log("gen", JSON.stringify(gen));
  // every kind once
  const out = await pg.evaluate(async () => {
    const res = [];
    const p = game.player;
    const run = (defId, pick) => {
      const loc = { id:"t_"+defId, defId, x:p.x+10, y:p.y, discovered:false, used:false };
      game.secretLocations.push(loc);
      const before = { gold:p.gold, san:p.sanity, inv: JSON.stringify(game.inventory.map(e=>[e.id||e.defId,e.qty])) };
      interactWithLocation(loc);
      const ch = talk.choices ? talk.choices.map(c=>c.label) : null;
      if(pick != null && talk.choices){ const c = talk.choices.find(c=>c.label===pick); if(c) c.onPick(); }
      const txt = talk.segs ? talk.segs.map(s=>(s.g||[]).join("")).join("") : "";
      const extra = document.querySelector("#talkDialog .tk-reward") ? document.querySelector("#talkDialog .tk-reward").textContent : "";
      res.push({ defId, choices: ch, used: loc.used, gold: p.gold-before.gold, san: Math.round(p.sanity-before.san), reward: extra, inBattle: game.inBattle, revealed: game.secretLocations.filter(l=>l.revealed).length });
      if(game.inBattle){ res[res.length-1].mimic = !!game.battle && !!(game.battle.monster||{}).mimic; }
      if(talk.open) closeTalk();
    };
    p.sanity = 60;
    run("mana_vein"); run("mana_flower"); run("mana_pool","ดื่มน้ำจากบ่อ"); run("echo_voice","ฟังเขาจนจบ"); run("echo_voice","ปลดปล่อยเขา");
    run("roadside_shrine","สวดภาวนา"); res.push({ chip: document.getElementById("hudBuff").textContent });
    run("watchtower");
    for(let i=0;i<6 && !game.inBattle;i++) run("shaking_chest","เปิดหีบ");
    run("messenger_bag"); run("strange_tree");
    return res; });
  out.forEach(o => console.log(JSON.stringify(o)));
  // win the mimic fight if we're in it
  const mim = await pg.evaluate(async () => {
    if(!game.inBattle) return "no mimic in 6 tries";
    const m = game.battle && game.battle.monster; const g0 = game.player.gold, s0 = game.stats.chestsOpened, n0 = game.inventory.length;
    m.hp = 0; exitBattle("win");
    return { mimic: !!(m && m.mimic), gold: game.player.gold - g0, chests: game.stats.chestsOpened - s0, newItems: game.inventory.length - n0 };
  });
  console.log("mimic", JSON.stringify(mim));
  // persistence across reload
  const before = await pg.evaluate(() => { warpToMap(2); saveGameNow(); return game.secretLocations.map(l=>l.defId+"@"+Math.round(l.x)); });
  await pg.reload(); await pg.waitForTimeout(900);
  const after = await pg.evaluate(() => { const d = readSave(); continueGame(d); return game.secretLocations.map(l=>l.defId+"@"+Math.round(l.x)); });
  console.log("persist", JSON.stringify(before) === JSON.stringify(after), before.length);
  await pg.evaluate(() => { const l = game.secretLocations[0]; l.revealed = true; renderMinimap(); });
  await pg.screenshot({ path: "t/secret_mm.png" });
  console.log("errors", errs); await br.close();
})();
