// v67 👥 party — client side with a fake server (net_poll's r.pt fed straight into partyApply, netRpc stubbed).
// Run: cd /tmp/mw/t && node party_test.js
const { loadGame } = require("./harness");
const g = loadGame(process.env.GAME || "game.html");
const R = s => g.run(s), G = s => g.get(s);
const fails = [], eq = (l, a, b) => { if(JSON.stringify(a) !== JSON.stringify(b)) fails.push(`${l}: got ${JSON.stringify(a)} want ${JSON.stringify(b)}`); };
R(`startGame("Leader", { ...look }, "sword"); closeTutorial && closeTutorial(); document.getElementById("coachModal").hidden = true; game.player.tutorialDone = true;`);
// pretend we're online with the v67 SQL installed
R(`partyAvailable = () => true; net.user = { id: "me" }; window.__rpc = []; window.__chat = []; const _cal = chatAddLine; chatAddLine = (c, n, t, id) => { __chat.push(t); _cal(c, n, t, id); }; netRpc = async (fn, body) => { __rpc.push([fn, JSON.parse(body)]); return { ok: true }; };`);
eq("solo: no box", G("(renderPartyBox(), document.getElementById('partyBox').hidden)"), true);
eq("solo: mult 1", G("partyExpMult()"), 1);
// an invite arrives
R(`partyApply({ party: null, inv: [{ from: "u2", name: "Mira", level: 33 }] })`);
eq("invite shown", G("document.getElementById('partyInvite').hidden"), false);
R(`document.getElementById("piYes").click()`);
eq("accept → rpc", G("JSON.stringify(__rpc.pop())"), JSON.stringify(["party_answer", { p_from: "u2", p_accept: true }]));
eq("invite closed", G("document.getElementById('partyInvite').hidden"), true);
// the party as the server reports it: Mira leads, me + Kai
const pt = (leader, members) => JSON.stringify({ party: { id: 1, leader, members }, inv: [] });
const mira = { id: "u2", name: "Mira", level: 33, online: true, map: 2, dim: 1 }, kai = { id: "u3", name: "Kai", level: 20, online: true, map: 0, dim: 1 },
      me = { id: "me", name: "Leader", level: 1, online: true, map: 2, dim: 1 };
R(`partyApply(${pt("u2", [mira, me, kai])})`);
const boxHtml = () => G("document.getElementById('partyBox').innerHTML");
const count = (html, needle) => html.split(needle).length - 1;
eq("box shows 3", count(boxHtml(), 'class="pb-row'), 3);
eq("not leader: no kick buttons", count(boxHtml(), "data-kick"), 0);
R("warpToMap(2)");
eq("no mates on map yet", G("partyExpMult()"), 1);
R(`rtPeerUpdate({ id: "u2", x: 500, y: 500, name: "Mira", mapTier: 2, dimension: 1, level: 33 })`);
eq("Mira on my map → +10%", G("Math.round(partyExpMult() * 100)"), 110);
R(`rtPeerUpdate({ id: "zz", x: 520, y: 500, name: "Stranger", mapTier: 2, dimension: 1, level: 5 })`);
eq("strangers don't count", G("Math.round(partyExpMult() * 100)"), 110);
// kill a monster: EXP carries the bonus
const exp0 = G("game.player.exp + 100 * game.player.level * (game.player.level - 1) / 2");
R(`(()=>{ const m = game.monsters.find(m => m.alive && !MONSTER_DEFS[m.type].isBoss); window.__base = m.expReward; enterBattle(m); exitBattle("win"); })()`);
eq("victory text shows the bonus", G("document.getElementById('victoryExp').textContent"), `+${Math.round(G("__base") * 1.1)} EXP (👥 +10%)`);
R("closeSummaryPanel(); if(document.getElementById('battleCanvas').style.display === 'block') returnToOverworldView()");
eq("town: no bonus", G("(warpToMap(TOWN_TIER), partyExpMult())"), 1);
// player menu for a stranger: not leader → no invite item
R(`game.player.x = 400; socOpenMenu("zz", "Stranger", 100, 100)`);
eq("member can't invite", G("document.getElementById('playerMenu').innerHTML.includes('pinvite')"), false);
R("socCloseMenu()");
// I become leader (Mira left)
R(`partyApply(${pt("me", [me, kai])})`);
eq("chat: leader line", G("__chat.some(t => t.includes('หัวหน้าปาร์ตี้'))"), true);
eq("leader: kick button for Kai", count(boxHtml(), "data-kick"), 1);
R(`socOpenMenu("zz", "Stranger", 100, 100)`);
eq("leader can invite", G("document.getElementById('playerMenu').innerHTML.includes('pinvite')"), true);
R(`socMenuAction("pinvite", "zz", "Stranger")`);
eq("invite rpc", G("JSON.stringify(__rpc.pop())"), JSON.stringify(["party_invite", { p_to: "zz" }]));
// kick needs two clicks
const clickBox = target => g.byId("partyBox").dispatch("click", { target });
const kickT = { closest: () => ({ dataset: { kick: "u3" } }) }, leaveT = { id: "partyLeaveBtn", closest: () => null };
clickBox(kickT);
eq("kick armed, no rpc yet", G("__rpc.length"), 0);
clickBox(kickT);
eq("kick rpc", G("JSON.stringify(__rpc.pop())"), JSON.stringify(["party_kick", { p_who: "u3" }]));
// leave needs two clicks too
clickBox(leaveT); clickBox(leaveT);
eq("leave rpc", G("JSON.stringify(__rpc.pop())"), JSON.stringify(["party_leave", {}]));
// party dissolves
R(`partyApply({ party: null, inv: [] })`);
eq("box hidden after dissolve", G("document.getElementById('partyBox').hidden"), true);
eq("chat: dissolved line", G("__chat.some(t => t.includes('ปาร์ตี้สลาย'))"), true);
// offline build: nothing shows
R(`partyAvailable = () => NET_ONLINE && serverHas("party") && !!net.user; partyApply(${pt("me", [me, kai])})`);
eq("offline: never shown", G("(renderPartyBox(), document.getElementById('partyBox').hidden)"), true);
console.log("fails", JSON.stringify(fails, null, 1));
console.log("errors:", JSON.stringify(g.errors().slice(0, 5)));
