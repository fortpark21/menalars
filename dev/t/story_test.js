// Plays the whole main-story chain (chapters 1-3) through the real game code in the harness.
const { loadGame } = require("./harness");
const g = loadGame(process.env.GAME || "game.html");
const R = s => g.run(s), G = s => g.get(s);
R(`(()=>{ let a = 99; Math.random = () => { a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; })()`);
R(`startGame("Story", { ...look }, "sword"); closeTutorial && closeTutorial(); document.getElementById("coachModal").hidden = true; game.player.tutorialDone = true;`);
const adv = ms => { for(let i = 0; i < Math.ceil(ms / 100); i++){ g.clock.advance(100); R("loop(performance.now())"); } };
function fight(expr){
  R(`enterBattle(${expr})`);
  for(let i = 0; i < 400 && G("game.inBattle"); i++){
    g.clock.advance(120);
    R(`if(game.battle && !game.battle.victoryAt){ if(performance.now() - game.battle.stats.startedAt > 300) game.battle.monster.hp = Math.min(game.battle.monster.hp, 1);
       battleHoldStartRatio = 0; battleLastDragDirection = game.battle.swordSwipeDirection; battleAttack(); } loop(performance.now())`);
  }
  adv(1300); R("if(!document.getElementById('victoryPanel').hidden || !document.getElementById('defeatPanel').hidden) closeSummaryPanel()");
  R("if(!game.inBattle && document.getElementById('battleCanvas').style.display === 'block') returnToOverworldView()");
  R("game.player.hp = getEffectiveMaxHp(); game.player.sanity = SANITY_MAX;");
  adv(300); R("if(talk.open) closeTalk()"); adv(200); R("if(talk.open) closeTalk()");
}
function pick(label){
  const idx = G(`talk.choices.findIndex(c => c.label.includes(${JSON.stringify(label)}))`);
  if(idx < 0) throw new Error("no choice " + label + " in " + G("JSON.stringify(talk.choices.map(c=>c.label))"));
  R(`talkPick(${idx})`);
}
function talkTo(kind){
  if(G("game.mapTier") !== 0){ R("warpToMap(TOWN_TIER)"); adv(200); }
  R(`if(talk.open) closeTalk(); (()=>{ const n = game.npcs.find(n => n.kind === ${JSON.stringify(kind)}); game.player.x = n.x; game.player.y = n.y + 40; interactWithNpc(n); })()`);
}
const log = [];
R("game.player.level = 40; game.player.atk = 200; game.player.maxHp = 2000; game.player.hp = 2000; game.player.expNeeded = 4000;");
for(let step = 0; step < 260; step++){
  if(G("game.inBattle")){
    for(let i = 0; i < 400 && G("game.inBattle"); i++){ g.clock.advance(120); R(`if(game.battle && !game.battle.victoryAt){ if(performance.now() - game.battle.stats.startedAt > 300) game.battle.monster.hp = Math.min(game.battle.monster.hp, 1); battleHoldStartRatio = 0; battleLastDragDirection = game.battle.swordSwipeDirection; battleAttack(); } loop(performance.now())`); }
    adv(1300); R("closeSummaryPanel(); if(document.getElementById('battleCanvas').style.display === 'block') returnToOverworldView(); game.player.hp = getEffectiveMaxHp(); if(talk.open) closeTalk()");
  }
  const q = JSON.parse(G("JSON.stringify(storyQuest())") || "null");
  if(!q) break;
  const st = G("storyState().st");
  log.push(q.id + ":" + st);
  if(st === "offer"){ talkTo(q.from); pick("รับภารกิจ"); R("closeTalk()"); continue; }
  const gl = q.goal;
  if(gl.type === "talk"){ talkTo(gl.npc); pick(G(`talk.choices[0].label`)); R("if(talk.open) closeTalk()"); continue; }
  if(G("storyReady(storyQuest())") && q.npc){ talkTo(q.npc); pick("ส่งภารกิจ"); R("if(talk.open) closeTalk()"); continue; }
  if(gl.tier && G("game.mapTier") !== gl.tier){ R(`warpToMap(${gl.tier})`); adv(300); }
  if(gl.type === "kill" || gl.type === "win"){ fight(`game.monsters.find(m => m.alive && !MONSTER_DEFS[m.type].isBoss)`); if(gl.type==="win" && !G("storyReady(storyQuest())") && G("storyQuest().id")===q.id) R("storyState().n = 1; storyStatTick(); storyFieldComplete()"); }
  else if(gl.type === "boss"){ R("game.monsters.filter(m => MONSTER_DEFS[m.type].isBoss).forEach(m => m.alive = true)"); fight(`game.monsters.find(m => m.alive && MONSTER_DEFS[m.type].isBoss)`); }
  else if(gl.type === "drop"){ R(`(()=>{ const m = game.monsters.find(m => m.type === ${gl.slot}); m.alive = true; })()`); fight(`game.monsters.find(m => m.type === ${gl.slot})`); }
  else if(gl.type === "stat"){ R(`game.stats.${gl.key} = (game.stats.${gl.key} || 0) + ${gl.n}`); adv(200); }
  else if(gl.type === "give"){ R(`for(let i = 0; i < ${gl.n}; i++) addToInventory(${JSON.stringify(gl.item)})`); }
  else if(gl.type === "meditate"){ R("game.player.sanity = 5; startMeditating()"); adv(200000); R("stopMeditating()"); }
  else if(gl.type === "spot"){
    adv(200); R("if(talk.open) closeTalk()");
    const n = G("(storyState().spots || []).length");
    for(let k = 0; k < n; k++){
      R(`(()=>{ const sp = storyState().spots[${k}]; if(sp[2]) return; game.player.x = sp[0]; game.player.y = sp[1]; })()`);
      adv(100);
      if(G("talk.open") && G("talk.choices.length > 1")) R("talkPick(0)");
      adv(100); R("if(talk.open) closeTalk()"); adv(100); R("if(talk.open) closeTalk()");
    }
  }
  R("if(talk.open) closeTalk()"); adv(100); R("if(talk.open) closeTalk()");
}
const out = JSON.parse(G(`JSON.stringify({ story: game.player.story, gold: game.player.gold, lv: game.player.level, titles: [...game.unlockedTitles].filter(t => /story|whisper/.test(t)),
  pillars: storyPillarsLit(), inv: game.inventory.filter(e => e.kind !== "equipment").map(e => e.id + "x" + e.qty), eq: game.inventory.filter(e => e.kind === "equipment").length })`));
console.log(log.join(" "));
console.log(JSON.stringify({ i: out.story.i, done: out.story.done.length, ch: out.story.ch, gold: out.gold, lv: out.lv, titles: out.titles, pillars: out.pillars, inv: out.inv, eq: out.eq }));
const save = G("JSON.stringify(buildSaveData())");
const g2 = loadGame(process.env.GAME || "game.html");
g2.run(`continueGame(JSON.parse(${JSON.stringify(save)}))`);
console.log("reload story i:", g2.get("storyState().i"), "tracker:", g2.byId("storyTracker").innerHTML.replace(/<[^>]+>/g, " ").slice(0, 120));
console.log("errors:", g.errors().concat(g2.errors()).slice(0, 5));
