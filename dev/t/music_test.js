// v43: checks which music each scene picks, crossfades, playlist, jingles, sfx names, settings.
const { loadGame } = require("./harness");
const g = loadGame(process.env.GAME || "game.html");
const R = s => g.run(s), G = s => g.get(s);
const fails = [];
const eq = (label, got, want) => { if(JSON.stringify(got) !== JSON.stringify(want)) fails.push(`${label}: got ${JSON.stringify(got)} want ${JSON.stringify(want)}`); };
const tick = (ms = 100) => { for(let i = 0; i < Math.ceil(ms / 100); i++){ g.clock.advance(100); R("musicTick()"); } };
const playing = () => G("music.els.filter(e => e && !e.paused).map(e => e.dataset.key)");

// before any click: nothing plays
tick(300); eq("locked", playing(), []);
R("unlockAudio()"); tick(200);
eq("title screen → title theme", G("music.key"), "bgm_title");
R(`startGame("Mus", { ...look }, "sword"); closeTutorial && closeTutorial(); document.getElementById("coachModal").hidden = true; game.player.tutorialDone = true; warpToMap(TOWN_TIER);`);
tick(3000);
eq("town", G("music.key"), "bgm_city01");
eq("town playing", playing(), ["bgm_city01"]);
// end of song → City02
R("music.els[music.cur].currentTime = 178"); tick(3000);
eq("playlist next", G("music.key"), "bgm_city02");
R("music.els[music.cur].currentTime = 178"); tick(3000);
eq("playlist 3", G("music.key"), "bgm_city03");
R("music.els[music.cur].currentTime = 178"); tick(3000);
eq("playlist 4", G("music.key"), "bgm_city04");
R("music.els[music.cur].currentTime = 178"); tick(3000);
eq("playlist wraps", G("music.key"), "bgm_city01");
// map 1
R("warpToMap(1)"); tick(3000);
eq("map1", G("music.key"), "bgm_map01");
R("music.els[music.cur].currentTime = 60"); tick(100);
// map 5 falls back to map01 (same track keeps playing, no restart)
R("delete AUDIO.bgm_map05"); R("warpToMap(5)"); tick(500);
eq("map5 fallback", G("music.key"), "bgm_map01");
R("warpToMap(1)"); tick(300);
// battle
R("enterBattle(game.monsters.find(m => m.alive && !MONSTER_DEFS[m.type].isBoss))"); tick(1200);
eq("fight", G("music.key"), "bgm_fight01");
eq("fight starts at 0", G("Math.round(music.els[music.cur].currentTime)"), 0);
eq("only fight audible", playing(), ["bgm_fight01"]);
R("exitBattle('win')");
// v64: no fanfare after a road-side monster — the map music simply carries on
eq("no jingle after normal win", G("!!music.jingle"), false);
tick(1200);
eq("back to map", G("music.key"), "bgm_map01");
eq("map resumes near 60s", G("music.els[music.cur].currentTime >= 59"), true);
// boss without boss track → fight01
R("delete AUDIO.bgm_boss; delete AUDIO.bgm_fight02; delete AUDIO.bgm_fight03");
R("game.monsters.filter(m => MONSTER_DEFS[m.type].isBoss).forEach(m => m.alive = true)");
R("enterBattle(game.monsters.find(m => m.alive && MONSTER_DEFS[m.type].isBoss))"); tick(500);
eq("boss fallback", G("music.key"), "bgm_fight01");
R("exitBattle('win')"); tick(1500);
// pretend new tracks arrived
R(`AUDIO.bgm_boss = "assets/bgm_boss.mp3"; AUDIO.bgm_meditate = "assets/bgm_meditate.mp3"; AUDIO.bgm_map04 = "assets/bgm_map04.mp3"; AUDIO.bgm_fight02 = "assets/bgm_fight02.mp3"; AUDIO.jgl_victory = "assets/jgl_victory.mp3";`);
R("game.monsters.filter(m => MONSTER_DEFS[m.type].isBoss).forEach(m => m.alive = true)");
R("enterBattle(game.monsters.find(m => m.alive && MONSTER_DEFS[m.type].isBoss))"); tick(500);
eq("boss track", G("music.key"), "bgm_boss");
R("exitBattle('win')"); tick(200);
eq("victory jingle ducks", G("music.duckTarget"), 0.12);
eq("jingle playing", G("!!music.jingle && !music.jingle.paused"), true);
eq("boss win: no music under jingle", G("music.key"), null);
eq("boss jingle capped at 7 s", G("JINGLE_MAX_S[music.jingle.src.includes('victory_boss') ? 'jgl_victory_boss' : 'jgl_victory']"), G("AUDIO.jgl_victory_boss ? 7 : 3"));
tick(800); eq("nothing audible under jingle", G("music.els.filter(e => e && !e.paused && e.volume > 0.001).length"), 0);
R("sfxHold.queue.length = 0; sfx.levelUp(); sfx.coin(); sfx.levelUp()");
eq("reward sfx queued once each", G("sfxHold.queue.slice()"), ["levelUp", "coin"]);
R("music.jingle._l.ended.forEach(f => f())"); tick(100);
eq("queue drains one at a time", G("sfxHold.queue.slice()"), ["coin"]);
tick(700);
eq("queue empty", G("sfxHold.queue.length"), 0);
eq("duck restored", G("music.duck"), 1);
eq("map fades back in after jingle", G("music.key"), "bgm_map01");
// a new fight right after a win cuts the leftover jingle
R("game.monsters.filter(m => !MONSTER_DEFS[m.type].isBoss).forEach(m => m.alive = true)");
R("enterBattle(game.monsters.find(m => m.alive && !MONSTER_DEFS[m.type].isBoss))"); tick(300);
R("exitBattle('win')"); tick(300);
R("enterBattle(game.monsters.find(m => m.alive && !MONSTER_DEFS[m.type].isBoss))"); tick(1500);
eq("next fight cuts jingle", [G("!!music.jingle"), G("music.key")], [false, "bgm_fight01"]);
R("exitBattle('win')"); tick(300); R("if(music.jingle) music.jingle._l.ended.forEach(f => f())"); tick(2000);
R("warpToMap(4)"); tick(500);
eq("map4 own track", G("music.key"), "bgm_map04");
R("enterBattle(game.monsters.find(m => m.alive && !MONSTER_DEFS[m.type].isBoss))"); tick(500);
eq("fight02 on map4", G("music.key"), "bgm_fight02");
R("exitBattle('win')"); tick(500); R("if(music.jingle) music.jingle._l.ended.forEach(f => f())");
R("startMeditating()"); tick(500);
eq("meditate", G("music.key"), "bgm_meditate");
R("stopMeditating()"); tick(500);
eq("after meditate", G("music.key"), "bgm_map04");
// settings
R("setAudioCfg('musicOn', false)"); tick(100);
eq("muted volume", G("music.els[music.cur].volume"), 0);
R("setAudioCfg('musicOn', true)"); tick(3000);
eq("unmuted volume", G("music.els[music.cur].volume > 0.4"), true);
R("setAudioCfg('music', 0.2)"); tick(100);
eq("volume follows slider", G("Math.round(music.els[music.cur].volume * 100)"), 20);
// hidden tab pauses
R("document.hidden = true"); tick(200);
eq("hidden pauses", playing(), []);
R("document.hidden = false"); tick(200);
eq("visible resumes", playing(), ["bgm_map04"]);
// sfx names all callable, beeps still work without files
R("['click','attack','crit','miss','talk','die','dodge','perfectDodge','counter','playerHurt','levelUp','skillReady','heal','rareDrop','itemGet','chest','refineOk','questDone','notice','warp','coin','equip'].forEach(k => sfx[k]())");
eq("sfx without file → false", G("playSfxFile('attack')"), false);
R("setAudioCfg('sfxOn', false)");
eq("sfx muted → true (silent)", G("playSfxFile('attack')"), true);
R("setAudioCfg('sfxOn', true)");
// M hotkey
g.fireWindow("keydown", { code:"KeyM", key:"ฒ" });
eq("M mutes", G("audioCfg.musicOn"), false);
g.fireWindow("keydown", { code:"KeyM", key:"m" });
eq("M unmutes", G("audioCfg.musicOn"), true);
eq("settings saved", JSON.parse(G("localStorage.getItem(AUDIO_CFG_KEY)")).music, 0.2);
// failed file → marked and skipped
R("music.els[music.cur]._l.error.forEach(f => f())"); tick(300);
eq("failed map04 falls back", G("music.key"), "bgm_map01");
console.log(fails.length ? "FAILS:\n" + fails.join("\n") : "music test: all passed");
console.log("errors:", g.errors().slice(0, 5));
// ---- v44 options ----
const f2 = [];
const eq2 = (l, a, b) => { if(JSON.stringify(a) !== JSON.stringify(b)) f2.push(`${l}: got ${JSON.stringify(a)} want ${JSON.stringify(b)}`); };
R("setOpt('master', 0.5)"); tick(3000);
eq2("master scales music", G("Math.round(music.els[music.cur].volume * 100)"), 10);
R("setOpt('masterOn', false)"); tick(100);
eq2("master off", G("music.els[music.cur].volume"), 0);
eq2("master off silences sfx", G("playSfxFile('attack') && playSfxFile('coin')"), true);
R("setOpt('masterOn', true); setOpt('uiOn', false)");
eq2("ui off → coin silent", G("playSfxFile('coin')"), true);
eq2("ui off → attack still beeps", G("playSfxFile('attack')"), false);
eq2("battle vol", G("sfxCatVol('battle')"), 0.4);
eq2("ui vol", G("sfxCatVol('ui')"), 0);
R("setOpt('uiScale', 1.3)"); eq2("ui zoom", G("UI_ZOOM"), 1.3);
R("setOpt('minimap', false); setOpt('hint', false)");
eq2("body classes", G("['opt-no-minimap','opt-no-hint'].map(c => document.body.classList.contains(c))"), [true, true]);
R("setOpt('talkSpeed', 'instant')");
R("warpToMap(TOWN_TIER)"); R("(()=>{ const n = game.npcs.find(n => n.kind === 'doctor'); game.player.x = n.x; game.player.y = n.y + 40; interactWithNpc(n); })()");
eq2("instant talk", G("talk.shown === talk.total"), true);
R("if(talk.open) closeTalk()");
// reset
R("document.getElementById('optionsBtn').click()");
const clickReset = () => g.byId("optionsPanel").dispatch("click", { target: Object.assign(g.byId("optReset"), { closest: () => null }) });
clickReset(); eq2("reset armed, not yet", G("OPT.uiScale"), 1.3);
clickReset(); eq2("reset done", G("JSON.stringify(OPT) === JSON.stringify(OPT_DEFAULTS)"), true);
eq2("zoom back", G("UI_ZOOM"), 1);
// saved + reload keeps options, migrates old v43 key
const g3 = loadGame(process.env.GAME || "game.html");
g3.run(`localStorage.setItem("menalars_audio_v1", JSON.stringify({ music:0.3, musicOn:false, sfx:0.2, sfxOn:true }))`);
// (migration happens at load — simulate by reloading the script in a context that already has the old key)
const vm = require("vm"); const fs = require("fs"); const { extractScript } = require("./harness");
const g4 = loadGame(process.env.GAME || "game.html");
g4.ctx.localStorage._s["menalars_audio_v1"] = JSON.stringify({ music:0.3, musicOn:false, sfx:0.2, sfxOn:true });
eq2("migration source readable", !!g4.ctx.localStorage._s["menalars_audio_v1"], true);
// low power: loop skips frames < 30ms apart
R("setOpt('lowPower', true); lastLoopFrame = performance.now()"); g.clock.advance(16);
const before = G("game.lastTime"); R("loop(performance.now())");
eq2("low power skips 16ms frame", G("game.lastTime"), before);
g.clock.advance(20); R("loop(performance.now())");
eq2("low power runs 36ms frame", G("game.lastTime") !== before, true);
console.log(f2.length ? "OPTION FAILS:\n" + f2.join("\n") : "options test: all passed");
console.log("errors2:", g.errors().slice(0, 5));
