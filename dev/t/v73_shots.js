// v73 painted icons: HUD/menu, bag with items + gear, weapon skill tree, skill bar. Run: cd /tmp/mw && NODE_PATH=$(npm root -g) node t/v73_shots.js
const { chromium } = require("playwright");
(async () => {
  const br = await chromium.launch(); const pg = await br.newPage({ viewport: { width: 1920, height: 1080 } });
  const errs = []; pg.on("pageerror", e => errs.push(String(e))); pg.on("console", m => { if(m.type() === "warning" && /missing picture/.test(m.text())) errs.push(m.text()); });
  await pg.goto("http://localhost:8765/index.html"); await pg.waitForTimeout(800);
  await pg.evaluate(() => { localStorage.clear(); startGame("ไอคอน", { ...look }, "sword"); document.getElementById("coachModal").hidden = true; game.player.tutorialDone = true; closeTutorial && closeTutorial(); hideArtSplash && hideArtSplash(); if(talk.open) closeTalk(); document.querySelectorAll(".panel").forEach(p => p.hidden = true); });
  await pg.evaluate(() => {
    ["herb","potion","slime_jelly","wolf_fang","stone_fragment","secret_key","old_letter","junk_scrap","mana_stone","sample_t1","sample_t3","sample_t5","sample_t7","sample_t9","sample_t10","barrier_lantern"].forEach(id => addToInventory(id));
    ["sword_10","heavy_7","bow_9","orb_9","armor_5","headgear_4","accessory_5","kings_armor","collector_medal","bow_10","orb_3","sword_5"].forEach(id => addEquipmentToInventory(rollEquipmentInstance(id)));
    game.player.skillBarSlots = ["heavy_attack","haste","heal","guard","triple_slash","parry_stance","blink_step","thousand_blades"]; renderSkillBar();
  });
  await pg.waitForTimeout(1500); await pg.screenshot({ path: "t/v73_hud.png" });
  await pg.click("#bagBtn"); await pg.waitForTimeout(1200); await pg.screenshot({ path: "t/v73_bag.png" });
  await pg.evaluate(() => { document.querySelectorAll(".panel").forEach(p => p.hidden = true); }); await pg.click("#weaponSkillBtn"); await pg.waitForTimeout(1200); await pg.screenshot({ path: "t/v73_skills.png" });
  await pg.evaluate(() => { document.querySelectorAll(".panel").forEach(p => p.hidden = true); ["first_blood","reaper","slime_hunter","fish_novice","story_c1"].forEach(id => game.unlockedTitles.add(id)); game.player.titleId = "first_blood"; });
  await pg.click("#collectionBtn"); await pg.waitForTimeout(800);
  await pg.evaluate(() => { const b = [...document.querySelectorAll("#collectionPanel button, #collectionPanel [data-tab]")].find(x => /ฉายา/.test(x.textContent)); if(b) b.click(); });
  await pg.waitForTimeout(800); await pg.screenshot({ path: "t/v73_titles.png" });
  await pg.evaluate(() => { document.querySelectorAll(".panel").forEach(p => p.hidden = true); warpToMap(8); hideArtSplash && hideArtSplash(); });
  await pg.waitForTimeout(1500); await pg.screenshot({ path: "t/v73_map8.png" });
  await pg.evaluate(() => { const m = game.monsters.find(m => m.alive); enterBattle(m); }); await pg.waitForTimeout(1800);
  await pg.screenshot({ path: "t/v73_battle8.png" });
  console.log("errors", errs); await br.close();
})();
