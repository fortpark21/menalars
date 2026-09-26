const { loadGame } = require('./harness'); const g = loadGame('game.html'); const R=s=>g.run(s), G=s=>g.get(s);
R('startGame("S", { ...look }, "sword"); closeTutorial && closeTutorial(); document.getElementById("coachModal").hidden = true; game.player.tutorialDone = true; warpToMap(TOWN_TIER); game.player.sanity = 40;');
R('(()=>{ const n = game.npcs.find(n => n.kind === "monk"); game.player.x = n.x; game.player.y = n.y + 40; interactWithNpc(n); })()');
R('talkPick(talk.choices.findIndex(c=>c.label.includes("พระ")))');
console.log('active', G('monkGame.active'));
for(let i=0;i<660;i++){ g.clock.advance(100); R('monkTick(performance.now())');
  R('(()=>{ const near = monkGame.mons.filter(m=>Math.hypot(m.x-monkGame.W/2, m.y-monkGame.H*0.56) < 250); if(near.length && Math.random()<0.8){ const m=near[0]; monkGame.mons.splice(monkGame.mons.indexOf(m),1); monkGame.killed++; } })()');
}
console.log('done', G('monkGame.done'), 'killed', G('monkGame.killed'), 'leaked', G('monkGame.leaked'), 'sanity', G('Math.round(game.player.sanity)'), 'buff', G('JSON.stringify(game.player.monkBuff)'), G('document.getElementById("mgTitle").textContent'));
R('closeMonkGame()');
const s0 = G('game.player.sanity'); R('drainSanity(10)'); console.log('drain blocked', G('game.player.sanity') === s0, 'rareMult', G('monkRareMult()'));
R('(()=>{ const n = game.npcs.find(n => n.kind === "monk"); interactWithNpc(n); })()'); console.log('choice disabled', G('talk.choices.find(c=>c.label.includes("พระ")).disabled'), G('talk.choices.find(c=>c.label.includes("พระ")).sub'));
// quit early = no buff
R('delete game.player.monkBuff; if(talk.open) closeTalk(); startMonkGame()'); for(let i=0;i<100;i++){ g.clock.advance(100); R('monkTick(performance.now())'); }
R('finishMonkGame(false)'); console.log('quit → buff', G('!!game.player.monkBuff'), G('document.getElementById("mgTitle").textContent'));
console.log('errors', g.errors().slice(0,3));
