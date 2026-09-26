// Builds the constant table the server's economy guard (econ_data) needs, straight from the game's own definitions.
const { loadGame } = require("./harness");
const g = loadGame(process.argv[2] || "game.html");
g.run(`startGame("Gen", { ...look }, "sword"); game.dimension = 1;`);
const data = JSON.parse(g.get(`JSON.stringify((()=>{
  const tiers = {};
  for(let t = 1; t <= MAP_TIER_COUNT; t++){
    const defs = getMapMonsterDefs(t);
    tiers[t] = { g: defs.map(d => d.gold), x: defs.map(d => d.exp) };
    if(defs.length !== 6 || defs[5].isBoss !== true) throw new Error("slot layout changed");
  }
  const items = {};
  for(const [id, d] of Object.entries(EQUIPMENT_DEFS)){
    const base = id.replace(/_t\\d+$/, "");
    const cur = items[base];
    const row = [d.rarity, d.cosmeticOnly || !(GEAR_STAT_POOL[d.slot] || []).length ? 1 : 0];
    if(cur && (cur[0] !== row[0] || cur[1] !== row[1])) throw new Error("base " + base + " differs across tiers");
    items[base] = row;
    if((d.tier || 1) !== (/_t(\\d+)$/.test(id) ? +id.match(/_t(\\d+)$/)[1] : 1)) throw new Error("tier/id mismatch " + id);
  }
  const pts = {}; for(const [r, v] of Object.entries(STAT_ROLL_BY_RARITY)) pts[r] = v.pts[1];
  const skill = {}; for(const [type, tree] of Object.entries(WEAPON_SKILL_TREES)) skill[type] = tree.tiers.map(t => [t.unlockRankIndex, t.points]);
  const titles = {}; TITLE_DEFS.forEach(d => titles[d.id] = [d.stat, d.goal]);
  const quests = {}; STORY_QUESTS.forEach(q => quests[q.id] = [q.rw[0], q.rw[1], q.rw[2] || 0, q.goal.tier || q.ch, q.finale ? 1 : 0]);
  return {
    tiers, dimStep: DIM_REWARD_STEP, items, pts,
    eliteMult: ELITE_REWARD_MULT,
    price: Object.assign({}, CONSUMABLE_SELL_PRICE, Object.fromEntries(Object.keys(CARD_DEFS).map(id => [id, Math.round((SELL_PRICE_BY_RARITY[CARD_DEFS[id].rarity] || 10) * 0.7)]))),
    eqPrice: SELL_PRICE_BY_RARITY,
    starter: Object.values(STARTER_WEAPON_DEF_ID), shopOnly: SHOP_BUY_ITEMS.map(i => i.id),
    stack: ITEM_TABLE.map(i => i.id).concat(Object.keys(CARD_DEFS)), cards: Object.keys(CARD_DEFS),
    rankExp: WEAPON_RANK_LADDER.map(r => r.expNeeded), skill, titles, quests, letters: LETTER_DEFS.map(l => l.id),
    totals: { mon: MONSTER_DEFS.length, card: Object.keys(CARD_DEFS).length, eq: Object.keys(EQUIPMENT_DEFS).length },
    base: { atk: 6, hp: 50, atkLv: 2, hpLv: 10, spLv: STAT_POINTS_PER_LEVEL, spDim: DIM_RITUAL_STAT_POINTS, masteryMax: MASTERY_MAX, refineMax: REFINE_MAX, sanityMax: SANITY_MAX, tierMax: MAP_TIER_COUNT, bag: BAG_CAPACITY, storage: STORAGE_CAPACITY }
  };
})())`));
if(g.errors().length) throw new Error(g.errors().join("\n"));
process.stdout.write(JSON.stringify(data));
