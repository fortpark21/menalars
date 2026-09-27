// v67 👥 party UI screenshots with fake server data. Run: cd /tmp/mw && NODE_PATH=$(npm root -g) node t/v67_shots.js
const { chromium } = require("playwright");
(async () => {
  const br = await chromium.launch(); const pg = await br.newPage({ viewport: { width: 1600, height: 900 } });
  const errs = []; pg.on("pageerror", e => errs.push(String(e)));
  await pg.goto("http://localhost:8765/index.html"); await pg.waitForTimeout(800);
  await pg.evaluate(() => { localStorage.clear(); startGame("หัวหน้า", { ...look }, "sword"); document.getElementById("coachModal").hidden = true; game.player.tutorialDone = true; closeTutorial && closeTutorial();
    partyAvailable = () => true; net.user = { id: "me" }; netRpc = async () => ({ ok: true });
    warpToMap(2); hideArtSplash && hideArtSplash(); if(talk.open) closeTalk(); document.querySelectorAll(".panel").forEach(p => p.hidden = true);
    game.player.x = 900; game.player.y = 700;
    partyApply({ party: { id: 1, leader: "me", members: [
      { id: "me", name: "หัวหน้า", level: 24, online: true, map: 2, dim: 1 },
      { id: "u2", name: "มีรา", level: 31, online: true, map: 2, dim: 1 },
      { id: "u3", name: "ไคจิ", level: 18, online: true, map: 0, dim: 1 },
      { id: "u4", name: "ซากุระ", level: 27, online: false, map: 4, dim: 2 } ] }, inv: [] });
    rtPeerUpdate({ id: "u2", x: 1010, y: 720, name: "มีรา", mapTier: 2, dimension: 1, level: 31, look: { gender: "female", hairStyle: 1, hairColor: "#222233", outfitColor: "#c0392b" } });
    rtPeerUpdate({ id: "zz", x: 780, y: 760, name: "คนแปลกหน้า", mapTier: 2, dimension: 1, level: 9 });
    renderPartyBox();
  });
  await pg.waitForTimeout(1200);
  await pg.hover("#partyBox .pb-row:nth-of-type(3)"); await pg.waitForTimeout(200);
  await pg.screenshot({ path: "t/v67_party.png" });
  await pg.evaluate(() => { partyApply({ party: null, inv: [{ from: "u9", name: "ทาเคชิ", level: 40 }] }); });
  await pg.waitForTimeout(600); await pg.screenshot({ path: "t/v67_invite.png" });
  console.log("errors", errs); await br.close();
})();
