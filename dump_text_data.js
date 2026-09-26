const { loadGame } = require("/tmp/mw/t/harness");
const g = loadGame("game.html");
const names = ["STORY_QUESTS","STORY_CHAPTERS","STORY_NPC_NAME","LETTER_DEFS","LETTER_CATS","LETTER_SPY_PAGES","RESEARCHER_LINES","DOCTOR_LINES","MONK_LINES","TOWN_LORD_LORE","QUEST_DEFS","MERCHANT_TIPS","BLACKSMITH_TIPS","TUTORIAL_STEPS","TUT_INPUT","NPC_TALK_PROFILE","STAT_INFO","SANITY_MADNESS","SANITY_ALERT_TITLES","DIM_RULES","SKILL_DEFS","WEAPON_SKILL_TREES","TITLE_DEFS","TITLE_CATS","TITLE_TIERS","SECRET_LOCATION_DEFS","DUNGEON_ROOM_INFO","MONK_GRADES","ITEM_TABLE","CARD_DEFS","MILESTONE_DEFS","MAP_DEFS","TOWN_DEF","PLAYER_PRESETS","WILL_COLORS","MONSTER_DEFS","WEAPON_RANK_LADDER","MAD_HEADS"];
const out = {};
for(const n of names){ try{ out[n] = JSON.parse(g.get(`JSON.stringify(${n})`)); }catch(e){ console.error(n, e.message); } }
require("fs").writeFileSync("/tmp/mw/text_export/_data.json", JSON.stringify(out, null, 1));
console.log(Object.keys(out).length);
