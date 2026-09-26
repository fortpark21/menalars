// v62: every map boss uses its own signature combo (BOSS_MOVES). Fights each map boss in the harness and
// records one full combo: hit count, where the pauses fall, mirrored sides, feint, and that attacking is
// blocked during a burst but allowed during a pause. Run: cd /tmp/mw/t && node boss_move_test.js
const { loadGame } = require("./harness");
const g = loadGame(process.env.GAME || "game.html");
const R = s => g.run(s), G = s => g.get(s);
R(`startGame("Boss", { ...look }, "sword"); closeTutorial && closeTutorial(); document.getElementById("coachModal").hidden = true; game.player.tutorialDone = true;`);
const fails = [];
for(let tier = 1; tier <= 10; tier++){
  R(`warpToMap(${tier}); game.player.level = ${tier * 10}; game.player.maxHp = 999999; game.player.hp = 999999;`);
  R(`enterBattle(game.monsters.find(m => m.alive && MONSTER_DEFS[m.type].isBoss)); game.battle.monster.hp = game.battle.monster.maxHp = 1e9;`);
  const move = JSON.parse(G("JSON.stringify(game.battle.bossMove)"));
  let seq = "", sides = [], feints = 0, prevTele = false, prevPause = false, started = false, blocked = 0, pauseHits = 0;
  for(let i = 0; i < 1500; i++){
    g.clock.advance(20); R("loop(performance.now())");
    if(!G("game.inBattle")){ fails.push(tier + ": battle ended"); break; }
    const tele = G("game.battle.telegraphSide !== null"), pause = G("game.battle.comboPauseUntil > 0"), active = G("game.battle.comboActive");
    if(tele && !prevTele){ started = true; seq += "●"; if(G("game.battle.telegraphFeintAt > 0")) feints++; }
    if(prevTele && !tele) sides.push(G("game.battle.comboLastSide"));
    if(pause && !prevPause){ seq += "|";
      // attack during the pause must land
      const before = G("game.battle.stats.normalHits + game.battle.stats.perfectHits + game.battle.stats.misses");
      R("game.battle.lastPlayerAttack = 0; battleAttack()");
      if(G("game.battle.stats.normalHits + game.battle.stats.perfectHits + game.battle.stats.misses") > before) pauseHits++;
    }
    if(active && tele){ // attacking during a burst is blocked
      const before = G("game.battle.stats.normalHits + game.battle.stats.perfectHits + game.battle.stats.misses");
      R("game.battle.lastPlayerAttack = 0; battleAttack()");
      if(G("game.battle.stats.normalHits + game.battle.stats.perfectHits + game.battle.stats.misses") > before) blocked++;
    }
    prevTele = tele; prevPause = pause;
    if(started && !active && !pause && !tele) break;
  }
  const want = move.groups.map(n => "●".repeat(n)).join("|");
  const breaks = sides.filter((s, i) => i > 0 && s === sides[i - 1]).length, alt = breaks <= (move.feint ? 1 : 0); // a feint flips the mirrored side once — that is the trick
  const line = `map ${tier} «${move.name}» want ${want} got ${seq} sides ${sides.map(s => s[0]).join("")} feints ${feints} pauseAttack ${pauseHits}/${move.groups.length - 1} burstLeak ${blocked}`;
  console.log(line);
  if(seq !== want) fails.push(tier + ": pattern");
  if(pauseHits !== move.groups.length - 1) fails.push(tier + ": pause attack");
  if(blocked) fails.push(tier + ": attack not blocked in burst");
  if(move.alternate && !alt) fails.push(tier + ": not alternating");
  if(!!move.feint !== (feints === 1)) fails.push(tier + ": feint count " + feints);
  R("exitBattle('flee')"); R("if(document.getElementById('battleCanvas').style.display === 'block') returnToOverworldView()");
}
// the letter spy (fake town lord) keeps the old 3-hit combo
R("warpToMap(TOWN_TIER); letterSpyFight()");
console.log("spy boss move", G("game.battle.bossMove.name"), G("game.battle.comboTotal"));
if(G("game.battle.comboTotal") !== 3) fails.push("spy: combo total");
console.log("fails", JSON.stringify(fails));
console.log("errors:", JSON.stringify(g.errors().slice(0, 5)));
