const { chromium } = require("playwright");
(async () => {
  const br = await chromium.launch(); const pg = await br.newPage({ viewport: { width: 1280, height: 720 } });
  await pg.goto("http://localhost:8765/index.html"); await pg.waitForTimeout(800);
  await pg.evaluate(() => { startGame("Shot", { ...look }, "sword"); document.getElementById("coachModal").hidden = true; game.player.tutorialDone = true; closeTutorial && closeTutorial(); warpToMap(TOWN_TIER); });
  await pg.waitForTimeout(600);
  const shots = [["c10_boss", "temple", "done"]];
  for(const [id, kind, mode] of shots){
    await pg.evaluate(([id, kind, mode]) => { if(talk.open) closeTalk();
      const s = storyState(); s.i = STORY_QUESTS.findIndex(q => q.id === id); s.done = STORY_QUESTS.slice(0, s.i).map(q => q.id);
      s.st = mode === "offer" ? "offer" : "active"; if(mode === "done"){ const q = STORY_QUESTS[s.i]; s.n = 9; s.spots = (q.goal.spots||[]).map(()=>[0,0,1]); }
      const n = game.npcs.find(n => n.kind === kind); game.player.x = n.x; game.player.y = n.y + 40; interactWithNpc(n); }, [id, kind, mode]);
    await pg.waitForTimeout(16000);
    await pg.screenshot({ path: `t/talk_${id}.png` });
  }
  await br.close();
})();
