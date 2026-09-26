const { chromium } = require("playwright");
(async () => {
  const br = await chromium.launch(); const pg = await br.newPage({ viewport: { width: 1280, height: 720 } });
  const errs=[]; pg.on("pageerror", e=>errs.push(String(e)));
  await pg.goto("http://localhost:8765/index.html"); await pg.waitForTimeout(800);
  await pg.evaluate(() => { startGame("Shot", { ...look }, "sword"); document.getElementById("coachModal").hidden = true; game.player.tutorialDone = true; closeTutorial && closeTutorial(); warpToMap(TOWN_TIER); });
  await pg.waitForTimeout(600);
  const out = await pg.evaluate(() => {
    const r=[]; const grab=(label)=>{ r.push(label+": "+talk.segs.map(s=>s.t||s.text||s.s||(typeof s==="string"?s:JSON.stringify(s))).join("")); if(talk.open) closeTalk(); };
    game.player.gold=5; openMerchantDialog(); grab("merchant poor");
    game.player.gold=500; openMerchantDialog(); grab("merchant");
    game.inventory.push({kind:"material", id:"mana_stone", qty:3}); openBlacksmithDialog(); grab("smith");
    renderTownLordDialog(); grab("lord offer");
    game.player.questState.junk_hunt="active"; renderTownLordDialog(); grab("lord active");
    game.player.questState.junk_hunt="completed"; renderTownLordDialog(); grab("lord done");
    renderTempleDialog("confirm"); grab("temple confirm");
    renderTempleDialog("lore"); grab("temple lore");
    renderTempleDialog(); grab("temple");
    return r; });
  console.log(out.join("\n")); console.log("errors", errs);
  await br.close();
})();
