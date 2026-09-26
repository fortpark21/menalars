-- ============================================================
-- Menalars — Supabase setup (run once in Supabase → SQL Editor → New query → Run)
-- Safe to re-run: every statement is create-or-replace / if-not-exists.
-- ============================================================

-- One cloud save per account. session_id = the device currently allowed to save (newest login wins).
create table if not exists public.saves (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  data       jsonb,
  rev        bigint not null default 0,
  session_id uuid,
  updated_at timestamptz not null default now()
);

-- Every equipment piece (by its instanceId) an account has ever saved. alive = false once it left the save
-- (sold, lost, replaced) — it can never come back, which is what stops rollback / two-device duplication.
create table if not exists public.item_registry (
  user_id    uuid not null references auth.users(id) on delete cascade,
  uid        text not null,
  alive      boolean not null default true,
  created_at timestamptz not null default now(),
  primary key (user_id, uid)
);

-- GM accounts: may open the debug panel (Ctrl+Shift+D) in the online build and get a [GM] tag in-game.
-- Add yourself: insert into public.admins values ('<your user id from Authentication → Users>');
create table if not exists public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade
);

-- Game version gate. min_version = the oldest game file still allowed to save; older open tabs are told to refresh.
-- Force an update: update public.app_config set value = <GAME_VERSION> where key = 'min_version';
create table if not exists public.app_config (key text primary key, value int not null);
insert into public.app_config values ('min_version', 0) on conflict (key) do nothing;
alter table public.app_config enable row level security;
revoke all on public.app_config from anon, authenticated;
create or replace function public.min_game_version() returns int language sql stable security definer set search_path = public as $$
  select coalesce((select value from public.app_config where key = 'min_version'), 0) $$;
revoke execute on function public.min_game_version() from public, anon, authenticated;

-- Hall of Fame: when this account last moved up the ranking key (a full tie goes to whoever got there first).
alter table public.saves add column if not exists progress_at timestamptz;
update public.saves set progress_at = updated_at where progress_at is null;

-- Ranking key of a save: {highest dimension, furthest map in it, level, exp}. Numbers that aren't numbers count as 0.
create or replace function public.lb_num(v jsonb) returns bigint language sql immutable as $$
  select case when jsonb_typeof(v) = 'number' then least(greatest(floor((v)::numeric), 0), 1000000000000)::bigint else 0 end $$;
create or replace function public.lb_key(d jsonb) returns bigint[] language sql immutable as $$
  select array[m, greatest(case when m = 1 then public.lb_num(d -> 'maxMapTierReachedDim1') else public.lb_num(d -> 'dimReach' -> m::text) end, 1),
               public.lb_num(d -> 'player' -> 'level'), public.lb_num(d -> 'player' -> 'exp')]
    from (select greatest(public.lb_num(d -> 'maxDimension'), 1) m) x $$;
revoke execute on function public.lb_num(jsonb), public.lb_key(jsonb) from public, anon, authenticated;

-- No direct table access from the game — only through the two functions below.
alter table public.saves enable row level security;
alter table public.item_registry enable row level security;
alter table public.admins enable row level security;
revoke all on public.saves, public.item_registry, public.admins from anon, authenticated;

