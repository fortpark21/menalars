// Run: cd /tmp/mw/t && node fish_time.js  (N=samples, NEED="c,u,r,e,l" to try other need values)
// average bot catch time per rarity (same bot as fish_test); NEED env overrides need values: "c,u,r,e,l"
const { loadGame } = require("./harness");
const g = loadGame(process.env.GAME || "game.html"), R = s => g.run(s), G = s => g.get(s);
R(`startGame("F", { ...look }, "sword"); closeTutorial && closeTutorial(); document.getElementById("coachModal").hidden = true; game.player.tutorialDone = true; warpToMap(TOWN_TIER); game.player.x = FISH_SPOTS[0].x; game.player.y = FISH_SPOTS[0].y;`);
if(process.env.NEED){ const n = process.env.NEED.split(",").map(Number); R(`["common","uncommon","rare","epic","legendary"].forEach((r, i) => FISH_RARITY[r].need = ${JSON.stringify(n)}[i])`); }
const out = [];
for(const rar of ["common", "uncommon", "rare", "epic", "legendary"]){
  let ok = 0, time = 0; const N = +(process.env.N || 30);
  for(let i = 0; i < N; i++){
    R("game.inventory.length = 0; startFishing(); document.getElementById('fishResult').hidden = true");
    R(`fishing.biteAt = 0; fishStep(0.02); fishing.fish = FISH_DEFS.find(f => f.rarity === "${rar}")`);
    let t = 0, lag = 0;
    while(G("fishing.phase") !== "done" && t < 120){
      const st = JSON.parse(G("JSON.stringify({ p: fishing.power, z: fishing.zoneC, v: fishing.vel, tug: fishing.tug && fishing.tug.side })"));
      lag = (lag + 1) % 3; if(!lag) R(`fishing.hold = ${st.p + st.v * 0.25 < st.z}`);
      R(`fishing.keyL = ${st.tug === "right"}; fishing.keyR = ${st.tug === "left"}`);
      R("fishStep(0.02)"); t += 0.02;
    }
    if(G("fishing.progress >= 1")){ ok++; time += t; }
    R("closeFishing()");
  }
  out.push(`${rar} ${ok}/${N} ${(time / Math.max(1, ok)).toFixed(1)}s`);
}
console.log(out.join(" | "));
