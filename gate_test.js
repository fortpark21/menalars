const { loadGame } = require("./harness");
const g = loadGame("game_on.html"); const R=s=>g.run(s), G=s=>g.get(s);
R(`startGame("Gate", { ...look }, "sword"); document.getElementById("coachModal").hidden = true; game.player.tutorialDone = true;`);
R(`const s = storyState(); s.i = STORY_QUESTS.findIndex(q => q.id === "c4_hut"); s.st = "offer"; s.done = STORY_QUESTS.slice(0, s.i).map(q => q.id);`);
R(`net.storyMax = 3;`);
console.log("online old server:", G("JSON.stringify(storyQuest() && storyQuest().id)"));
R(`net.storyMax = 10;`);
console.log("online new server:", G("JSON.stringify(storyQuest() && storyQuest().id)"));

console.log("offline:", G("JSON.stringify(storyQuest() && storyQuest().id)"));
console.log("errors", g.errors());