-- ============================================================
-- ECONOMY GUARD (v7) — the server decides what a save may contain.
-- Fights run in the browser, so the server can't replay them. Instead every autosave is compared with the
-- last save it accepted (save_game → econ_check) and must pass:
--   1) rules no honest play can break: stat points vs level, ATK/HP vs level, item stats vs rarity/tier,
--      existing items never change (only their refine level goes up), titles need their goal, …
--   2) earnings tied to kills: gold/EXP may only grow by what the kills since the last save can pay
--      (per monster slot, at the best map/layer reached) + sales of items that left the save + chests/quests,
--      and kills/new items may only come as fast as the fastest possible farming (a budget that refills with
--      play time, capped at 30 min). Over budget = flagged for GM; far over = the save is refused.
-- A refused save never lands: the game reloads the last good one. Every refusal/flag goes to econ_flags
-- (GM Console → 🚩 ตรวจโกง). GM accounts are exempt (their test tools spawn things).
-- econ_data() is generated from the game's own tables — regenerate it whenever items/monsters/titles change.
-- ============================================================
alter table public.saves add column if not exists econ jsonb;           -- earning budgets {k, u, at}
alter table public.item_registry add column if not exists def text;     -- which item each id was (discovery check)
create table if not exists public.econ_flags (
  id         bigserial primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  kind       text not null,
  detail     jsonb,
  rejected   boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists econ_flags_user_idx on public.econ_flags (user_id, created_at desc);
create table if not exists public.saves_archive (         -- characters a GM wiped — kept so they can be restored
  id         bigserial primary key,
  user_id    uuid not null,
  name       text,
  data       jsonb,
  reason     text,
  by         uuid,
  created_at timestamptz not null default now()
);
alter table public.econ_flags enable row level security;
alter table public.saves_archive enable row level security;
revoke all on public.econ_flags, public.saves_archive from anon, authenticated;

-- ECON_DATA_BEGIN
create or replace function public.econ_data() returns jsonb language sql immutable as $$ select '{"tiers":{"1":{"g":[9,16,28,46,70,263],"x":[21,35,56,84,123,385]},"2":{"g":[86,102,116,131,147,431],"x":[149,173,200,224,250,735]},"3":{"g":[163,177,193,208,224,648],"x":[275,301,326,352,376,1089]},"4":{"g":[238,254,270,285,299,863],"x":[403,427,453,478,504,1446]},"5":{"g":[315,331,347,361,376,1073],"x":[529,555,579,606,630,1799]},"6":{"g":[392,408,422,438,453,1288],"x":[656,681,707,732,758,2156]},"7":{"g":[469,483,499,515,530,1505],"x":[782,809,833,859,884,2510]},"8":{"g":[544,560,576,592,606,1720],"x":[910,935,961,985,1012,2867]},"9":{"g":[621,637,653,667,683,1930],"x":[1036,1062,1087,1113,1138,3220]},"10":{"g":[698,714,728,744,760,2146],"x":[1164,1188,1215,1239,1265,3577]}},"dimStep":0.3,"items":{"kings_armor":["epic",0],"collector_medal":["legendary",1],"sword_1":["common",0],"sword_2":["common",0],"sword_3":["uncommon",0],"sword_4":["uncommon",0],"sword_5":["rare",0],"sword_6":["rare",0],"sword_7":["epic",0],"sword_8":["epic",0],"sword_9":["legendary",0],"sword_10":["legendary",0],"heavy_1":["common",0],"heavy_2":["common",0],"heavy_3":["uncommon",0],"heavy_4":["uncommon",0],"heavy_5":["rare",0],"heavy_6":["rare",0],"heavy_7":["epic",0],"heavy_8":["epic",0],"heavy_9":["legendary",0],"heavy_10":["legendary",0],"bow_1":["common",0],"bow_2":["common",0],"bow_3":["uncommon",0],"bow_4":["uncommon",0],"bow_5":["rare",0],"bow_6":["rare",0],"bow_7":["epic",0],"bow_8":["epic",0],"bow_9":["legendary",0],"bow_10":["legendary",0],"orb_1":["common",0],"orb_2":["common",0],"orb_3":["uncommon",0],"orb_4":["uncommon",0],"orb_5":["rare",0],"orb_6":["rare",0],"orb_7":["epic",0],"orb_8":["epic",0],"orb_9":["legendary",0],"orb_10":["legendary",0],"armor_1":["common",0],"armor_2":["uncommon",0],"armor_3":["rare",0],"armor_4":["epic",0],"armor_5":["legendary",0],"headgear_1":["common",0],"headgear_2":["uncommon",0],"headgear_3":["rare",0],"headgear_4":["epic",0],"headgear_5":["legendary",0],"accessory_1":["common",0],"accessory_2":["uncommon",0],"accessory_3":["rare",0],"accessory_4":["epic",0],"accessory_5":["legendary",0]},"pts":{"common":1.2,"uncommon":1.7,"rare":2.4,"epic":3.4,"legendary":4.4},"eliteMult":2,"price":{"herb":3,"potion":5,"slime_jelly":4,"wolf_fang":6,"stone_fragment":8,"secret_key":20,"junk_scrap":2,"mana_stone":12,"sample_t1":7,"sample_t2":23,"sample_t3":39,"sample_t4":54,"sample_t5":69,"sample_t6":85,"sample_t7":100,"sample_t8":115,"sample_t9":130,"sample_t10":146,"fish_siw":4,"fish_kad":6,"fish_ayu":6,"fish_tu":7,"fish_nil":8,"fish_saba":14,"fish_takhian":12,"fish_salid":12,"fish_duk":15,"fish_chon":30,"fish_koi":34,"fish_fugu":36,"fish_madai":38,"fish_unagi":70,"fish_kaphong":64,"fish_katsuo":66,"fish_buek":160,"fish_maguro":180,"green_slime_card":11,"pink_slime_card":11,"goblin_card":25,"wolf_card":25,"skeleton_card":56,"stone_king_card":280,"kings_oath_secret":280},"eqPrice":{"common":15,"uncommon":35,"rare":80,"epic":180,"legendary":400},"starter":["sword_1","heavy_1","bow_1","orb_1"],"shopOnly":["herb","potion"],"stack":["herb","potion","slime_jelly","wolf_fang","stone_fragment","secret_key","old_letter","junk_scrap","mana_stone","sample_t1","sample_t2","sample_t3","sample_t4","sample_t5","sample_t6","sample_t7","sample_t8","sample_t9","sample_t10","bark_tag","barrier_lantern","inscribed_wrap","fish_siw","fish_kad","fish_ayu","fish_tu","fish_nil","fish_saba","fish_takhian","fish_salid","fish_duk","fish_chon","fish_koi","fish_fugu","fish_madai","fish_unagi","fish_kaphong","fish_katsuo","fish_buek","fish_maguro","green_slime_card","pink_slime_card","goblin_card","wolf_card","skeleton_card","stone_king_card","kings_oath_secret"],"cards":["green_slime_card","pink_slime_card","goblin_card","wolf_card","skeleton_card","stone_king_card","kings_oath_secret"],"rankExp":[0,500,1500,3500,7000,13000,23000,40000,70000,120000],"skill":{"sword":[[1,2],[3,2],[5,2],[7,2],[9,2]],"heavy":[[1,2],[3,2],[5,2],[7,2],[9,2]],"bow":[[1,2],[3,2],[5,2],[7,2],[9,2]],"orb":[[1,2],[3,2],[5,2],[7,2],[9,2]]},"titles":{"first_blood":["kills",100],"reaper":["kills",1000],"death_walker":["kills",5000],"calamity":["kills",20000],"slime_hunter":["slimeKills",100],"one_beat":["perfectHits",300],"flawless_blade":["perfectHits",3000],"rhythm_sage":["perfectHits",15000],"perfect_warrior":["bestPerfectStreak",50],"swaying_shadow":["perfectDodges",50],"formless_wind":["perfectDodges",500],"shadowless":["perfectDodges",2500],"counter_art":["counters",50],"mirror_blade":["counters",500],"keen_eye":["crits",500],"fortune_chosen":["crits",5000],"star_assassin":["crits",25000],"unscathed":["flawless",50],"invisible_armor":["flawless",500],"survivor":["survivor",1],"never_give_up":["deaths",25],"elite_hunter":["eliteKills",10],"star_breaker":["eliteKills",100],"elite_bane":["eliteKills",500],"boss_slayer":["bossKills",10],"throne_hunter":["bossKills",50],"king_of_kings":["bossKills",200],"untouchable":["untouchable",1],"five_realms":["bossTiers",5],"ten_kings":["bossTiers",10],"wanderer":["reach",3],"pathfinder":["reach",6],"worlds_edge":["reach",10],"story_c1":["chapters",1],"story_c2":["chapters",2],"story_c3":["chapters",3],"story_c5":["chapters",5],"story_c7":["chapters",7],"story_c10":["chapters",10],"whisper_listener":["listened",1],"secret_seeker":["secrets",5],"secret_keeper":["secrets",30],"dungeon_diver":["dungeons",1],"labyrinth_lord":["dungeons",10],"underworld_ruler":["dungeons",30],"treasure_hunter":["chests",10],"rising_hero":["level",25],"menalars_hero":["level",50],"peak":["level",100],"barrier_breaker":["maxDim",2],"dimension_walker":["maxDim",3],"void_voyager":["maxDim",5],"novice_collector":["colPct",10],"monster_hunter":["monstersHalf",1],"monster_master":["monstersAll",1],"card_collector":["cards",3],"full_deck":["allCards",1],"half_collector":["colPct",50],"curator":["colPct",75],"full_collector":["colPct",100],"treasure_bearer":["epics",5],"legend_chosen":["legends",1],"legend_vault":["legends",10],"apprentice_smith":["refines",10],"artisan":["bestRefine",5],"forge_master":["bestRefine",10],"new_rich":["goldEarned",10000],"tycoon":["goldEarned",100000],"gold_king":["goldEarned",1000000],"mind_trainee":["meditations",10],"still_water":["meditations",100],"fish_novice":["fish",10],"fish_master":["fish",200],"fish_sage":["fishSpecies",18],"town_friend":["junkQuest",1],"letter_reader":["lettersRead",15],"letter_keeper":["lettersRead",40],"letter_all":["lettersRead",60],"shadow_unmasker":["spyUnmasked",1],"courier":["letters",3],"skill_student":["skills",5],"weapon_scholar":["skills",15],"weapon_master":["bestRank",5],"four_arms":["rankedWeapons",4],"transcender":["bestRank",9]},"quests":{"c1_wake":[40,60,0,1,0],"c1_town":[50,95,0,1,0],"c1_squad":[50,95,0,1,0],"c1_test":[100,190,0,1,0],"c1_wreck":[100,190,0,1,0],"c1_bark":[100,190,0,1,0],"c1_mind":[100,190,0,1,0],"c1_counter":[100,190,0,1,0],"c1_boss":[270,510,1,1,1],"c2_child":[350,600,0,2,0],"c2_lantern":[350,600,0,2,0],"c2_incense":[350,600,0,2,0],"c2_preacher":[350,600,0,2,0],"c2_lost":[350,600,0,2,0],"c2_boss":[930,1600,1,2,1],"c3_tablets":[580,980,0,3,0],"c3_wrap":[580,980,0,3,0],"c3_vent":[580,980,0,3,0],"c3_heat":[580,980,0,3,0],"c3_boss":[1540,2600,1,3,1],"c4_hut":[810,1365,0,4,0],"c4_frozen":[810,1365,0,4,0],"c4_ice":[810,1365,0,4,0],"c4_still":[810,1365,0,4,0],"c4_boss":[2150,3600,1,4,1],"c5_brother":[1040,1750,0,5,0],"c5_ore":[1040,1750,0,5,0],"c5_camp":[1040,1750,0,5,0],"c5_dark":[1040,1750,0,5,0],"c5_boss":[2760,4600,1,5,1],"c6_cure":[1270,2135,0,6,0],"c6_drowned":[1270,2135,0,6,0],"c6_ferry":[1270,2135,0,6,0],"c6_calm":[1270,2135,0,6,0],"c6_boss":[3370,5600,1,6,1],"c7_mirror":[1500,2520,0,7,0],"c7_cage":[1500,2520,0,7,0],"c7_home":[1500,2520,0,7,0],"c7_sight":[1500,2520,0,7,0],"c7_boss":[3980,6600,1,7,1],"c8_mural":[1730,2905,0,8,0],"c8_pilgrims":[1730,2905,0,8,0],"c8_doubt":[1730,2905,0,8,0],"c8_sun":[1730,2905,0,8,0],"c8_boss":[4590,7600,1,8,1],"c9_edge":[1960,3290,0,9,0],"c9_echo":[1960,3290,0,9,0],"c9_warriors":[1960,3290,0,9,0],"c9_untouched":[1960,3290,0,9,0],"c9_boss":[5200,8600,1,9,1],"c10_saints":[2190,3675,0,10,0],"c10_mind":[2190,3675,0,10,0],"c10_throne":[2190,3675,0,10,0],"c10_boss":[5810,9600,1,10,1]},"letters":["L01","L02","L03","L04","L05","L06","L07","L08","L09","L10","L11","L12","L13","L14","L15","L16","L17","L18","L19","L20","L21","L22","L23","L24","L25","L26","L27","L28","L29","L30","L31","L32","L33","L34","L35","L36","L37","L38","L39","L40","L41","L42","L43","L44","L45","L46","L47","L48","L49","L50","L51","L52","L53","L54","L55","L56","L57","L58","L59","L60"],"totals":{"mon":6,"card":7,"eq":561},"base":{"atk":6,"hp":50,"atkLv":2,"hpLv":10,"spLv":3,"spDim":3,"masteryMax":100,"refineMax":10,"sanityMax":100,"tierMax":10,"bag":48,"storage":100}}'::jsonb $$;
-- ECON_DATA_END

create or replace function public.econ_n(v jsonb) returns numeric language sql immutable as $$
  select case when jsonb_typeof(v) = 'number' then (v #>> '{}')::numeric else 0 end $$;
create or replace function public.econ_obj(v jsonb) returns jsonb language sql immutable as $$
  select case when jsonb_typeof(v) = 'object' then v else '{}'::jsonb end $$;
create or replace function public.econ_arr(v jsonb) returns jsonb language sql immutable as $$
  select case when jsonb_typeof(v) = 'array' then v else '[]'::jsonb end $$;
-- every item entry of a save (bag + home box)
create or replace function public.econ_items(d jsonb) returns setof jsonb language sql immutable as $$
  select e from jsonb_array_elements(public.econ_arr(d -> 'inventory')) e
  union all
  select e from jsonb_array_elements(public.econ_arr(d -> 'storage')) e $$;
-- v45: bag + box + the NPC buy-back list (items sold this session that can be bought back at the same price —
-- still owned as far as duplicates and item checks go)
create or replace function public.econ_items_all(d jsonb) returns setof jsonb language sql immutable as $$
  select e from public.econ_items(d) e
  union all
  select e from jsonb_array_elements(public.econ_arr(d -> 'buyback')) e $$;
-- weapon rank index for a rank EXP total
create or replace function public.econ_rank(x numeric) returns int language sql immutable as $$
  select coalesce(max(i - 1), 0)::int from jsonb_array_elements_text(public.econ_data() -> 'rankExp') with ordinality t(v, i) where x >= v::numeric $$;

-- The same numbers the game's title checks read (getTitleStats), computed from a save.
create or replace function public.econ_title_stats(d jsonb) returns jsonb language plpgsql immutable as $$
declare
  C jsonb := public.econ_data(); p jsonb := public.econ_obj(d -> 'player'); st jsonb := public.econ_obj(d -> 'stats');
  hc jsonb := public.econ_obj(d -> 'huntCounts'); wr jsonb := public.econ_obj(p -> 'weaponRank');
  mon int; cards int; eqd int; epics int; legends int; skills int := 0; best int := 0; ranked int := 0; ri int; w record;
begin
  select count(*) into mon from jsonb_each(hc) where public.econ_n(value) > 0 and key ~ '^[0-9]+$' and key::int < (C -> 'totals' ->> 'mon')::int;
  select count(distinct substr(x, 6)) into cards from jsonb_array_elements_text(public.econ_arr(d -> 'discoveredItems')) x
   where x like 'card:%' and (C -> 'cards') ? substr(x, 6);
  select count(distinct substr(x, 11)),
         count(distinct substr(x, 11)) filter (where C -> 'items' -> regexp_replace(substr(x, 11), '_t[0-9]+$', '') ->> 0 = 'epic'),
         count(distinct substr(x, 11)) filter (where C -> 'items' -> regexp_replace(substr(x, 11), '_t[0-9]+$', '') ->> 0 = 'legendary')
    into eqd, epics, legends
    from jsonb_array_elements_text(public.econ_arr(d -> 'discoveredItems')) x
   where x like 'equipment:%' and (C -> 'items') ? regexp_replace(substr(x, 11), '_t[0-9]+$', '');
  for w in select value from jsonb_each(wr) loop
    skills := skills + (select count(*) from jsonb_object_keys(public.econ_obj(w.value -> 'unlockedSkills')));
    ri := public.econ_rank(public.econ_n(w.value -> 'exp'));
    best := greatest(best, ri);
    if ri >= 3 then ranked := ranked + 1; end if;
  end loop;
  return jsonb_build_object(
    'kills', public.econ_n(st -> 'kills'), 'eliteKills', public.econ_n(st -> 'eliteKills'), 'bossKills', public.econ_n(hc -> '5'),
    'bossTiers', (select count(*) from jsonb_object_keys(public.econ_obj(st -> 'bossTiers'))),
    'slimeKills', public.econ_n(hc -> '0') + public.econ_n(hc -> '1'),
    'perfectHits', public.econ_n(st -> 'perfectHits'), 'perfectDodges', public.econ_n(st -> 'perfectDodges'),
    'counters', public.econ_n(st -> 'counters'), 'crits', public.econ_n(st -> 'crits'), 'flawless', public.econ_n(st -> 'flawless'),
    'deaths', public.econ_n(st -> 'deaths'), 'bestPerfectStreak', public.econ_n(st -> 'bestPerfectStreak'),
    'untouchable', public.econ_n(st -> 'untouchableBossKills'), 'survivor', public.econ_n(st -> 'survivorWins'),
    'chests', public.econ_n(st -> 'chestsOpened'), 'dungeons', public.econ_n(st -> 'dungeons'), 'secrets', public.econ_n(st -> 'secrets'),
    'refines', public.econ_n(st -> 'refines'),
    'bestRefine', (select coalesce(max(public.econ_n(e -> 'refineLevel')), 0) from public.econ_items(d) e where e ->> 'kind' = 'equipment'),
    'goldEarned', public.econ_n(st -> 'goldEarned'), 'meditations', public.econ_n(st -> 'meditations'), 'letters', public.econ_n(st -> 'letters'),
    'junkQuest', case when public.econ_obj(p -> 'questState') ->> 'junk_hunt' = 'completed' then 1 else 0 end,
    'chapters', (select count(distinct x) from jsonb_array_elements_text(public.econ_arr(public.econ_obj(p -> 'story') -> 'done')) x
                  where C -> 'quests' -> x ->> 4 = '1'),
    'lettersRead', (select count(distinct x) from jsonb_array_elements_text(public.econ_arr(public.econ_obj(p -> 'letters') -> 'found')) x
                     where (C -> 'letters') ? x),
    'spyUnmasked', case when public.econ_n(public.econ_obj(p -> 'letters') -> 'spy') = 2 then 1 else 0 end,
    'listened', case when public.econ_obj(public.econ_obj(p -> 'story') -> 'ch') ->> 'c2p' = 'listen' then 1 else 0 end,
    'level', public.econ_n(p -> 'level'), 'reach', greatest(public.econ_n(d -> 'maxMapTierReached'), 1), 'maxDim', greatest(public.econ_n(d -> 'maxDimension'), 1),
    'skills', skills, 'bestRank', best, 'rankedWeapons', ranked,
    'colPct', round((mon + cards + eqd) * 100.0 / ((C -> 'totals' ->> 'mon')::int + (C -> 'totals' ->> 'card')::int + (C -> 'totals' ->> 'eq')::int)),
    'monstersHalf', case when mon >= ceil((C -> 'totals' ->> 'mon')::numeric / 2) then 1 else 0 end,
    'monstersAll', case when mon >= (C -> 'totals' ->> 'mon')::int then 1 else 0 end,
    'cards', cards, 'allCards', case when cards >= (C -> 'totals' ->> 'card')::int then 1 else 0 end,
    'epics', epics, 'legends', legends,
    -- v66 🎣 fishing
    'fish', public.econ_n(st -> 'fishCaught'),
    'fishSpecies', (select count(*) from jsonb_each(public.econ_obj(p -> 'fishBook')) f
                     where f.key like 'fish\_%' and (C -> 'stack') ? f.key and public.econ_n(f.value -> 'n') > 0));
end $$;

-- o = last accepted save, d = the new one, e = budget state, dt = seconds since the last accepted save.
-- Returns { ok, reason: 'invalid' | 'econ', detail, econ, flags[] }.
drop function if exists public.econ_check(uuid, jsonb, jsonb, jsonb, numeric); -- parameters may be renamed between versions
create or replace function public.econ_check(me uuid, o jsonb, d jsonb, p_econ jsonb, dt numeric)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  C jsonb := public.econ_data(); B jsonb; np jsonb; op jsonb; st jsonb; ost jsonb;
  lv numeric; olv numeric; xp numeric; oxp numeric; g numeric; og numeric;
  mxd numeric; omxd numeric; reach numeric; oreach numeric; dm numeric; tr int;
  hc numeric; ohc numeric; dk numeric; delite numeric; tmp numeric; tmp2 numeric; bad text;
  sale numeric := 0; units numeric := 0; rmana numeric := 0; rsteps numeric := 0; newmana numeric;
  lim_g numeric; lim_x numeric; k record; tstats jsonb; flags jsonb := '[]'::jsonb;
  rk numeric := 0.3; ru numeric := 4; rb numeric := 1.0 / 30; bank_k numeric; bank_u numeric; bank_b numeric; bank_e numeric; bank_l numeric; acc numeric;
  luck numeric := 0; dboss numeric; neq numeric := 0; nstarter numeric := 0; nshop numeric := 0;
  qg numeric := 0; qx numeric := 0; qgear numeric := 0; lgone numeric := 0;
  rebuy numeric := 0; rq numeric := 0;
  fishd numeric := 0;   -- v66 🎣 fish caught since the last save (they arrive without kills)
begin
  np := public.econ_obj(d -> 'player');
  if jsonb_typeof(o) is distinct from 'object' or jsonb_typeof(o -> 'player') is distinct from 'object' then o := '{}'::jsonb; end if;
  -- starting over (a new character) = compare with an empty character
  select coalesce(sum(public.econ_n(value)), 0) into hc from jsonb_each(public.econ_obj(d -> 'huntCounts'));
  select coalesce(sum(public.econ_n(value)), 0) into ohc from jsonb_each(public.econ_obj(o -> 'huntCounts'));
  if public.econ_n(np -> 'level') < public.econ_n(o -> 'player' -> 'level') or hc < ohc then o := '{}'::jsonb; ohc := 0; end if;
  op := public.econ_obj(o -> 'player'); st := public.econ_obj(d -> 'stats'); ost := public.econ_obj(o -> 'stats');
  B := C -> 'base';
  fishd := greatest(public.econ_n(st -> 'fishCaught') - public.econ_n(ost -> 'fishCaught'), 0);

  -- ---------- 1. character numbers ----------
  lv := public.econ_n(np -> 'level'); olv := greatest(public.econ_n(op -> 'level'), 1);
  xp := public.econ_n(np -> 'exp'); oxp := public.econ_n(op -> 'exp');
  g := public.econ_n(np -> 'gold'); og := public.econ_n(op -> 'gold');
  mxd := greatest(public.econ_n(d -> 'maxDimension'), 1); omxd := greatest(public.econ_n(o -> 'maxDimension'), 1);
  reach := greatest(public.econ_n(d -> 'maxMapTierReached'), 1); oreach := greatest(public.econ_n(o -> 'maxMapTierReached'), 1);
  if lv < 1 or lv > 1000 or lv <> floor(lv) then bad := 'level';
  elsif xp < 0 or xp >= lv * 100 + 1 then bad := 'exp';
  elsif public.econ_n(np -> 'expNeeded') <> lv * 100 then bad := 'expNeeded';
  elsif g < 0 or g > 1e12 then bad := 'gold';
  elsif public.econ_n(np -> 'atk') > greatest((B ->> 'atk')::numeric + (B ->> 'atkLv')::numeric * (lv - 1), public.econ_n(op -> 'atk') + (B ->> 'atkLv')::numeric * greatest(lv - olv, 0)) then bad := 'atk';
  elsif public.econ_n(np -> 'maxHp') > greatest((B ->> 'hp')::numeric + (B ->> 'hpLv')::numeric * (lv - 1), public.econ_n(op -> 'maxHp') + (B ->> 'hpLv')::numeric * greatest(lv - olv, 0)) then bad := 'maxHp';
  elsif public.econ_n(np -> 'sanity') > (B ->> 'sanityMax')::numeric + 0.5 then bad := 'sanity';
  elsif exists (select 1 from jsonb_each(public.econ_obj(np -> 'statPoints')) where jsonb_typeof(value) <> 'number' or public.econ_n(value) < 0) then bad := 'statPoints';
  elsif exists (select 1 from jsonb_each(public.econ_obj(np -> 'mastery')) where public.econ_n(value) < 0 or public.econ_n(value) > (B ->> 'masteryMax')::numeric) then bad := 'mastery';
  end if;
  if bad is null then
    select coalesce(sum(public.econ_n(value)), 0) into tmp from jsonb_each(public.econ_obj(np -> 'statPoints'));
    select coalesce(sum(public.econ_n(value)), 0) into tmp2 from jsonb_each(public.econ_obj(op -> 'statPoints'));
    if tmp > greatest((B ->> 'spLv')::numeric * (lv - 1) + (B ->> 'spDim')::numeric * (mxd - 1),
                      tmp2 + (B ->> 'spLv')::numeric * greatest(lv - olv, 0) + (B ->> 'spDim')::numeric * greatest(mxd - omxd, 0)) then bad := 'statPoints'; end if;
  end if;

  -- ---------- 2. progress (maps / layers) ----------
  if bad is null then
    if mxd > omxd + 1 or (mxd > omxd and coalesce(public.econ_obj(o -> 'dimCleared') ->> (omxd::int)::text, 'false') <> 'true') then bad := 'dimension';
    elsif reach > (B ->> 'tierMax')::numeric or reach > oreach + 1 + floor(greatest(dt, 0) / 60) then bad := 'reach';
    elsif greatest(public.econ_n(d -> 'maxMapTierReachedDim1'), 1) > reach then bad := 'reach';
    elsif exists (select 1 from jsonb_each(public.econ_obj(d -> 'dimReach')) x
                   where x.key !~ '^[0-9]+$' or x.key::numeric > mxd or public.econ_n(x.value) > (B ->> 'tierMax')::numeric
                      or public.econ_n(x.value) > greatest(public.econ_n(public.econ_obj(o -> 'dimReach') -> x.key), 1) + 1 + floor(greatest(dt, 0) / 60)) then bad := 'reach';
    elsif exists (select 1 from jsonb_each_text(public.econ_obj(d -> 'dimCleared')) x
                   where x.value = 'true' and coalesce(public.econ_obj(o -> 'dimCleared') ->> x.key, 'false') <> 'true'
                     and (x.key !~ '^[0-9]+$' or x.key::numeric > mxd
                          or (case when x.key = '1' then public.econ_n(d -> 'maxMapTierReachedDim1') else public.econ_n(public.econ_obj(d -> 'dimReach') -> x.key) end) < (B ->> 'tierMax')::numeric)) then bad := 'cleared';
    end if;
  end if;

  -- ---------- 3. items ----------
  if bad is null then
    -- equipment: a piece seen before may only gain refine levels; a new piece must be a real item of its rarity,
    -- from a map already reached, fresh (+0), with bonus points inside what its rarity/tier can roll
    select min(case
             when oe is not null then
               case when (ne -> 'defId') is distinct from (oe -> 'defId') or (ne -> 'rarity') is distinct from (oe -> 'rarity')
                         or (ne -> 'rolledStats') is distinct from (oe -> 'rolledStats') or (ne -> 'rollQuality') is distinct from (oe -> 'rollQuality') then 'item_changed'
                    when public.econ_n(ne -> 'refineLevel') < public.econ_n(oe -> 'refineLevel') or public.econ_n(ne -> 'refineLevel') > (B ->> 'refineMax')::numeric
                         or public.econ_n(ne -> 'refineLevel') <> floor(public.econ_n(ne -> 'refineLevel')) then 'refine' end
             when C -> 'items' -> base is null then 'item_def'
             when ne ->> 'rarity' is distinct from C -> 'items' -> base ->> 0 then 'item_rarity'
             when tier > reach then 'item_tier'
             when public.econ_n(ne -> 'refineLevel') <> 0 then 'item_refine'
             when jsonb_typeof(ne -> 'rollQuality') not in ('null', 'number') or public.econ_n(ne -> 'rollQuality') not between 0 and 100 then 'item_stats'
             when jsonb_typeof(ne -> 'rolledStats') <> 'object' then 'item_stats'
             when exists (select 1 from jsonb_each(ne -> 'rolledStats') s
                           where s.key not in ('STR','AGI','DEX','VIT','LUK','MEDITATE') or jsonb_typeof(s.value) <> 'number'
                              or public.econ_n(s.value) < 0 or public.econ_n(s.value) <> floor(public.econ_n(s.value))) then 'item_stats'
             when (select coalesce(sum(public.econ_n(s.value)), 0) from jsonb_each(ne -> 'rolledStats') s)
                  > case when (C -> 'items' -> base ->> 1) = '1' then 0 else greatest(3, round((C -> 'pts' ->> (ne ->> 'rarity'))::numeric * tier)) end then 'item_stats'
           end),
           coalesce(sum(case when oe is not null then (public.econ_n(ne -> 'refineLevel') * (public.econ_n(ne -> 'refineLevel') + 1)
                                                      - public.econ_n(oe -> 'refineLevel') * (public.econ_n(oe -> 'refineLevel') + 1)) / 2 end), 0),
           coalesce(sum(case when oe is not null then public.econ_n(ne -> 'refineLevel') - public.econ_n(oe -> 'refineLevel') end), 0),
           count(*) filter (where oe is null and not ((C -> 'starter') ? (ne ->> 'defId'))),
           coalesce(sum(case when oe is null then case ne ->> 'rarity' when 'rare' then 1 when 'epic' then 4 when 'legendary' then 12 else 0 end end), 0),
           count(*) filter (where oe is null and (C -> 'starter') ? (ne ->> 'defId'))
      into bad, rmana, rsteps, neq, luck, nstarter
      from (select n.e ne, oo.e oe, regexp_replace(coalesce(n.e ->> 'defId', ''), '_t[0-9]+$', '') base,
                   coalesce(substring(n.e ->> 'defId' from '_t([0-9]+)$')::int, 1) tier
              from public.econ_items_all(d) n(e)
              left join lateral (select x from public.econ_items_all(o) x where x ->> 'kind' = 'equipment' and x ->> 'instanceId' = n.e ->> 'instanceId' limit 1) oo(e) on true
             where n.e ->> 'kind' = 'equipment') q;
  end if;
  if bad is null and (jsonb_array_length(public.econ_arr(d -> 'inventory')) > greatest((B ->> 'bag')::int, jsonb_array_length(public.econ_arr(o -> 'inventory')))
                      or jsonb_array_length(public.econ_arr(d -> 'storage')) > greatest((B ->> 'storage')::int, jsonb_array_length(public.econ_arr(o -> 'storage')))
                      or jsonb_array_length(public.econ_arr(d -> 'buyback')) > 12) then
    bad := 'bag';
  end if;
  if bad is null then
    -- stackables: known ids, sane counts
    if exists (select 1 from public.econ_items_all(d) x
                where jsonb_typeof(x) <> 'object'
                   or (coalesce(x ->> 'kind', '') <> 'equipment' and coalesce(x ->> 'id', '') ~ '^sample_t[0-9]{1,2}$' and substring(x ->> 'id' from 9)::int > reach)
                   or (coalesce(x ->> 'kind', '') <> 'equipment' and (not ((C -> 'stack') ? coalesce(x ->> 'id', ''))
                        or public.econ_n(x -> 'qty') < 1 or public.econ_n(x -> 'qty') > 99999 or public.econ_n(x -> 'qty') <> floor(public.econ_n(x -> 'qty'))))) then
      bad := 'stack';
    end if;
  end if;
  if bad is null then
    -- what sold items could have paid (equipment + stack drops that left the save), what new stack units arrived
    select coalesce(sum((C -> 'eqPrice' ->> (x ->> 'rarity'))::numeric), 0) into sale
      from public.econ_items(o) x
     where x ->> 'kind' = 'equipment' and (C -> 'eqPrice') ? coalesce(x ->> 'rarity', '')
       and not exists (select 1 from public.econ_items(d) y where y ->> 'kind' = 'equipment' and y ->> 'instanceId' = x ->> 'instanceId');
    -- v45 buy-back: equipment that came back from the list costs its sale price again
    select coalesce(sum((C -> 'eqPrice' ->> (x ->> 'rarity'))::numeric), 0) into rebuy
      from jsonb_array_elements(public.econ_arr(o -> 'buyback')) x
     where x ->> 'kind' = 'equipment' and (C -> 'eqPrice') ? coalesce(x ->> 'rarity', '')
       and exists (select 1 from public.econ_items(d) y where y ->> 'kind' = 'equipment' and y ->> 'instanceId' = x ->> 'instanceId')
       and not exists (select 1 from public.econ_items(o) y where y ->> 'kind' = 'equipment' and y ->> 'instanceId' = x ->> 'instanceId');
    for k in
      select x ->> 'id' id,
             sum(case when w = 'n' then q else 0 end) nqq, sum(case when w = 'o' then q else 0 end) oqq,
             sum(case when w = 'nb' then q else 0 end) nbq, sum(case when w = 'ob' then q else 0 end) obq
        from (select 'n' w, x, public.econ_n(x -> 'qty') q from public.econ_items(d) x
              union all select 'o', x, public.econ_n(x -> 'qty') from public.econ_items(o) x where (C -> 'stack') ? coalesce(x ->> 'id', '')
              union all select 'nb', x, public.econ_n(x -> 'qty') from jsonb_array_elements(public.econ_arr(d -> 'buyback')) x
              union all select 'ob', x, public.econ_n(x -> 'qty') from jsonb_array_elements(public.econ_arr(o -> 'buyback')) x) a
       where coalesce(x ->> 'kind', '') <> 'equipment'
       group by 1
    loop
      -- stacks only enter the buy-back list by leaving the bag/box (being sold) — never from nowhere
      if k.nbq - k.obq > greatest(k.oqq - k.nqq, 0) then bad := 'buyback'; exit; end if;
      rq := least(greatest(k.nqq - k.oqq, 0), greatest(k.obq - k.nbq, 0));   -- bought back: paid for, not a drop
      rebuy := rebuy + rq * coalesce((C -> 'price' ->> k.id)::numeric, 0);
      if k.id = 'old_letter' and k.oqq > k.nqq then lgone := k.oqq - k.nqq; end if;   -- letters handed in (v9: many at once)
      if k.id = 'mana_stone' then newmana := greatest(k.nqq - k.oqq - rq + rmana, 0);   -- refining spent some
        units := units + newmana;
      elsif (C -> 'shopOnly') ? k.id then nshop := nshop + greatest(k.nqq - k.oqq - rq, 0);
      else units := units + greatest(k.nqq - k.oqq - rq, 0);
      end if;
      if k.oqq > k.nqq then sale := sale + (k.oqq - k.nqq) * coalesce((C -> 'price' ->> k.id)::numeric, 0); end if;
    end loop;
    if rmana > 0 and newmana is null then units := units + rmana; end if;     -- refined with stones that aren't in either save
  end if;

  -- ---------- 4. counters (titles read these) ----------
  if bad is null then
    dk := greatest(hc - ohc, 0);
    delite := greatest(public.econ_n(st -> 'eliteKills') - public.econ_n(ost -> 'eliteKills'), 0);
    if exists (select 1 from jsonb_each(public.econ_obj(d -> 'huntCounts')) x
                where x.key !~ '^[0-5]$' or public.econ_n(x.value) < public.econ_n(public.econ_obj(o -> 'huntCounts') -> x.key)
                   or public.econ_n(x.value) <> floor(public.econ_n(x.value))) then bad := 'hunt';
    elsif public.econ_n(st -> 'kills') > hc + 1 then bad := 'kills';
    elsif public.econ_n(st -> 'eliteKills') > greatest(public.econ_n(st -> 'kills'), hc) or public.econ_n(st -> 'flawless') > greatest(public.econ_n(st -> 'kills'), hc) then bad := 'kills';
    elsif public.econ_n(st -> 'untouchableBossKills') > public.econ_n(public.econ_obj(d -> 'huntCounts') -> '5') then bad := 'kills';
    elsif (public.econ_n(st -> 'perfectHits') + public.econ_n(st -> 'crits') + public.econ_n(st -> 'counters') + public.econ_n(st -> 'perfectDodges'))
        - (public.econ_n(ost -> 'perfectHits') + public.econ_n(ost -> 'crits') + public.econ_n(ost -> 'counters') + public.econ_n(ost -> 'perfectDodges'))
        > 200 * dk + 200 then bad := 'combat';
    elsif public.econ_n(st -> 'bestPerfectStreak') > greatest(public.econ_n(ost -> 'bestPerfectStreak'), public.econ_n(st -> 'perfectHits') - public.econ_n(ost -> 'perfectHits')) + 10 then bad := 'combat';
    elsif public.econ_n(st -> 'dungeons') - public.econ_n(ost -> 'dungeons') > floor(dk / 3) + 1
       or public.econ_n(st -> 'chestsOpened') - public.econ_n(ost -> 'chestsOpened') > dk + 1 then bad := 'dungeon';
    elsif public.econ_n(st -> 'secrets') - public.econ_n(ost -> 'secrets') > 5 + floor(greatest(dt, 0) / 10)
       or public.econ_n(st -> 'meditations') - public.econ_n(ost -> 'meditations') > 1 + floor(greatest(dt, 0) / 20)
       or public.econ_n(st -> 'letters') - public.econ_n(ost -> 'letters') > greatest(1 + floor(greatest(dt, 0) / 30), lgone + 1)
       or public.econ_n(st -> 'deaths') - public.econ_n(ost -> 'deaths') > 1 + floor(greatest(dt, 0) / 3)
       or public.econ_n(st -> 'refines') - public.econ_n(ost -> 'refines') > rsteps + 3 then bad := 'counters';
    elsif exists (select 1 from jsonb_each(public.econ_obj(st -> 'bossTiers')) x where x.key !~ '^[0-9]+$' or x.key::numeric > reach) then bad := 'counters';
    end if;
  end if;
  if bad is null then
    -- weapon ranks: EXP only from fighting, skills only as many as the rank has earned
    select coalesce(sum(public.econ_n(n.value -> 'exp') - public.econ_n(public.econ_obj(public.econ_obj(op -> 'weaponRank') -> n.key) -> 'exp')), 0)
      into tmp from jsonb_each(public.econ_obj(np -> 'weaponRank')) n;
    if tmp > 800 * dk + 800 then bad := 'rank';
    elsif exists (select 1 from jsonb_each(public.econ_obj(np -> 'weaponRank')) n
                   where (select count(*) from jsonb_object_keys(public.econ_obj(n.value -> 'unlockedSkills')))
                         > greatest((select coalesce(sum((t ->> 1)::int), 0) from jsonb_array_elements(coalesce(C -> 'skill' -> n.key, '[]')) t
                                      where public.econ_rank(public.econ_n(n.value -> 'exp')) >= (t ->> 0)::int),
                                    (select count(*) from jsonb_object_keys(public.econ_obj(public.econ_obj(public.econ_obj(op -> 'weaponRank') -> n.key) -> 'unlockedSkills'))))) then bad := 'skills';
    end if;
    if bad is null then
      select coalesce(sum(public.econ_n(s.value)), 0) into tmp
        from jsonb_each(public.econ_obj(np -> 'weaponRank')) n, jsonb_each(public.econ_obj(n.value -> 'unlockedSkills')) s;
      select coalesce(sum(public.econ_n(s.value)), 0) into tmp2
        from jsonb_each(public.econ_obj(op -> 'weaponRank')) n, jsonb_each(public.econ_obj(n.value -> 'unlockedSkills')) s;
      if tmp - tmp2 > 3000 * dk + 3000 then bad := 'skills'; end if;
    end if;
  end if;
  if bad is null then
    -- titles: each newly unlocked one must have reached its goal; the worn one must be unlocked
    for k in select x id from jsonb_array_elements_text(public.econ_arr(d -> 'unlockedTitles')) x
              where not (public.econ_arr(o -> 'unlockedTitles') ? x) loop
      if not ((C -> 'titles') ? k.id) then bad := 'title'; exit; end if;
      if tstats is null then tstats := public.econ_title_stats(d); end if;
      if public.econ_n(tstats -> (C -> 'titles' -> k.id ->> 0)) < (C -> 'titles' -> k.id ->> 1)::numeric then bad := 'title:' || k.id; exit; end if;
    end loop;
    if bad is null and jsonb_typeof(np -> 'titleId') = 'string' and not (public.econ_arr(d -> 'unlockedTitles') ? (np ->> 'titleId')) then bad := 'titleId'; end if;
  end if;
  if bad is null then
    -- discoveries: real ids; a newly discovered equipment has to be (or have been) owned
    select count(*) filter (where not (x like 'equipment:%' or x like 'card:%' or x like 'consumable:%')
                               or (x like 'equipment:%' and not ((C -> 'items') ? regexp_replace(substr(x, 11), '_t[0-9]+$', '')))
                               or (x like 'card:%' and not ((C -> 'cards') ? substr(x, 6)))
                               or (x like 'consumable:%' and not ((C -> 'stack') ? substr(x, 12)))),
           count(*) filter (where x like 'equipment:%'
                               and not exists (select 1 from public.econ_items(d) i where i ->> 'defId' = substr(x, 11))
                               and not exists (select 1 from public.econ_items(o) i where i ->> 'defId' = substr(x, 11))
                               and not exists (select 1 from public.item_registry r where r.user_id = me and r.def = substr(x, 11)))
      into tmp, tmp2
      from jsonb_array_elements_text(public.econ_arr(d -> 'discoveredItems')) x
     where not (public.econ_arr(o -> 'discoveredItems') ? x);
    if tmp > 0 or tmp2 > 6 then bad := 'discovery';
    elsif tmp2 > 0 and (jsonb_array_length(public.econ_arr(d -> 'inventory')) < (B ->> 'bag')::int
                        or jsonb_array_length(public.econ_arr(d -> 'storage')) < (B ->> 'storage')::int) then   -- bag + box full = drops are lost, that's honest
      flags := flags || jsonb_build_array(jsonb_build_object('kind', 'discovery', 'n', tmp2)); end if;
  end if;
  if bad is null then
    if jsonb_typeof(public.econ_obj(np -> 'story') -> 'done') not in ('array', 'null') and (np -> 'story' -> 'done') is not null then bad := 'quest';
    elsif exists (select 1 from jsonb_array_elements(public.econ_arr(public.econ_obj(np -> 'story') -> 'done')) x
                   where jsonb_typeof(x) <> 'string' or not ((C -> 'quests') ? (x #>> '{}'))) then bad := 'quest';
    elsif exists (select 1 from jsonb_array_elements_text(public.econ_arr(public.econ_obj(op -> 'story') -> 'done')) x
                   where (C -> 'quests') ? x and not (public.econ_arr(public.econ_obj(np -> 'story') -> 'done') ? x)) then bad := 'quest';
    else
      select coalesce(sum((C -> 'quests' -> x ->> 0)::numeric), 0), coalesce(sum((C -> 'quests' -> x ->> 1)::numeric), 0),
             coalesce(sum((C -> 'quests' -> x ->> 2)::numeric), 0), coalesce(max((C -> 'quests' -> x ->> 3)::numeric), 0)
        into qg, qx, qgear, tmp
        from (select distinct x from jsonb_array_elements_text(public.econ_arr(public.econ_obj(np -> 'story') -> 'done')) x
               where not (public.econ_arr(public.econ_obj(op -> 'story') -> 'done') ? x)) q;
      if tmp > reach then bad := 'quest'; end if;
    end if;
  end if;
  if bad is not null then return jsonb_build_object('ok', false, 'reason', 'invalid', 'detail', bad); end if;

  -- ---------- 5. earnings tied to kills ----------
  tr := least(reach, (B ->> 'tierMax')::numeric)::int;
  dm := 1 + (C ->> 'dimStep')::numeric * (mxd - 1);
  select coalesce(sum(greatest(public.econ_n(x.value) - public.econ_n(public.econ_obj(o -> 'huntCounts') -> x.key), 0) * (C -> 'tiers' -> tr::text -> 'g' ->> x.key::int)::numeric), 0),
         coalesce(sum(greatest(public.econ_n(x.value) - public.econ_n(public.econ_obj(o -> 'huntCounts') -> x.key), 0) * (C -> 'tiers' -> tr::text -> 'x' ->> x.key::int)::numeric), 0)
    into lim_g, lim_x from jsonb_each(public.econ_obj(d -> 'huntCounts')) x;
  lim_g := ceil(lim_g * dm + delite * (C -> 'tiers' -> tr::text -> 'g' ->> 4)::numeric * dm * ((C ->> 'eliteMult')::numeric - 1) + dk * dm)
         + sale + 50 * greatest(public.econ_n(st -> 'chestsOpened') - public.econ_n(ost -> 'chestsOpened'), 0)
         + 60 * greatest(public.econ_n(st -> 'letters') - public.econ_n(ost -> 'letters'), 0) + 120 + qg;
  lim_x := ceil(lim_x * dm + delite * (C -> 'tiers' -> tr::text -> 'x' ->> 4)::numeric * dm * ((C ->> 'eliteMult')::numeric - 1) + dk * dm) + 80 + qx;
  -- shop goods cost money: a starter weapon 20, a herb/potion at least 8 (beyond what kills could have dropped) —
  -- so free copies from the console can't be sold back for gold
  lim_g := lim_g - 20 * nstarter - 8 * greatest(nshop - 2 * dk, 0) - rebuy;   -- v45: buying back costs what the sale paid
  if g - og > lim_g then return jsonb_build_object('ok', false, 'reason', 'econ', 'detail', 'gold', 'n', g - og, 'max', lim_g); end if;
  if (50 * lv * (lv - 1) + xp) - (50 * olv * (olv - 1) + oxp) > lim_x then
    return jsonb_build_object('ok', false, 'reason', 'econ', 'detail', 'exp', 'n', (50 * lv * (lv - 1) + xp) - (50 * olv * (olv - 1) + oxp), 'max', lim_x);
  end if;
  if public.econ_n(st -> 'goldEarned') - public.econ_n(ost -> 'goldEarned') > lim_g + rebuy then bad := 'goldEarned'; end if;   -- spending on a buy-back isn't earning
  if bad is not null then return jsonb_build_object('ok', false, 'reason', 'invalid', 'detail', bad); end if;

  -- ---------- 6. how fast: kills and new items vs a budget that refills with time (30 min max) ----------
  acc := least(greatest(dt, 0), 900);
  bank_k := least(coalesce(public.econ_n(p_econ -> 'k'), rk * 1800) + rk * acc, rk * 1800);
  bank_u := least(coalesce(public.econ_n(p_econ -> 'u'), ru * 1800) + ru * acc, ru * 1800);
  if jsonb_typeof(p_econ) is distinct from 'object' then bank_k := rk * 1800; bank_u := ru * 1800; end if;
  -- v66 🎣 a fish takes at least ~4 s (bite + reeling): each one caught may bring one new stack item
  if fishd > floor(acc / 4) + 3 then return jsonb_build_object('ok', false, 'reason', 'econ', 'detail', 'fish', 'n', fishd, 'max', floor(acc / 4) + 3); end if;
  units := greatest(units - 3 - fishd - public.econ_n(st -> 'chestsOpened') + public.econ_n(ost -> 'chestsOpened')
                            - public.econ_n(st -> 'secrets') + public.econ_n(ost -> 'secrets')
                            - public.econ_n(st -> 'letters') + public.econ_n(ost -> 'letters'), 0);
  -- new gear only comes from kills (≤3 pieces each), letters, secret spots and the one-time collector medal
  if neq > 3 * dk + greatest(public.econ_n(st -> 'letters') - public.econ_n(ost -> 'letters'), 0) + greatest(public.econ_n(st -> 'secrets') - public.econ_n(ost -> 'secrets'), 0)
            + (case when public.econ_arr(d -> 'unlockedMilestones') ? 'collection_50' and not (public.econ_arr(o -> 'unlockedMilestones') ? 'collection_50') then 1 else 0 end) + qgear then
    return jsonb_build_object('ok', false, 'reason', 'econ', 'detail', 'items', 'n', neq, 'max', 3 * dk);
  end if;
  units := units + greatest(neq - greatest(public.econ_n(st -> 'letters') - public.econ_n(ost -> 'letters'), 0) - qgear, 0); -- gear handed out for letters / story quests doesn't need kills
  if units > 5 * dk + 3 then return jsonb_build_object('ok', false, 'reason', 'econ', 'detail', 'items', 'n', units, 'max', 5 * dk + 3); end if;
  -- bosses / elites can't be farmed faster than they appear; rare+ gear needs kills that could have dropped it
  dboss := greatest(public.econ_n(public.econ_obj(d -> 'huntCounts') -> '5') - public.econ_n(public.econ_obj(o -> 'huntCounts') -> '5'), 0);
  bank_b := least(coalesce(public.econ_n(p_econ -> 'b'), 20) + rb * acc, 20);
  bank_e := least(coalesce(public.econ_n(p_econ -> 'e'), 20) + rb * acc, 20);
  bank_l := least(coalesce(public.econ_n(p_econ -> 'l'), 30) + 0.3 * greatest(dk - dboss - delite, 0) + 3 * dboss + 1 * delite, 30);
  if jsonb_typeof(p_econ) is distinct from 'object' then bank_b := 20; bank_e := 20; bank_l := 30; end if;
  if dboss > bank_b + 5 then return jsonb_build_object('ok', false, 'reason', 'econ', 'detail', 'bosses', 'n', dboss, 'max', floor(bank_b + 5)); end if;
  if delite > bank_e + 5 then return jsonb_build_object('ok', false, 'reason', 'econ', 'detail', 'elites', 'n', delite, 'max', floor(bank_e + 5)); end if;
  if luck > bank_l + 24 then return jsonb_build_object('ok', false, 'reason', 'econ', 'detail', 'rare', 'n', luck, 'max', floor(bank_l + 24)); end if;
  if dboss > bank_b then flags := flags || jsonb_build_array(jsonb_build_object('kind', 'fast_bosses', 'n', dboss)); bank_b := 0; else bank_b := bank_b - dboss; end if;
  if delite > bank_e then flags := flags || jsonb_build_array(jsonb_build_object('kind', 'fast_elites', 'n', delite)); bank_e := 0; else bank_e := bank_e - delite; end if;
  if luck > bank_l then flags := flags || jsonb_build_array(jsonb_build_object('kind', 'lucky', 'n', luck, 'bank', floor(bank_l))); bank_l := 0; else bank_l := bank_l - luck; end if;
  if dk > bank_k + rk * 300 then return jsonb_build_object('ok', false, 'reason', 'econ', 'detail', 'kills', 'n', dk, 'max', floor(bank_k + rk * 300)); end if;
  if units > bank_u + ru * 300 then return jsonb_build_object('ok', false, 'reason', 'econ', 'detail', 'items', 'n', units, 'max', floor(bank_u + ru * 300)); end if;
  if dk > bank_k then flags := flags || jsonb_build_array(jsonb_build_object('kind', 'fast_kills', 'n', dk, 'bank', floor(bank_k))); bank_k := 0; else bank_k := bank_k - dk; end if;
  if units > bank_u then flags := flags || jsonb_build_array(jsonb_build_object('kind', 'fast_items', 'n', units, 'bank', floor(bank_u))); bank_u := 0; else bank_u := bank_u - units; end if;
  return jsonb_build_object('ok', true, 'econ', jsonb_build_object('k', round(bank_k, 2), 'u', round(bank_u, 2), 'b', round(bank_b, 3), 'e', round(bank_e, 3), 'l', round(bank_l, 2)), 'flags', flags);
end $$;
revoke execute on function public.econ_data(), public.econ_n(jsonb), public.econ_obj(jsonb), public.econ_arr(jsonb), public.econ_items(jsonb), public.econ_items_all(jsonb),
  public.econ_rank(numeric), public.econ_title_stats(jsonb), public.econ_check(uuid, jsonb, jsonb, jsonb, numeric) from public, anon, authenticated;

-- v52: how many story chapters this server's econ_data() already knows. The game only offers chapters up to this number,
-- so a newer index.html uploaded before this SQL can never make a save carry a quest id the server would reject.
create or replace function public.story_chapters() returns int language sql immutable as $$ select 10 $$;
grant execute on function public.story_chapters() to anon, authenticated;
-- v66: systems the client may switch on (it asks once at login; missing function = all off)
create or replace function public.game_features() returns jsonb language sql immutable as $$ select '{"fish":1}'::jsonb $$;
grant execute on function public.game_features() to anon, authenticated;

-- one flag row per kind per minute at most (a cheat client retrying can't flood the table)
create or replace function public.econ_flag(p_user uuid, p_kind text, p_detail jsonb, p_rejected boolean)
returns void language sql security definer set search_path = public as $$
  insert into public.econ_flags (user_id, kind, detail, rejected)
  select p_user, p_kind, p_detail, p_rejected
   where not exists (select 1 from public.econ_flags where user_id = p_user and kind = p_kind and created_at > now() - interval '1 minute') $$;
revoke execute on function public.econ_flag(uuid, text, jsonb, boolean) from public, anon, authenticated;

-- Called once per login: this device becomes the only one allowed to save; returns the save.
create or replace function public.claim_session(p_session uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  r public.saves;
begin
  if me is null then raise exception 'not signed in'; end if;
  if public.mod_active(me, 'ban') is not null then   -- banned: no session, no save
    return jsonb_build_object('banned', public.mod_active(me, 'ban'), 'mv', public.min_game_version());
  end if;
  insert into public.saves (user_id, session_id, claimed_at) values (me, p_session, now())
    on conflict (user_id) do update set session_id = excluded.session_id, claimed_at = now()
    returning * into r;
  return jsonb_build_object('data', r.data, 'rev', r.rev, 'mv', public.min_game_version(),
                            'admin', exists (select 1 from public.admins a where a.user_id = me));
end $$;

-- Every autosave. Rejected (nothing written) when: another device took over (session), a stale save
-- (rev), an equipment piece without an id (nouid), the same piece twice or a piece that already left
-- this account (dupe), a malformed or oversized save (format / size).
create or replace function public.save_game(p_session uuid, p_rev bigint, p_data jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  r public.saves;
  uids text[];
  missing int;
  chk jsonb;
begin
  if me is null then raise exception 'not signed in'; end if;
  select * into r from public.saves where user_id = me for update;
  if not found or r.session_id is distinct from p_session then
    return jsonb_build_object('ok', false, 'reason', 'session');
  end if;
  if r.rev <> p_rev then return jsonb_build_object('ok', false, 'reason', 'rev'); end if;
  if public.mod_active(me, 'ban') is not null then return jsonb_build_object('ok', false, 'reason', 'banned'); end if;
  if public.mod_kicked(me) is not null then return jsonb_build_object('ok', false, 'reason', 'kicked'); end if;
  if public.lb_num(p_data -> 'gv') < public.min_game_version() then return jsonb_build_object('ok', false, 'reason', 'version'); end if;
  if octet_length(p_data::text) > 1500000 then return jsonb_build_object('ok', false, 'reason', 'size'); end if;
  if jsonb_typeof(p_data -> 'inventory') is distinct from 'array'
     or jsonb_typeof(p_data -> 'storage') is distinct from 'array'
     or jsonb_typeof(p_data -> 'player') is distinct from 'object' then
    return jsonb_build_object('ok', false, 'reason', 'format');
  end if;

  select coalesce(array_agg(e ->> 'instanceId'), '{}'),
         count(*) filter (where coalesce(e ->> 'instanceId', '') = '')
    into uids, missing
    from (select jsonb_array_elements(p_data -> 'inventory') e
          union all
          select jsonb_array_elements(p_data -> 'storage')
          union all
          select jsonb_array_elements(public.econ_arr(p_data -> 'buyback'))) x   -- v45: buy-back list
   where e ->> 'kind' = 'equipment';

  if missing > 0 then return jsonb_build_object('ok', false, 'reason', 'nouid'); end if;
  if cardinality(uids) <> (select count(distinct u) from unnest(uids) u) then
    return jsonb_build_object('ok', false, 'reason', 'dupe');
  end if;
  if exists (select 1 from public.item_registry i
              where i.user_id = me and not i.alive and i.uid = any (uids)) then
    return jsonb_build_object('ok', false, 'reason', 'dupe');
  end if;

  -- economy guard (see ECONOMY GUARD above) — GM accounts are exempt
  if not public.is_gm(me) then
    chk := public.econ_check(me, r.data, p_data, r.econ, extract(epoch from now() - r.updated_at));
    if coalesce((chk ->> 'ok')::boolean, false) is not true then
      perform public.econ_flag(me, (chk ->> 'reason') || ':' || coalesce(chk ->> 'detail', '?'), chk, true);
      return jsonb_build_object('ok', false, 'reason', chk ->> 'reason', 'detail', chk ->> 'detail');
    end if;
    perform public.econ_flag(me, f ->> 'kind', f, false) from jsonb_array_elements(coalesce(chk -> 'flags', '[]')) f;
  end if;

  update public.item_registry set alive = false
   where user_id = me and alive and not (uid = any (uids));
  insert into public.item_registry (user_id, uid, def)
    select me, x ->> 'instanceId', x ->> 'defId' from public.econ_items_all(p_data) x where x ->> 'kind' = 'equipment'
    on conflict (user_id, uid) do update set def = coalesce(public.item_registry.def, excluded.def);

  update public.saves set data = p_data, rev = rev + 1, updated_at = now(), econ = coalesce(chk -> 'econ', econ),
         progress_at = case when progress_at is null or public.lb_key(p_data) > public.lb_key(r.data) then now() else progress_at end
   where user_id = me returning * into r;
  return jsonb_build_object('ok', true, 'rev', r.rev);
end $$;

-- GM accounts (public.admins) — the game shows [GM] over these players' heads. The list comes from here,
-- so a player can't tag themselves by editing what their own game sends.
create or replace function public.staff_ids()
returns uuid[] language sql stable security definer set search_path = public as $$
  select coalesce(array_agg(user_id), '{}') from public.admins
$$;

revoke execute on function public.claim_session(uuid), public.save_game(uuid, bigint, jsonb), public.staff_ids() from public, anon;
grant execute on function public.claim_session(uuid), public.save_game(uuid, bigint, jsonb), public.staff_ids() to authenticated;

-- ============================================================
-- SOCIAL — friends, whispers, blocks, reports, player profiles (right-click menu on other players).
-- Everything goes through the functions below; the sender is always auth.uid(), never what the game says.
-- ============================================================
create table if not exists public.player_status (      -- heartbeat every few seconds from net_poll()
  user_id      uuid primary key references auth.users(id) on delete cascade,
  last_seen    timestamptz not null default now(),
  dim          int not null default 1,
  map          int not null default 0,
  x            int,
  y            int,
  last_whisper timestamptz
);
create table if not exists public.friends (             -- one row per direction; accepted on both once mutual
  user_id    uuid not null references auth.users(id) on delete cascade,
  friend_id  uuid not null references auth.users(id) on delete cascade,
  accepted   boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (user_id, friend_id)
);
create table if not exists public.blocks (
  user_id    uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, blocked_id)
);
create table if not exists public.whispers (            -- a mailbox slot: deleted as soon as the receiver polls it
  id         bigserial primary key,
  from_id    uuid not null references auth.users(id) on delete cascade,
  to_id      uuid not null references auth.users(id) on delete cascade,
  body       text not null,
  created_at timestamptz not null default now()
);
create table if not exists public.reports (             -- GM reads these in Table Editor → reports
  id         bigserial primary key,
  reporter   uuid not null references auth.users(id) on delete cascade,
  target     uuid not null references auth.users(id) on delete cascade,
  reason     text not null,
  note       text,
  chat       jsonb,
  handled    boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists whispers_to_idx on public.whispers (to_id);
create index if not exists friends_friend_idx on public.friends (friend_id);
alter table public.player_status enable row level security;
alter table public.friends enable row level security;
alter table public.blocks enable row level security;
alter table public.whispers enable row level security;
alter table public.reports enable row level security;
revoke all on public.player_status, public.friends, public.blocks, public.whispers, public.reports from anon, authenticated;

-- helpers (not callable from the game)
create or replace function public.soc_name(p uuid) returns text language sql stable security definer set search_path = public as $$
  select coalesce((select data -> 'player' ->> 'name' from public.saves where user_id = p), '?') $$;
create or replace function public.soc_online(p uuid) returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.player_status where user_id = p and last_seen > now() - interval '15 seconds') $$;
create or replace function public.soc_blocked(a uuid, b uuid) returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.blocks where (user_id = a and blocked_id = b) or (user_id = b and blocked_id = a)) $$;
revoke execute on function public.soc_name(uuid), public.soc_online(uuid), public.soc_blocked(uuid, uuid) from public, anon, authenticated;

-- Heartbeat + mailbox: marks me online at this map, hands over (and deletes) whispers sent to me,
-- and returns the counters the game uses to notice new friend requests / accepted friends.
create or replace function public.net_poll(p_dim int, p_map int, p_x int, p_y int)
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); w jsonb; warns jsonb;
begin
  if me is null then raise exception 'not signed in'; end if;
  insert into public.player_status (user_id, last_seen, dim, map, x, y) values (me, now(), p_dim, p_map, p_x, p_y)
    on conflict (user_id) do update set last_seen = now(), dim = excluded.dim, map = excluded.map, x = excluded.x, y = excluded.y;
  delete from public.whispers where to_id = me and created_at < now() - interval '2 minutes'; -- stale: I was offline, drop
  with gone as (delete from public.whispers where to_id = me returning from_id, body, created_at)
  select coalesce(jsonb_agg(jsonb_build_object('from', from_id, 'name', public.soc_name(from_id), 'body', body) order by created_at), '[]')
    into w from gone;
  with sent as (update public.sanctions set delivered = true
                 where user_id = me and kind = 'warn' and not delivered and revoked_at is null returning reason, created_at)
  select coalesce(jsonb_agg(reason order by created_at), '[]') into warns from sent;
  return jsonb_build_object('w', w,
    'ban', public.mod_active(me, 'ban'), 'mute', public.mod_active(me, 'mute'), 'kick', public.mod_kicked(me), 'warns', warns,
    'muted', (select coalesce(jsonb_agg(distinct user_id), '[]') from public.sanctions where kind = 'mute' and revoked_at is null and until > now()),
    'ann', (select jsonb_build_object('id', id, 'body', body, 'at', created_at) from public.announcements
             where created_at > now() - interval '15 minutes' order by id desc limit 1),
    'req', (select coalesce(jsonb_agg(jsonb_build_object('id', f.user_id, 'name', public.soc_name(f.user_id))), '[]')
              from public.friends f where f.friend_id = me and not f.accepted),
    'fc', (select count(*) from public.friends where user_id = me and accepted),
    'mv', public.min_game_version(),
    'pv', (select count(*) from public.polls p where p.status = 'open' and p.closes_at > now()
             and not exists (select 1 from public.poll_votes v where v.poll_id = p.id and v.user_id = me))); -- open votes I haven't cast (town board "!")
end $$;

create or replace function public.whisper_send(p_to uuid, p_body text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); body text := btrim(regexp_replace(coalesce(p_body, ''), '\s+', ' ', 'g'));
begin
  if me is null then raise exception 'not signed in'; end if;
  if p_to = me or char_length(body) = 0 or char_length(body) > 120 then return jsonb_build_object('ok', false, 'reason', 'invalid'); end if;
  if public.mod_active(me, 'mute') is not null then return jsonb_build_object('ok', false, 'reason', 'muted'); end if;
  if public.soc_blocked(me, p_to) then return jsonb_build_object('ok', false, 'reason', 'blocked'); end if;
  if not public.soc_online(p_to) then return jsonb_build_object('ok', false, 'reason', 'offline'); end if;
  if exists (select 1 from public.player_status where user_id = me and last_whisper > now() - interval '1 second') then
    return jsonb_build_object('ok', false, 'reason', 'fast');
  end if;
  update public.player_status set last_whisper = now() where user_id = me;
  insert into public.whispers (from_id, to_id, body) values (me, p_to, body);
  return jsonb_build_object('ok', true);
end $$;

-- Ask to be friends; if they already asked me, this accepts instead.
create or replace function public.friend_request(p_to uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'not signed in'; end if;
  if p_to = me or not exists (select 1 from public.saves where user_id = p_to) then return jsonb_build_object('ok', false, 'reason', 'invalid'); end if;
  if public.soc_blocked(me, p_to) then return jsonb_build_object('ok', false, 'reason', 'blocked'); end if;
  if exists (select 1 from public.friends where user_id = p_to and friend_id = me) then
    update public.friends set accepted = true where user_id = p_to and friend_id = me;
    insert into public.friends (user_id, friend_id, accepted) values (me, p_to, true)
      on conflict (user_id, friend_id) do update set accepted = true;
    return jsonb_build_object('ok', true, 'state', 'friends');
  end if;
  if (select count(*) from public.friends where user_id = me) >= 100 then return jsonb_build_object('ok', false, 'reason', 'full'); end if;
  insert into public.friends (user_id, friend_id) values (me, p_to) on conflict do nothing;
  return jsonb_build_object('ok', true, 'state', 'pending');
end $$;

-- Unfriend / cancel my request / decline theirs — all the same: both directions go.
create or replace function public.friend_remove(p_other uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'not signed in'; end if;
  delete from public.friends where (user_id = me and friend_id = p_other) or (user_id = p_other and friend_id = me);
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.block_player(p_other uuid, p_on boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'not signed in'; end if;
  if p_other = me then return jsonb_build_object('ok', false, 'reason', 'invalid'); end if;
  if p_on then
    insert into public.blocks (user_id, blocked_id) values (me, p_other) on conflict do nothing;
    delete from public.friends where (user_id = me and friend_id = p_other) or (user_id = p_other and friend_id = me);
  else
    delete from public.blocks where user_id = me and blocked_id = p_other;
  end if;
  return jsonb_build_object('ok', true);
end $$;

-- Everything the friends window needs. Location only for accepted friends.
create or replace function public.friend_list()
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'not signed in'; end if;
  return jsonb_build_object(
    'friends', (select coalesce(jsonb_agg(jsonb_build_object(
        'id', o.id, 'name', public.soc_name(o.id),
        'level', (select (data -> 'player' ->> 'level')::int from public.saves where user_id = o.id),
        'state', o.state,
        'online', case when o.state = 'friends' then public.soc_online(o.id) else null end,
        'dim', case when o.state = 'friends' then s.dim end, 'map', case when o.state = 'friends' then s.map end,
        'x', case when o.state = 'friends' then s.x end, 'y', case when o.state = 'friends' then s.y end)), '[]')
      from (select coalesce(a.friend_id, b.user_id) id,
                   case when a.accepted then 'friends' when a.friend_id is not null then 'outgoing' else 'incoming' end state
              from (select * from public.friends where user_id = me) a
              full join (select * from public.friends where friend_id = me) b on b.user_id = a.friend_id) o
      left join public.player_status s on s.user_id = o.id),
    'blocked', (select coalesce(jsonb_agg(jsonb_build_object('id', blocked_id, 'name', public.soc_name(blocked_id))), '[]')
                  from public.blocks where user_id = me));
end $$;

-- Profile card (anyone) / full inspect (friends only), built from the target's cloud save.
create or replace function public.player_profile(p_target uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); d jsonb; friend boolean; eq jsonb; weapon jsonb;
begin
  if me is null then raise exception 'not signed in'; end if;
  select data into d from public.saves where user_id = p_target;
  if d is null then return jsonb_build_object('ok', false, 'reason', 'nosave'); end if;
  friend := exists (select 1 from public.friends where user_id = me and friend_id = p_target and accepted);
  select coalesce(jsonb_agg(e), '[]') into eq from jsonb_array_elements(d -> 'inventory') e
   where e ->> 'kind' = 'equipment'
     and e ->> 'instanceId' in (select value from jsonb_each_text(coalesce(d -> 'player' -> 'equipment', '{}')));
  select e into weapon from jsonb_array_elements(eq) e where e ->> 'instanceId' = d -> 'player' -> 'equipment' ->> 'weapon';
  return jsonb_build_object('ok', true, 'friend', friend, 'gm', exists (select 1 from public.admins where user_id = p_target),
    'online', public.soc_online(p_target),
    'name', d -> 'player' -> 'name', 'title', d -> 'player' -> 'title', 'level', d -> 'player' -> 'level',
    'look', d -> 'player' -> 'look', 'willColor', d -> 'player' -> 'willColor', 'weaponRank', d -> 'player' -> 'weaponRank',
    'maxDimension', d -> 'maxDimension', 'dimReach', d -> 'dimReach', 'maxMapTierReachedDim1', d -> 'maxMapTierReachedDim1',
    'weapon', weapon,
    'equipment', case when friend or p_target = me then d -> 'player' -> 'equipment' end,
    'equipped', case when friend or p_target = me then eq end,
    'statPoints', case when friend or p_target = me then d -> 'player' -> 'statPoints' end);
end $$;

-- Hall of Fame (town object): top 10 + my own rank. GM accounts (public.admins) are left out here, on the server.
create or replace function public.leaderboard()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare me uuid := auth.uid(); isgm boolean := public.is_gm(auth.uid());
begin
  if me is null then raise exception 'not signed in'; end if;
  return (
    with ranked as (
      select s.user_id, s.data, k, row_number() over (order by k desc, s.progress_at asc nulls last, s.user_id) rn
        from public.saves s cross join lateral (select public.lb_key(s.data) k) kk
       where s.data is not null and not exists (select 1 from public.admins a where a.user_id = s.user_id)
         and public.mod_active(s.user_id, 'ban') is null),
    rw as (
      select user_id, rn, jsonb_build_object('id', user_id, 'rank', rn, 'name', data -> 'player' -> 'name', 'title', data -> 'player' -> 'title',
               'dim', k[1], 'map', k[2], 'level', k[3], 'look', data -> 'player' -> 'look', 'willColor', data -> 'player' -> 'willColor',
               'flags', case when isgm then (select count(*) from public.econ_flags f where f.user_id = ranked.user_id and f.created_at > now() - interval '30 days') end) j
        from ranked)
    select jsonb_build_object(
      'total', (select count(*) from ranked),
      'gm', exists (select 1 from public.admins where user_id = me),
      'top', (select coalesce(jsonb_agg(j order by rn), '[]') from rw where rn <= 10),
      'me', (select j from rw where user_id = me)));
end $$;

create or replace function public.report_player(p_target uuid, p_reason text, p_note text, p_chat jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'not signed in'; end if;
  if p_target = me or p_reason not in ('chat', 'cheat', 'spam', 'other') then return jsonb_build_object('ok', false, 'reason', 'invalid'); end if;
  if (select count(*) from public.reports where reporter = me and created_at > now() - interval '1 hour') >= 10 then
    return jsonb_build_object('ok', false, 'reason', 'fast');
  end if;
  insert into public.reports (reporter, target, reason, note, chat)
    values (me, p_target, p_reason, left(coalesce(p_note, ''), 300),
            case when jsonb_typeof(p_chat) = 'array' then (select jsonb_agg(left(v #>> '{}', 120)) from (select v from jsonb_array_elements(p_chat) v limit 10) t) end);
  return jsonb_build_object('ok', true);
end $$;

revoke execute on function public.net_poll(int, int, int, int), public.whisper_send(uuid, text), public.friend_request(uuid),
  public.friend_remove(uuid), public.block_player(uuid, boolean), public.friend_list(), public.player_profile(uuid),
  public.report_player(uuid, text, text, jsonb), public.leaderboard() from public, anon;
grant execute on function public.net_poll(int, int, int, int), public.whisper_send(uuid, text), public.friend_request(uuid),
  public.friend_remove(uuid), public.block_player(uuid, boolean), public.friend_list(), public.player_profile(uuid),
  public.report_player(uuid, text, text, jsonb), public.leaderboard() to authenticated;
-- ============================================================
-- VOTE BOARD (🗳️ ป้ายประชามติ in town) — players propose a question with 2-4 choices, others back it; every
-- 12 h round (00:00 / 12:00 UTC) the most-backed proposal (≥ 2 backers) goes up for a 12 h vote. GMs can
-- post a vote directly and remove anything. Who may vote / propose / back: a linked (non-Guest) account at
-- Lv.10+ — one person, one voice. Counts stay hidden until a vote closes; a vote can be changed until then.
-- ============================================================
create table if not exists public.polls (
  id         bigserial primary key,
  question   text not null,
  options    jsonb not null,                    -- ["...", "..."] 2-4 choices
  status     text not null default 'proposal',  -- proposal | open | expired | removed ("closed" = open past closes_at)
  source     text not null default 'player',    -- player | gm
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  round      bigint not null default floor(extract(epoch from now()) / 43200),
  opened_at  timestamptz,
  closes_at  timestamptz
);
create table if not exists public.poll_votes (
  poll_id    bigint not null references public.polls(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  choice     smallint not null,
  updated_at timestamptz not null default now(),
  primary key (poll_id, user_id)
);
create table if not exists public.poll_supports (
  poll_id    bigint not null references public.polls(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  primary key (poll_id, user_id)
);
create index if not exists polls_status_idx on public.polls (status, round);
alter table public.polls enable row level security;
alter table public.poll_votes enable row level security;
alter table public.poll_supports enable row level security;
revoke all on public.polls, public.poll_votes, public.poll_supports from anon, authenticated;

-- helpers (not callable from the game)
create or replace function public.poll_ineligible(p uuid) returns text language sql stable security definer set search_path = public as $$
  select case when coalesce((select is_anonymous from auth.users where id = p), true) then 'guest'
              when public.lb_num((select data -> 'player' -> 'level' from public.saves where user_id = p)) < 10 then 'level'
              else null end $$;
-- trimmed, single-spaced text or null when empty / too long
create or replace function public.poll_clean(t text, maxlen int) returns text language sql immutable as $$
  select case when char_length(c) between 1 and maxlen then c end
    from (select btrim(regexp_replace(coalesce(t, ''), '\s+', ' ', 'g')) c) x $$;
-- validated choice list (2-4 distinct, ≤ 40 chars each) or null
create or replace function public.poll_clean_options(o jsonb) returns jsonb language plpgsql immutable as $$
declare out jsonb := '[]'; v text; c text;
begin
  if jsonb_typeof(o) is distinct from 'array' or jsonb_array_length(o) not between 2 and 4 then return null; end if;
  for v in select jsonb_array_elements_text(o) loop
    c := public.poll_clean(v, 40);
    if c is null or out ? c then return null; end if;
    out := out || to_jsonb(c);
  end loop;
  return out;
end $$;
-- round change: the most-backed proposal of every finished round opens for 12 h, the rest expire
create or replace function public.poll_tick() returns void language plpgsql security definer set search_path = public as $$
declare cur bigint := floor(extract(epoch from now()) / 43200); r bigint; best bigint;
begin
  if not exists (select 1 from public.polls where status = 'proposal' and round < cur) then return; end if;
  perform pg_advisory_xact_lock(7701);
  for r in select distinct round from public.polls where status = 'proposal' and round < cur order by 1 loop
    select p.id into best from public.polls p
      where p.status = 'proposal' and p.round = r
        and (select count(*) from public.poll_supports s where s.poll_id = p.id) >= 2
      order by (select count(*) from public.poll_supports s where s.poll_id = p.id) desc, p.created_at
      limit 1;
    if best is not null then
      update public.polls set status = 'open', opened_at = now(), closes_at = now() + interval '12 hours' where id = best;
    end if;
    update public.polls set status = 'expired' where status = 'proposal' and round = r;
  end loop;
end $$;
revoke execute on function public.poll_ineligible(uuid), public.poll_clean(text, int), public.poll_clean_options(jsonb), public.poll_tick()
  from public, anon, authenticated;

-- Everything the board shows. Open votes: my choice + how many voted (counts hidden until closed).
create or replace function public.poll_board()
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); cur bigint := floor(extract(epoch from now()) / 43200);
begin
  if me is null then raise exception 'not signed in'; end if;
  perform public.poll_tick();
  return jsonb_build_object(
    'now', now(), 'roundEnds', to_timestamp((cur + 1) * 43200),
    'ineligible', public.poll_ineligible(me),
    'gm', exists (select 1 from public.admins where user_id = me),
    'open', (select coalesce(jsonb_agg(jsonb_build_object('id', p.id, 'question', p.question, 'options', p.options, 'source', p.source,
               'closesAt', p.closes_at, 'voters', (select count(*) from public.poll_votes v where v.poll_id = p.id),
               'my', (select choice from public.poll_votes v where v.poll_id = p.id and v.user_id = me)) order by p.closes_at), '[]')
             from public.polls p where p.status = 'open' and p.closes_at > now()),
    'proposals', (select coalesce(jsonb_agg(x.j order by x.n desc, x.created_at), '[]') from (
               select p.created_at, (select count(*) from public.poll_supports s where s.poll_id = p.id) n,
                      jsonb_build_object('id', p.id, 'question', p.question, 'options', p.options,
                        'supports', (select count(*) from public.poll_supports s where s.poll_id = p.id),
                        'mine', exists (select 1 from public.poll_supports s where s.poll_id = p.id and s.user_id = me),
                        'own', p.created_by = me, 'by', public.soc_name(p.created_by)) j
                 from public.polls p where p.status = 'proposal' and p.round = cur) x),
    'closed', (select coalesce(jsonb_agg(x.j order by x.closes_at desc), '[]') from (
               select p.closes_at, jsonb_build_object('id', p.id, 'question', p.question, 'options', p.options, 'source', p.source,
                        'closedAt', p.closes_at,
                        'counts', (select jsonb_agg((select count(*) from public.poll_votes v where v.poll_id = p.id and v.choice = i) order by i)
                                     from generate_series(0, jsonb_array_length(p.options) - 1) i),
                        'my', (select choice from public.poll_votes v where v.poll_id = p.id and v.user_id = me)) j
                 from public.polls p where p.status = 'open' and p.closes_at <= now()
                 order by p.closes_at desc limit 20) x));
end $$;

create or replace function public.poll_vote(p_poll bigint, p_choice int)
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); why text; p public.polls;
begin
  if me is null then raise exception 'not signed in'; end if;
  why := public.poll_ineligible(me);
  if why is not null then return jsonb_build_object('ok', false, 'reason', why); end if;
  select * into p from public.polls where id = p_poll;
  if not found or p.status <> 'open' or p.closes_at <= now() then return jsonb_build_object('ok', false, 'reason', 'closed'); end if;
  if p_choice is null or p_choice < 0 or p_choice >= jsonb_array_length(p.options) then return jsonb_build_object('ok', false, 'reason', 'invalid'); end if;
  insert into public.poll_votes (poll_id, user_id, choice) values (p_poll, me, p_choice)
    on conflict (poll_id, user_id) do update set choice = excluded.choice, updated_at = now();
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.poll_propose(p_question text, p_options jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); why text; q text := public.poll_clean(p_question, 120); o jsonb := public.poll_clean_options(p_options);
        cur bigint := floor(extract(epoch from now()) / 43200); new_id bigint;
begin
  if me is null then raise exception 'not signed in'; end if;
  why := public.poll_ineligible(me);
  if why is not null then return jsonb_build_object('ok', false, 'reason', why); end if;
  if q is null or char_length(q) < 4 or o is null then return jsonb_build_object('ok', false, 'reason', 'invalid'); end if;
  if public.mod_active(me, 'mute') is not null then return jsonb_build_object('ok', false, 'reason', 'muted'); end if;
  if exists (select 1 from public.polls where created_by = me and status = 'proposal' and round = cur) then
    return jsonb_build_object('ok', false, 'reason', 'limit');
  end if;
  insert into public.polls (question, options, created_by, round) values (q, o, me, cur) returning id into new_id;
  insert into public.poll_supports (poll_id, user_id) values (new_id, me); -- the proposer backs it
  return jsonb_build_object('ok', true, 'id', new_id);
end $$;

create or replace function public.poll_support(p_poll bigint, p_on boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); why text;
begin
  if me is null then raise exception 'not signed in'; end if;
  why := public.poll_ineligible(me);
  if why is not null then return jsonb_build_object('ok', false, 'reason', why); end if;
  if not exists (select 1 from public.polls where id = p_poll and status = 'proposal' and round = floor(extract(epoch from now()) / 43200)) then
    return jsonb_build_object('ok', false, 'reason', 'closed');
  end if;
  if p_on then insert into public.poll_supports (poll_id, user_id) values (p_poll, me) on conflict do nothing;
  else delete from public.poll_supports where poll_id = p_poll and user_id = me; end if;
  return jsonb_build_object('ok', true);
end $$;

-- GM: open a vote right away (hours 1-72) / take down a proposal or vote
create or replace function public.poll_gm_create(p_question text, p_options jsonb, p_hours int)
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); q text := public.poll_clean(p_question, 120); o jsonb := public.poll_clean_options(p_options);
begin
  if me is null or not exists (select 1 from public.admins where user_id = me) then return jsonb_build_object('ok', false, 'reason', 'gm'); end if;
  if q is null or o is null then return jsonb_build_object('ok', false, 'reason', 'invalid'); end if;
  insert into public.polls (question, options, status, source, created_by, opened_at, closes_at)
    values (q, o, 'open', 'gm', me, now(), now() + make_interval(hours => least(greatest(coalesce(p_hours, 12), 1), 72)));
  return jsonb_build_object('ok', true);
end $$;
create or replace function public.poll_gm_remove(p_poll bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid();
begin
  if me is null or not exists (select 1 from public.admins where user_id = me) then return jsonb_build_object('ok', false, 'reason', 'gm'); end if;
  update public.polls set status = 'removed' where id = p_poll;
  return jsonb_build_object('ok', true);
end $$;

revoke execute on function public.poll_board(), public.poll_vote(bigint, int), public.poll_propose(text, jsonb), public.poll_support(bigint, boolean),
  public.poll_gm_create(text, jsonb, int), public.poll_gm_remove(bigint) from public, anon;
grant execute on function public.poll_board(), public.poll_vote(bigint, int), public.poll_propose(text, jsonb), public.poll_support(bigint, boolean),
  public.poll_gm_create(text, jsonb, int), public.poll_gm_remove(bigint) to authenticated;
-- ============================================================
-- MODERATION (🛡️ GM console) — ban / mute / kick / warn, server announcements, player lookup, reports.
-- Every action is checked here (caller must be in public.admins, target must not be); the sanctions
-- table doubles as the audit log. until = 'infinity' means permanent.
-- ============================================================
create table if not exists public.sanctions (
  id         bigserial primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  kind       text not null check (kind in ('ban', 'mute', 'kick', 'warn')),
  until      timestamptz not null default 'infinity',
  reason     text not null default '',
  by         uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  delivered  boolean not null default false,   -- warn: shown to the player yet
  revoked_at timestamptz,
  revoked_by uuid references auth.users(id) on delete set null
);
create index if not exists sanctions_user_idx on public.sanctions (user_id, kind);
create table if not exists public.announcements (
  id         bigserial primary key,
  body       text not null,
  by         uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
alter table public.saves add column if not exists claimed_at timestamptz; -- a kick after this = that device is out
alter table public.sanctions enable row level security;
alter table public.announcements enable row level security;
revoke all on public.sanctions, public.announcements from anon, authenticated;

-- helpers (not callable from the game)
create or replace function public.is_gm(p uuid) returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins where user_id = p) $$;
create or replace function public.mod_active(p uuid, k text) returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('until', until, 'reason', reason) from public.sanctions
   where user_id = p and kind = k and revoked_at is null and until > now()
   order by until desc limit 1 $$;
create or replace function public.mod_kicked(p uuid) returns text language sql stable security definer set search_path = public as $$
  select s.reason from public.sanctions s join public.saves v on v.user_id = s.user_id
   where s.user_id = p and s.kind = 'kick' and s.revoked_at is null and s.created_at > coalesce(v.claimed_at, '-infinity')
   order by s.created_at desc limit 1 $$;
revoke execute on function public.is_gm(uuid), public.mod_active(uuid, text), public.mod_kicked(uuid) from public, anon, authenticated;

-- GM: find players by name (empty = most recently seen)
create or replace function public.gm_search(p_query text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); q text := btrim(coalesce(p_query, ''));
begin
  if me is null or not public.is_gm(me) then return jsonb_build_object('ok', false, 'reason', 'gm'); end if;
  return jsonb_build_object('ok', true, 'players', (select coalesce(jsonb_agg(x.j order by x.seen desc nulls last), '[]') from (
    select st.last_seen seen, jsonb_build_object('id', s.user_id, 'name', s.data -> 'player' -> 'name', 'level', public.lb_num(s.data -> 'player' -> 'level'),
             'online', public.soc_online(s.user_id), 'lastSeen', st.last_seen, 'guest', u.is_anonymous, 'gm', public.is_gm(s.user_id),
             'ban', public.mod_active(s.user_id, 'ban'), 'mute', public.mod_active(s.user_id, 'mute')) j
      from public.saves s join auth.users u on u.id = s.user_id left join public.player_status st on st.user_id = s.user_id
     where s.data is not null
       and (q = '' or s.data -> 'player' ->> 'name' ilike '%' || replace(replace(q, '%', '\%'), '_', '\_') || '%' or s.user_id::text = q)
     order by st.last_seen desc nulls last limit 30) x));
end $$;

-- GM: everything about one player (full save view, account, status, sanctions, reports against them)
create or replace function public.gm_player(p_target uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); d jsonb; eq jsonb; u auth.users; st public.player_status; sv public.saves;
begin
  if me is null or not public.is_gm(me) then return jsonb_build_object('ok', false, 'reason', 'gm'); end if;
  select * into sv from public.saves where user_id = p_target;
  d := coalesce(sv.data, (select data from public.saves_archive where user_id = p_target order by id desc limit 1));
  if d is null then return jsonb_build_object('ok', false, 'reason', 'nosave'); end if;
  select * into u from auth.users where id = p_target;
  select * into st from public.player_status where user_id = p_target;
  select coalesce(jsonb_agg(e), '[]') into eq from jsonb_array_elements(coalesce(d -> 'inventory', '[]')) e
   where e ->> 'kind' = 'equipment'
     and e ->> 'instanceId' in (select value from jsonb_each_text(coalesce(d -> 'player' -> 'equipment', '{}')));
  return jsonb_build_object('ok', true, 'id', p_target, 'gm', public.is_gm(p_target), 'online', public.soc_online(p_target),
    'name', d -> 'player' -> 'name', 'title', d -> 'player' -> 'title', 'level', d -> 'player' -> 'level', 'gold', d -> 'player' -> 'gold',
    'look', d -> 'player' -> 'look', 'willColor', d -> 'player' -> 'willColor', 'weaponRank', d -> 'player' -> 'weaponRank',
    'sanity', d -> 'player' -> 'sanity', 'statPoints', d -> 'player' -> 'statPoints',
    'maxDimension', d -> 'maxDimension', 'dimReach', d -> 'dimReach', 'maxMapTierReachedDim1', d -> 'maxMapTierReachedDim1',
    'equipment', d -> 'player' -> 'equipment', 'equipped', eq,
    'invCount', jsonb_array_length(coalesce(d -> 'inventory', '[]')), 'storageCount', jsonb_array_length(coalesce(d -> 'storage', '[]')),
    'savedAt', sv.updated_at, 'gv', d -> 'gv',
    'account', jsonb_build_object('guest', u.is_anonymous, 'created', u.created_at, 'lastSignIn', u.last_sign_in_at,
                 'providers', coalesce(u.raw_app_meta_data -> 'providers', '[]')),
    'status', case when st.user_id is null then null else jsonb_build_object('lastSeen', st.last_seen, 'dim', st.dim, 'map', st.map, 'x', st.x, 'y', st.y) end,
    'ban', public.mod_active(p_target, 'ban'), 'mute', public.mod_active(p_target, 'mute'),
    'sanctions', (select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'kind', s.kind, 'until', s.until, 'reason', s.reason, 'at', s.created_at,
                    'by', public.soc_name(s.by), 'revoked', s.revoked_at is not null, 'active', s.revoked_at is null and s.until > now()) order by s.created_at desc), '[]')
                  from (select * from public.sanctions where user_id = p_target order by created_at desc limit 30) s),
    'reports', (select coalesce(jsonb_agg(jsonb_build_object('id', r.id, 'reason', r.reason, 'note', r.note, 'chat', r.chat, 'at', r.created_at,
                    'by', public.soc_name(r.reporter), 'handled', r.handled) order by r.created_at desc), '[]')
                from (select * from public.reports where target = p_target order by created_at desc limit 20) r),
    'reportCount', (select count(*) from public.reports where target = p_target),
    'wiped', sv.data is null,
    'flags', (select coalesce(jsonb_agg(jsonb_build_object('kind', f.kind, 'detail', f.detail, 'rejected', f.rejected, 'at', f.created_at) order by f.created_at desc), '[]')
                from (select * from public.econ_flags where user_id = p_target order by created_at desc limit 30) f),
    'flagCount', (select count(*) from public.econ_flags where user_id = p_target),
    'archives', (select coalesce(jsonb_agg(jsonb_build_object('id', a.id, 'name', a.name, 'level', a.data -> 'player' -> 'level', 'reason', a.reason,
                    'at', a.created_at, 'by', public.gm_name(a.by)) order by a.id desc), '[]')
                   from (select * from public.saves_archive where user_id = p_target order by id desc limit 10) a));
end $$;

-- GM: ban / mute (p_minutes <= 0 or null = permanent), kick (p_minutes > 0 = also banned that long), warn (reason = the message)
create or replace function public.gm_sanction(p_target uuid, p_kind text, p_minutes int, p_reason text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); why text := left(btrim(regexp_replace(coalesce(p_reason, ''), '\s+', ' ', 'g')), 200);
        until_at timestamptz := case when coalesce(p_minutes, 0) > 0 then now() + make_interval(mins => least(p_minutes, 5256000)) else 'infinity' end;
begin
  if me is null or not public.is_gm(me) then return jsonb_build_object('ok', false, 'reason', 'gm'); end if;
  if p_target = me or public.is_gm(p_target) then return jsonb_build_object('ok', false, 'reason', 'target'); end if;
  if not exists (select 1 from public.saves where user_id = p_target) then return jsonb_build_object('ok', false, 'reason', 'nosave'); end if;
  if p_kind not in ('ban', 'mute', 'kick', 'warn') or (p_kind = 'warn' and why = '') then return jsonb_build_object('ok', false, 'reason', 'invalid'); end if;
  if p_kind in ('ban', 'mute') then
    update public.sanctions set revoked_at = now(), revoked_by = me   -- the new one replaces what was running
     where user_id = p_target and kind = p_kind and revoked_at is null and until > now();
    insert into public.sanctions (user_id, kind, until, reason, by) values (p_target, p_kind, until_at, why, me);
  elsif p_kind = 'kick' then
    insert into public.sanctions (user_id, kind, until, reason, by) values (p_target, 'kick', now(), why, me);
    if coalesce(p_minutes, 0) > 0 then
      update public.sanctions set revoked_at = now(), revoked_by = me
       where user_id = p_target and kind = 'ban' and revoked_at is null and until > now() and until < until_at;
      insert into public.sanctions (user_id, kind, until, reason, by) values (p_target, 'ban', until_at, why, me);
    end if;
  else
    insert into public.sanctions (user_id, kind, until, reason, by) values (p_target, 'warn', now(), why, me);
  end if;
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.gm_revoke(p_target uuid, p_kind text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid();
begin
  if me is null or not public.is_gm(me) then return jsonb_build_object('ok', false, 'reason', 'gm'); end if;
  update public.sanctions set revoked_at = now(), revoked_by = me
   where user_id = p_target and kind = p_kind and revoked_at is null and until > now();
  return jsonb_build_object('ok', true);
end $$;

-- GM: reports inbox (unhandled first) / mark handled
create or replace function public.gm_reports(p_all boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid();
begin
  if me is null or not public.is_gm(me) then return jsonb_build_object('ok', false, 'reason', 'gm'); end if;
  return jsonb_build_object('ok', true, 'reports', (select coalesce(jsonb_agg(jsonb_build_object('id', r.id, 'reason', r.reason, 'note', r.note, 'chat', r.chat,
      'at', r.created_at, 'handled', r.handled, 'target', r.target, 'targetName', public.soc_name(r.target), 'by', public.soc_name(r.reporter))
      order by r.handled, r.created_at desc), '[]')
    from (select * from public.reports where p_all or not handled order by handled, created_at desc limit 60) r));
end $$;
create or replace function public.gm_report_handle(p_id bigint, p_handled boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid();
begin
  if me is null or not public.is_gm(me) then return jsonb_build_object('ok', false, 'reason', 'gm'); end if;
  update public.reports set handled = coalesce(p_handled, true) where id = p_id;
  return jsonb_build_object('ok', true);
end $$;

-- GM: sanctions running now + recent history
create or replace function public.gm_sanctions()
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid();
begin
  if me is null or not public.is_gm(me) then return jsonb_build_object('ok', false, 'reason', 'gm'); end if;
  return jsonb_build_object('ok', true,
    'active', (select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'user', s.user_id, 'name', public.soc_name(s.user_id), 'kind', s.kind,
                 'until', s.until, 'reason', s.reason, 'at', s.created_at, 'by', public.soc_name(s.by)) order by s.created_at desc), '[]')
               from public.sanctions s where s.kind in ('ban', 'mute') and s.revoked_at is null and s.until > now()),
    'history', (select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'user', s.user_id, 'name', public.soc_name(s.user_id), 'kind', s.kind,
                 'until', s.until, 'reason', s.reason, 'at', s.created_at, 'by', public.soc_name(s.by), 'revoked', s.revoked_at is not null) order by s.created_at desc), '[]')
               from (select * from public.sanctions order by created_at desc limit 40) s));
end $$;

-- GM: announcement to everyone online (shown once per player, for 15 minutes after posting)
create or replace function public.gm_announce(p_body text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); b text := left(btrim(regexp_replace(coalesce(p_body, ''), '\s+', ' ', 'g')), 200);
begin
  if me is null or not public.is_gm(me) then return jsonb_build_object('ok', false, 'reason', 'gm'); end if;
  if b = '' then return jsonb_build_object('ok', false, 'reason', 'invalid'); end if;
  insert into public.announcements (body, by) values (b, me);
  return jsonb_build_object('ok', true);
end $$;

revoke execute on function public.gm_search(text), public.gm_player(uuid), public.gm_sanction(uuid, text, int, text), public.gm_revoke(uuid, text),
  public.gm_reports(boolean), public.gm_report_handle(bigint, boolean), public.gm_sanctions(), public.gm_announce(text) from public, anon;
grant execute on function public.gm_search(text), public.gm_player(uuid), public.gm_sanction(uuid, text, int, text), public.gm_revoke(uuid, text),
  public.gm_reports(boolean), public.gm_report_handle(bigint, boolean), public.gm_sanctions(), public.gm_announce(text) to authenticated;

-- ============================================================
-- GM: cheat review (🚩 ตรวจโกง) — flagged players, wipe a character into the archive, restore it
-- ============================================================
create or replace function public.gm_name(p uuid) returns text language sql stable security definer set search_path = public as $$
  select coalesce((select data -> 'player' ->> 'name' from public.saves where user_id = p),
                  (select name from public.saves_archive where user_id = p order by id desc limit 1), '?') $$;
revoke execute on function public.gm_name(uuid) from public, anon, authenticated;

create or replace function public.gm_flags()
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid();
begin
  if me is null or not public.is_gm(me) then return jsonb_build_object('ok', false, 'reason', 'gm'); end if;
  return jsonb_build_object('ok', true, 'players', (
    select coalesce(jsonb_agg(j order by last desc), '[]') from (
      select max(f.created_at) last, jsonb_build_object('id', f.user_id, 'name', public.gm_name(f.user_id),
               'level', (select s.data -> 'player' -> 'level' from public.saves s where s.user_id = f.user_id),
               'wiped', coalesce((select s.data is null from public.saves s where s.user_id = f.user_id), true),
               'n', count(*), 'rejected', count(*) filter (where f.rejected), 'last', max(f.created_at),
               'kinds', jsonb_agg(distinct f.kind), 'ban', public.mod_active(f.user_id, 'ban'), 'online', public.soc_online(f.user_id)) j
        from public.econ_flags f
       where f.created_at > now() - interval '30 days'
       group by f.user_id order by max(f.created_at) desc limit 100) x));
end $$;

-- Wipe = the whole save goes to saves_archive (restorable), the account starts over with nothing.
create or replace function public.gm_wipe(p_target uuid, p_reason text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); sv public.saves;
begin
  if me is null or not public.is_gm(me) then return jsonb_build_object('ok', false, 'reason', 'gm'); end if;
  if p_target = me or public.is_gm(p_target) then return jsonb_build_object('ok', false, 'reason', 'target'); end if;
  select * into sv from public.saves where user_id = p_target for update;
  if not found or sv.data is null then return jsonb_build_object('ok', false, 'reason', 'nosave'); end if;
  insert into public.saves_archive (user_id, name, data, reason, by)
    values (p_target, left(sv.data -> 'player' ->> 'name', 20), sv.data, left(btrim(regexp_replace(coalesce(p_reason, ''), '\s+', ' ', 'g')), 200), me);
  update public.saves set data = null, rev = rev + 1, econ = null, progress_at = null, session_id = null where user_id = p_target;
  delete from public.item_registry where user_id = p_target;
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.gm_restore(p_archive bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); a public.saves_archive; sv public.saves;
begin
  if me is null or not public.is_gm(me) then return jsonb_build_object('ok', false, 'reason', 'gm'); end if;
  select * into a from public.saves_archive where id = p_archive;
  if not found or a.data is null or not exists (select 1 from auth.users where id = a.user_id) then return jsonb_build_object('ok', false, 'reason', 'invalid'); end if;
  select * into sv from public.saves where user_id = a.user_id for update;
  if found and sv.data is not null then   -- whatever they have now is kept too
    insert into public.saves_archive (user_id, name, data, reason, by)
      values (a.user_id, left(sv.data -> 'player' ->> 'name', 20), sv.data, 'เก็บไว้ก่อนกู้คืน #' || p_archive, me);
  end if;
  insert into public.saves (user_id, data, rev, session_id, updated_at, progress_at) values (a.user_id, a.data, 1, null, now(), now())
    on conflict (user_id) do update set data = excluded.data, rev = public.saves.rev + 1, session_id = null, econ = null, updated_at = now(), progress_at = now();
  delete from public.item_registry where user_id = a.user_id;
  insert into public.item_registry (user_id, uid, def)
    select a.user_id, x ->> 'instanceId', x ->> 'defId' from public.econ_items_all(a.data) x
     where x ->> 'kind' = 'equipment' and coalesce(x ->> 'instanceId', '') <> ''
    on conflict (user_id, uid) do nothing;
  return jsonb_build_object('ok', true);
end $$;

revoke execute on function public.gm_flags(), public.gm_wipe(uuid, text), public.gm_restore(bigint) from public, anon;
grant execute on function public.gm_flags(), public.gm_wipe(uuid, text), public.gm_restore(bigint) to authenticated;

-- ============================================================
-- MARKET (v41) — ตลาดกลาง: players sell spare gear / cards / mana stones to each other for gold.
-- No direct trades or gifts. Built so real-money trading is slow, visible and costs money:
--   • price must sit inside 0.5×–3× a server "reference price" (market_ref) and use 2 significant digits
--     (no secret code prices like 12,345)
--   • listings are anonymous and only appear after a random 1–10 min "inspection" — a buyer can't wait for a
--     particular seller's listing, and cheap listings get sniped by everyone else
--   • 2% listing fee (kept even if it doesn't sell) + 12% sales tax, both burned
--   • sale gold waits in the market mailbox for 24 h before it can be claimed (time for the GM to look)
--   • Lv5+, account older than 1 day, not a Guest (GM exempt)
--   • flagged for the GM (econ_flags): the same seller→buyer pair twice in 7 days (market_pair), prices ≥ 2× reference
--     (market_high), paying ≥ 1.5× reference within 3 min of the listing appearing (market_snipe — someone was told
--     what to look for), and a young account (under Lv15 or 3 days) paying / being paid ≥ 1.5× reference (market_newbie)
-- Every function that changes a save locks the save row and checks session + rev like save_game does, writes the
-- new save itself (rev + 1) and returns the new bag / box / gold so the game copies them exactly — the next autosave
-- is then compared against a save that already contains the trade (econ_check stays happy).
-- Items that enter a save through the market get a fresh instanceId (eq_m… / eq_r…), so item_registry never sees
-- an id come back to life.
-- ============================================================
create table if not exists public.market_listings (
  id         bigserial primary key,
  seller     uuid not null references auth.users(id) on delete cascade,
  item       jsonb not null,
  def        text not null,                 -- equipment defId, or the stack item id
  cat        text not null,                 -- weapon | armor | headgear | accessory | card | material
  wtype      text,                          -- sword / heavy / bow / orb (weapons) — the defId without _N_tN
  rarity     text,
  tier       int not null default 1,
  refine     int not null default 0,
  qty        int not null default 1,
  price      bigint not null,
  ref        bigint not null,
  fee        bigint not null,
  status     text not null default 'active', -- active | sold | cancelled | expired
  buyer      uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  visible_at timestamptz not null,
  expires_at timestamptz not null,
  closed_at  timestamptz
);
create index if not exists market_active_idx on public.market_listings (visible_at) where status = 'active';
create index if not exists market_seller_idx on public.market_listings (seller, status);
create index if not exists market_sold_idx on public.market_listings (def, closed_at desc) where status = 'sold';
create table if not exists public.market_mail (
  id           bigserial primary key,
  user_id      uuid not null references auth.users(id) on delete cascade,
  kind         text not null,               -- gold | item
  gold         bigint not null default 0,
  item         jsonb,
  note         text,                        -- sold | expired | cancelled
  listing      bigint,
  available_at timestamptz not null default now(),
  created_at   timestamptz not null default now(),
  claimed_at   timestamptz
);
create index if not exists market_mail_user_idx on public.market_mail (user_id) where claimed_at is null;
alter table public.market_listings enable row level security;
alter table public.market_mail enable row level security;
revoke all on public.market_listings, public.market_mail from anon, authenticated;

-- tuning knobs — change here and re-run this function only
create or replace function public.market_cfg() returns jsonb language sql immutable as $$
  select '{"lv":5,"ageDays":1,"fee":0.02,"tax":0.12,"holdH":24,"bandLo":0.5,"bandHi":3,"slots":5,"slotsMax":10,"perDay":30,
           "hours":[12,24,48],"showMin":1,"showMax":10,"maxQty":99,"minPrice":10,
           "kills":{"common":2,"uncommon":5,"rare":12,"epic":30,"legendary":80},
           "stackMult":{"mana_stone":4},"cardMult":8,"never":["kings_oath_secret","collector_medal"],
           "flag":{"pairN":2,"pairDays":7,"high":2,"snipeMin":3,"snipeX":1.5,"youngLv":15,"youngDays":3,"youngX":1.5},
           "cardRar":{"green_slime_card":"common","pink_slime_card":"common","goblin_card":"uncommon","wolf_card":"uncommon",
                      "skeleton_card":"rare","stone_king_card":"legendary"}}'::jsonb $$;

-- 2 significant digits (1,234 → 1,200 · 45,678 → 46,000); under 100 stays as is
create or replace function public.market_nice(p numeric) returns bigint language sql immutable as $$
  select case when p < 100 then round(p)::bigint
              else (round(p / power(10, floor(log(p)) - 1)) * power(10, floor(log(p)) - 1))::bigint end $$;

-- what one listing is worth to the server: kills of that map it would take to earn (gear), or a multiple of the NPC price
create or replace function public.market_ref(it jsonb, q int) returns bigint language plpgsql immutable as $$
declare C jsonb := public.econ_data(); M jsonb := public.market_cfg(); t int; g numeric; base text;
begin
  if it ->> 'kind' = 'equipment' then
    t := least(greatest(coalesce(substring(it ->> 'defId' from '_t([0-9]+)$')::int, 1), 1), 10);
    select avg(v::numeric) into g from (select jsonb_array_elements_text(C -> 'tiers' -> t::text -> 'g') v limit 5) x;
    return public.market_nice(greatest(
      g * coalesce((M -> 'kills' ->> (it ->> 'rarity'))::numeric, 2)
        * (1 + 0.15 * public.econ_n(it -> 'refineLevel'))
        * (0.85 + 0.3 * coalesce(public.econ_n(it -> 'rollQuality'), 50) / 100),
      coalesce((C -> 'eqPrice' ->> (it ->> 'rarity'))::numeric, 15) * 2));
  end if;
  base := it ->> 'id';
  return public.market_nice(greatest(q * coalesce((C -> 'price' ->> base)::numeric, 5)
         * coalesce((M -> 'stackMult' ->> base)::numeric, case when (C -> 'cards') ? base then (M ->> 'cardMult')::numeric else 4 end), 10));
end $$;

-- null = may use the market, else why not
create or replace function public.market_ineligible(p uuid) returns text language sql stable security definer set search_path = public as $$
  select case when public.is_gm(p) then null
              when coalesce((select is_anonymous from auth.users where id = p), true) then 'guest'
              when public.mod_active(p, 'ban') is not null then 'banned'
              when public.lb_num((select data -> 'player' -> 'level' from public.saves where user_id = p)) < (public.market_cfg() ->> 'lv')::int then 'level'
              when (select created_at from auth.users where id = p) > now() - make_interval(days => (public.market_cfg() ->> 'ageDays')::int) then 'new'
              else null end $$;

-- lazy clock: expired listings go back to their seller's mailbox
create or replace function public.market_tick() returns void language sql security definer set search_path = public as $$
  with ex as (update public.market_listings set status = 'expired', closed_at = now()
               where status = 'active' and expires_at <= now() returning id, seller, item)
  insert into public.market_mail (user_id, kind, item, note, listing) select seller, 'item', item, 'expired', id from ex $$;

-- one listing as the game sees it (no seller, no instanceId)
create or replace function public.market_row(l public.market_listings, me uuid) returns jsonb language sql stable as $$
  select jsonb_build_object('id', l.id, 'item', l.item - 'instanceId' - 'equipped', 'qty', l.qty, 'price', l.price, 'ref', l.ref,
                            'cat', l.cat, 'tier', l.tier, 'refine', l.refine, 'exp', l.expires_at, 'at', l.visible_at,
                            'mine', l.seller = me, 'status', l.status, 'show', l.visible_at <= now()) $$;

-- shared checks for the save-changing calls: the locked save row, or an error reason
create or replace function public.market_lock(me uuid, p_session uuid, p_rev bigint) returns jsonb language plpgsql security definer set search_path = public as $$
declare r public.saves;
begin
  if me is null then raise exception 'not signed in'; end if;
  select * into r from public.saves where user_id = me for update;
  if not found or r.session_id is distinct from p_session then return jsonb_build_object('ok', false, 'reason', 'session'); end if;
  if r.rev <> p_rev then return jsonb_build_object('ok', false, 'reason', 'rev'); end if;
  if public.mod_kicked(me) is not null then return jsonb_build_object('ok', false, 'reason', 'kicked'); end if;
  if public.market_ineligible(me) is not null then return jsonb_build_object('ok', false, 'reason', public.market_ineligible(me)); end if;
  if jsonb_typeof(r.data -> 'inventory') is distinct from 'array' or jsonb_typeof(r.data -> 'storage') is distinct from 'array' then
    return jsonb_build_object('ok', false, 'reason', 'format'); end if;
  return jsonb_build_object('ok', true, 'data', r.data);
end $$;

-- a save written by the market: rev + 1, returns what the game copies
create or replace function public.market_write(me uuid, d jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare nr bigint;
begin
  update public.saves set data = d, rev = rev + 1 where user_id = me returning rev into nr;
  return jsonb_build_object('ok', true, 'rev', nr, 'inventory', d -> 'inventory', 'storage', d -> 'storage', 'gold', d -> 'player' -> 'gold');
end $$;

-- put a stack / equipment into bag, then box; null = no room
create or replace function public.market_stash(d jsonb, it jsonb) returns jsonb language plpgsql immutable as $$
declare B jsonb := public.econ_data() -> 'base'; arr text; mx int; i int;
begin
  foreach arr in array array['inventory', 'storage'] loop
    mx := (B ->> case when arr = 'inventory' then 'bag' else 'storage' end)::int;
    if it ->> 'kind' is distinct from 'equipment' then
      select o - 1 into i from jsonb_array_elements(d -> arr) with ordinality x(e, o)
       where coalesce(e ->> 'kind', 'item') = coalesce(it ->> 'kind', 'item') and e ->> 'id' = it ->> 'id' limit 1;
      if i is not null then
        return jsonb_set(d, array[arr, i::text, 'qty'], to_jsonb(public.econ_n(d -> arr -> i -> 'qty') + public.econ_n(it -> 'qty')));
      end if;
    end if;
    if jsonb_array_length(d -> arr) < mx then return jsonb_set(d, array[arr], (d -> arr) || jsonb_build_array(it)); end if;
  end loop;
  return null;
end $$;

-- ---------- sell: take the item out of the bag, pay the fee, list it ----------
create or replace function public.market_list(p_session uuid, p_rev bigint, p_uid text, p_id text, p_qty int, p_price bigint, p_hours int)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid(); M jsonb := public.market_cfg(); C jsonb := public.econ_data();
  chk jsonb; d jsonb; i int; it jsonb; q int := 1; ref bigint; fee bigint; lv int; used int; cat text; base text; lid bigint;
begin
  chk := public.market_lock(me, p_session, p_rev);
  if not (chk ->> 'ok')::boolean then return chk; end if;
  d := chk -> 'data';
  if not (M -> 'hours') @> to_jsonb(p_hours) then return jsonb_build_object('ok', false, 'reason', 'hours'); end if;
  lv := public.lb_num(d -> 'player' -> 'level');
  select count(*) into used from public.market_listings where seller = me and status = 'active';
  if used >= least((M ->> 'slots')::int + lv / 20, (M ->> 'slotsMax')::int) then return jsonb_build_object('ok', false, 'reason', 'slots'); end if;
  if (select count(*) from public.market_listings where seller = me and created_at > now() - interval '1 day') >= (M ->> 'perDay')::int then
    return jsonb_build_object('ok', false, 'reason', 'daily'); end if;

  if coalesce(p_uid, '') <> '' then   -- one equipment piece
    select o - 1, e into i, it from jsonb_array_elements(d -> 'inventory') with ordinality x(e, o)
     where e ->> 'kind' = 'equipment' and e ->> 'instanceId' = p_uid limit 1;
    if i is null then return jsonb_build_object('ok', false, 'reason', 'noitem'); end if;
    if coalesce((it ->> 'equipped')::boolean, false)
       or exists (select 1 from jsonb_each_text(public.econ_obj(d -> 'player' -> 'equipment')) s where s.value = p_uid) then
      return jsonb_build_object('ok', false, 'reason', 'equipped'); end if;
    base := regexp_replace(coalesce(it ->> 'defId', ''), '_t[0-9]+$', '');
    if (C -> 'items') -> base is null or (M -> 'never') ? base then return jsonb_build_object('ok', false, 'reason', 'nosell'); end if;
    cat := case when base ~ '^(sword|heavy|bow|orb)_' then 'weapon' else split_part(base, '_', 1) end;
    if cat not in ('weapon', 'armor', 'headgear', 'accessory') then return jsonb_build_object('ok', false, 'reason', 'nosell'); end if;
    d := jsonb_set(d, '{inventory}', (d -> 'inventory') - i);
    insert into public.item_registry (user_id, uid, def, alive) values (me, p_uid, it ->> 'defId', false)
      on conflict (user_id, uid) do update set alive = false;
  else                                 -- part of a stack (cards, mana stones)
    q := coalesce(p_qty, 0);
    if q < 1 or q > (M ->> 'maxQty')::int then return jsonb_build_object('ok', false, 'reason', 'qty'); end if;
    if (M -> 'never') ? p_id or not ((C -> 'cards') ? p_id or (M -> 'stackMult') ? p_id) then return jsonb_build_object('ok', false, 'reason', 'nosell'); end if;
    select o - 1, e into i, it from jsonb_array_elements(d -> 'inventory') with ordinality x(e, o)
     where e ->> 'id' = p_id and coalesce(e ->> 'kind', 'item') <> 'equipment' limit 1;
    if i is null or public.econ_n(it -> 'qty') < q then return jsonb_build_object('ok', false, 'reason', 'noitem'); end if;
    if public.econ_n(it -> 'qty') = q then d := jsonb_set(d, '{inventory}', (d -> 'inventory') - i);
    else d := jsonb_set(d, array['inventory', i::text, 'qty'], to_jsonb(public.econ_n(it -> 'qty') - q)); end if;
    it := jsonb_set(it, '{qty}', to_jsonb(q));
    cat := case when (C -> 'cards') ? p_id then 'card' else 'material' end;
    base := p_id;
  end if;

  ref := public.market_ref(it, q);
  if p_price is null or p_price <> public.market_nice(p_price) or p_price < (M ->> 'minPrice')::int
     or p_price < ceil(ref * (M ->> 'bandLo')::numeric) or p_price > floor(ref * (M ->> 'bandHi')::numeric) then
    return jsonb_build_object('ok', false, 'reason', 'price', 'ref', ref); end if;
  fee := greatest(ceil(p_price * (M ->> 'fee')::numeric), 1);
  if public.econ_n(d -> 'player' -> 'gold') < fee then return jsonb_build_object('ok', false, 'reason', 'gold'); end if;
  d := jsonb_set(d, '{player,gold}', to_jsonb(public.econ_n(d -> 'player' -> 'gold') - fee));

  insert into public.market_listings (seller, item, def, cat, wtype, rarity, tier, refine, qty, price, ref, fee, visible_at, expires_at)
  values (me, it, coalesce(it ->> 'defId', p_id), cat, case when cat = 'weapon' then split_part(base, '_', 1) end,
          coalesce(it ->> 'rarity', M -> 'cardRar' ->> p_id, 'common'),
          coalesce(substring(it ->> 'defId' from '_t([0-9]+)$')::int, 1), public.econ_n(it -> 'refineLevel')::int, q, p_price, ref, fee,
          now() + make_interval(mins => (M ->> 'showMin')::int + floor(random() * ((M ->> 'showMax')::int - (M ->> 'showMin')::int + 1))::int),
          now() + make_interval(hours => p_hours))
  returning id into lid;
  if p_price >= ref * (M -> 'flag' ->> 'high')::numeric then perform public.econ_flag(me, 'market_high', jsonb_build_object('kind', 'market_high', 'listing', lid, 'price', p_price, 'ref', ref), false); end if;
  return public.market_write(me, d) || jsonb_build_object('listing', lid, 'fee', fee);
end $$;

-- ---------- take a listing back (any time) → mailbox ----------
create or replace function public.market_cancel(p_id bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); l public.market_listings;
begin
  if me is null then raise exception 'not signed in'; end if;
  select * into l from public.market_listings where id = p_id and seller = me for update;
  if not found or l.status <> 'active' then return jsonb_build_object('ok', false, 'reason', 'gone'); end if;
  update public.market_listings set status = 'cancelled', closed_at = now() where id = p_id;
  insert into public.market_mail (user_id, kind, item, note, listing) values (me, 'item', l.item, 'cancelled', l.id);
  return jsonb_build_object('ok', true);
end $$;

-- ---------- buy: gold out, item straight into the bag (or box), seller's gold into their mailbox ----------
create or replace function public.market_buy(p_session uuid, p_rev bigint, p_id bigint, p_price bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid(); M jsonb := public.market_cfg(); chk jsonb; d jsonb; l public.market_listings; it jsonb; nd jsonb; pairs int; tax bigint;
begin
  chk := public.market_lock(me, p_session, p_rev);
  if not (chk ->> 'ok')::boolean then return chk; end if;
  d := chk -> 'data';
  select * into l from public.market_listings where id = p_id for update;
  if not found or l.status <> 'active' or l.expires_at <= now() or l.visible_at > now() then return jsonb_build_object('ok', false, 'reason', 'gone'); end if;
  if l.seller = me then return jsonb_build_object('ok', false, 'reason', 'own'); end if;
  if l.price is distinct from p_price then return jsonb_build_object('ok', false, 'reason', 'gone'); end if;
  if public.econ_n(d -> 'player' -> 'gold') < l.price then return jsonb_build_object('ok', false, 'reason', 'gold'); end if;
  it := l.item - 'equipped';
  if it ->> 'kind' = 'equipment' then
    it := it || jsonb_build_object('instanceId', 'eq_m' || l.id, 'equipped', false);
  end if;
  nd := public.market_stash(d, it);
  if nd is null then return jsonb_build_object('ok', false, 'reason', 'full'); end if;
  nd := jsonb_set(nd, '{player,gold}', to_jsonb(public.econ_n(d -> 'player' -> 'gold') - l.price));
  if it ->> 'kind' = 'equipment' then
    insert into public.item_registry (user_id, uid, def) values (me, it ->> 'instanceId', it ->> 'defId') on conflict (user_id, uid) do update set alive = true;
  end if;
  update public.market_listings set status = 'sold', buyer = me, closed_at = now() where id = l.id;
  tax := ceil(l.price * (M ->> 'tax')::numeric);
  insert into public.market_mail (user_id, kind, gold, note, listing, available_at)
  values (l.seller, 'gold', l.price - tax, 'sold', l.id, now() + make_interval(hours => (M ->> 'holdH')::int));
  -- GM flags (thresholds in market_cfg().flag)
  select count(*) into pairs from public.market_listings where seller = l.seller and buyer = me and status = 'sold'
     and closed_at > now() - make_interval(days => (M -> 'flag' ->> 'pairDays')::int);
  if pairs >= (M -> 'flag' ->> 'pairN')::int then
    perform public.econ_flag(me, 'market_pair', jsonb_build_object('kind', 'market_pair', 'seller', l.seller, 'buyer', me, 'n', pairs, 'listing', l.id), false);
    perform public.econ_flag(l.seller, 'market_pair', jsonb_build_object('kind', 'market_pair', 'seller', l.seller, 'buyer', me, 'n', pairs, 'listing', l.id), false);
  end if;
  if l.price >= l.ref * (M -> 'flag' ->> 'high')::numeric then
    perform public.econ_flag(me, 'market_high', jsonb_build_object('kind', 'market_high', 'seller', l.seller, 'listing', l.id, 'price', l.price, 'ref', l.ref), false);
  end if;
  if l.price >= l.ref * (M -> 'flag' ->> 'snipeX')::numeric and now() - l.visible_at < make_interval(mins => (M -> 'flag' ->> 'snipeMin')::int) then
    perform public.econ_flag(me, 'market_snipe', jsonb_build_object('kind', 'market_snipe', 'seller', l.seller, 'buyer', me, 'listing', l.id, 'price', l.price, 'ref', l.ref,
                                                                    'secs', round(extract(epoch from now() - l.visible_at))), false);
  end if;
  if l.price >= l.ref * (M -> 'flag' ->> 'youngX')::numeric then
    perform public.econ_flag(y.id, 'market_newbie', jsonb_build_object('kind', 'market_newbie', 'seller', l.seller, 'buyer', me, 'listing', l.id, 'price', l.price, 'ref', l.ref), false)
       from auth.users y left join public.saves s on s.user_id = y.id
      where y.id in (me, l.seller) and not public.is_gm(y.id)
        and (y.created_at > now() - make_interval(days => (M -> 'flag' ->> 'youngDays')::int)
             or public.lb_num(s.data -> 'player' -> 'level') < (M -> 'flag' ->> 'youngLv')::int);
  end if;
  return public.market_write(me, nd) || jsonb_build_object('item', it);
end $$;

-- ---------- mailbox → save (all that are ready and fit) ----------
create or replace function public.market_claim(p_session uuid, p_rev bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); chk jsonb; d jsonb; nd jsonb; m record; it jsonb; got int := 0; gold bigint := 0; left_ int := 0;
begin
  chk := public.market_lock(me, p_session, p_rev);
  if not (chk ->> 'ok')::boolean and chk ->> 'reason' not in ('level', 'new') then return chk; end if;  -- what's already yours can always come home
  if not (chk ->> 'ok')::boolean then
    select jsonb_build_object('ok', true, 'data', data) into chk from public.saves where user_id = me;
  end if;
  d := chk -> 'data';
  for m in select * from public.market_mail where user_id = me and claimed_at is null and available_at <= now() order by id for update loop
    if m.kind = 'gold' then
      d := jsonb_set(d, '{player,gold}', to_jsonb(public.econ_n(d -> 'player' -> 'gold') + m.gold));
      gold := gold + m.gold;
    else
      it := m.item - 'equipped';
      if it ->> 'kind' = 'equipment' then it := it || jsonb_build_object('instanceId', 'eq_r' || m.id, 'equipped', false); end if;
      nd := public.market_stash(d, it);
      if nd is null then left_ := left_ + 1; continue; end if;
      d := nd;
      if it ->> 'kind' = 'equipment' then
        insert into public.item_registry (user_id, uid, def) values (me, it ->> 'instanceId', it ->> 'defId') on conflict (user_id, uid) do update set alive = true;
      end if;
    end if;
    update public.market_mail set claimed_at = now() where id = m.id;
    got := got + 1;
  end loop;
  if got = 0 then return jsonb_build_object('ok', false, 'reason', case when left_ > 0 then 'full' else 'empty' end); end if;
  return public.market_write(me, d) || jsonb_build_object('got', got, 'goldGot', gold, 'left', left_);
end $$;

-- ---------- browse ----------
-- p_f: {cat, wtype, rar:[..], tmin, tmax, rmin, pmin, pmax, defs:[..], stats:[..], sort: cheap|dear|new|ending|deal|ref}
create or replace function public.market_search(p_f jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); f jsonb := coalesce(p_f, '{}'::jsonb); res jsonb;
begin
  if me is null then raise exception 'not signed in'; end if;
  perform public.market_tick();
  select coalesce(jsonb_agg(public.market_row(x.l, me) order by x.rn), '[]'::jsonb) into res from (
    select l, row_number() over (order by
        case f ->> 'sort' when 'dear' then -l.price when 'cheap' then l.price when 'ref' then -l.ref end nulls last,
        case f ->> 'sort' when 'deal' then l.price::numeric / greatest(l.ref, 1) end nulls last,
        case f ->> 'sort' when 'ending' then l.expires_at end nulls last,
        l.visible_at desc) rn
      from public.market_listings l
     where l.status = 'active' and l.expires_at > now() and (l.visible_at <= now() or l.seller = me)
       and (f ->> 'cat' is null or l.cat = f ->> 'cat')
       and (f ->> 'wtype' is null or l.wtype = f ->> 'wtype')
       and (jsonb_typeof(f -> 'rar') is distinct from 'array' or jsonb_array_length(f -> 'rar') = 0 or (f -> 'rar') ? coalesce(l.rarity, ''))
       and (f ->> 'tmin' is null or l.tier >= (f ->> 'tmin')::int)
       and (f ->> 'tmax' is null or l.tier <= (f ->> 'tmax')::int)
       and (f ->> 'rmin' is null or l.refine >= (f ->> 'rmin')::int)
       and (f ->> 'pmin' is null or l.price >= (f ->> 'pmin')::bigint)
       and (f ->> 'pmax' is null or l.price <= (f ->> 'pmax')::bigint)
       and (jsonb_typeof(f -> 'defs') is distinct from 'array' or (f -> 'defs') ? l.def or (f -> 'defs') ? regexp_replace(l.def, '_t[0-9]+$', ''))
       and (jsonb_typeof(f -> 'stats') is distinct from 'array'
            or not exists (select 1 from jsonb_array_elements_text(f -> 'stats') s where public.econ_n(l.item -> 'rolledStats' -> s) <= 0))
     order by rn limit 300) x;
  return jsonb_build_object('ok', true, 'rows', res, 'now', now());
end $$;

-- my side of the market: who may trade, my listings (active + last 7 days), mailbox, knobs
create or replace function public.market_home()
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); M jsonb := public.market_cfg(); lv int;
begin
  if me is null then raise exception 'not signed in'; end if;
  perform public.market_tick();
  lv := public.lb_num((select data -> 'player' -> 'level' from public.saves where user_id = me));
  return jsonb_build_object('ok', true, 'now', now(), 'cfg', M, 'why', public.market_ineligible(me),
    'tg', (select jsonb_object_agg(t.key, (select avg(v::numeric) from (select jsonb_array_elements_text(t.value -> 'g') v limit 5) x))
             from jsonb_each(public.econ_data() -> 'tiers') t),
    'price', public.econ_data() -> 'price', 'eqPrice', public.econ_data() -> 'eqPrice', 'cards', public.econ_data() -> 'cards',
    'slots', least((M ->> 'slots')::int + lv / 20, (M ->> 'slotsMax')::int),
    'mine', (select coalesce(jsonb_agg(public.market_row(l, me) || jsonb_build_object('fee', l.fee, 'closed', l.closed_at) order by l.status <> 'active', l.created_at desc), '[]'::jsonb)
               from (select * from public.market_listings where seller = me and (status = 'active' or closed_at > now() - interval '7 days')
                      order by created_at desc limit 60) l),
    'mail', (select coalesce(jsonb_agg(jsonb_build_object('id', id, 'kind', kind, 'gold', gold, 'item', item, 'note', note, 'at', available_at, 'ready', available_at <= now()) order by id), '[]'::jsonb)
               from public.market_mail where user_id = me and claimed_at is null));
end $$;

-- recent sale prices of one item kind (all tiers of the same base when p_def has no _tN)
create or replace function public.market_history(p_def text)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('price', price, 'qty', qty, 'tier', tier, 'refine', refine, 'at', closed_at) order by closed_at desc), '[]'::jsonb)
    from (select * from public.market_listings where status = 'sold' and (def = p_def or regexp_replace(def, '_t[0-9]+$', '') = p_def)
           order by closed_at desc limit 12) x $$;

revoke execute on function public.market_cfg(), public.market_nice(numeric), public.market_ref(jsonb, int), public.market_ineligible(uuid),
  public.market_tick(), public.market_row(public.market_listings, uuid), public.market_lock(uuid, uuid, bigint), public.market_write(uuid, jsonb),
  public.market_stash(jsonb, jsonb) from public, anon, authenticated;
revoke execute on function public.market_list(uuid, bigint, text, text, int, bigint, int), public.market_cancel(bigint),
  public.market_buy(uuid, bigint, bigint, bigint), public.market_claim(uuid, bigint), public.market_search(jsonb),
  public.market_home(), public.market_history(text) from public, anon;
grant execute on function public.market_list(uuid, bigint, text, text, int, bigint, int), public.market_cancel(bigint),
  public.market_buy(uuid, bigint, bigint, bigint), public.market_claim(uuid, bigint), public.market_search(jsonb),
  public.market_home(), public.market_history(text) to authenticated;