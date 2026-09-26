-- ============================================================
-- Menalars v66 + v67 — 🎣 ตกปลา + 👥 ปาร์ตี้  (ต้องรัน 1 ครั้ง · รันซ้ำได้ ไม่ลบข้อมูลเดิม)
-- Supabase → SQL Editor → New query → วางทั้งไฟล์ → Run
-- (เท่ากับส่วนที่เปลี่ยนใน dev/sql/setup.sql — ถ้ารัน setup.sql ทั้งไฟล์แล้วไม่ต้องรันไฟล์นี้)
-- ============================================================

-- 1) ตารางค่าจากเกม (ปลา 18 ชนิด + ราคา + ฉายาตกปลา)
create or replace function public.econ_data() returns jsonb language sql immutable as $$ select '{"tiers":{"1":{"g":[9,16,28,46,70,263],"x":[21,35,56,84,123,385]},"2":{"g":[86,102,116,131,147,431],"x":[149,173,200,224,250,735]},"3":{"g":[163,177,193,208,224,648],"x":[275,301,326,352,376,1089]},"4":{"g":[238,254,270,285,299,863],"x":[403,427,453,478,504,1446]},"5":{"g":[315,331,347,361,376,1073],"x":[529,555,579,606,630,1799]},"6":{"g":[392,408,422,438,453,1288],"x":[656,681,707,732,758,2156]},"7":{"g":[469,483,499,515,530,1505],"x":[782,809,833,859,884,2510]},"8":{"g":[544,560,576,592,606,1720],"x":[910,935,961,985,1012,2867]},"9":{"g":[621,637,653,667,683,1930],"x":[1036,1062,1087,1113,1138,3220]},"10":{"g":[698,714,728,744,760,2146],"x":[1164,1188,1215,1239,1265,3577]}},"dimStep":0.3,"items":{"kings_armor":["epic",0],"collector_medal":["legendary",1],"sword_1":["common",0],"sword_2":["common",0],"sword_3":["uncommon",0],"sword_4":["uncommon",0],"sword_5":["rare",0],"sword_6":["rare",0],"sword_7":["epic",0],"sword_8":["epic",0],"sword_9":["legendary",0],"sword_10":["legendary",0],"heavy_1":["common",0],"heavy_2":["common",0],"heavy_3":["uncommon",0],"heavy_4":["uncommon",0],"heavy_5":["rare",0],"heavy_6":["rare",0],"heavy_7":["epic",0],"heavy_8":["epic",0],"heavy_9":["legendary",0],"heavy_10":["legendary",0],"bow_1":["common",0],"bow_2":["common",0],"bow_3":["uncommon",0],"bow_4":["uncommon",0],"bow_5":["rare",0],"bow_6":["rare",0],"bow_7":["epic",0],"bow_8":["epic",0],"bow_9":["legendary",0],"bow_10":["legendary",0],"orb_1":["common",0],"orb_2":["common",0],"orb_3":["uncommon",0],"orb_4":["uncommon",0],"orb_5":["rare",0],"orb_6":["rare",0],"orb_7":["epic",0],"orb_8":["epic",0],"orb_9":["legendary",0],"orb_10":["legendary",0],"armor_1":["common",0],"armor_2":["uncommon",0],"armor_3":["rare",0],"armor_4":["epic",0],"armor_5":["legendary",0],"headgear_1":["common",0],"headgear_2":["uncommon",0],"headgear_3":["rare",0],"headgear_4":["epic",0],"headgear_5":["legendary",0],"accessory_1":["common",0],"accessory_2":["uncommon",0],"accessory_3":["rare",0],"accessory_4":["epic",0],"accessory_5":["legendary",0]},"pts":{"common":1.2,"uncommon":1.7,"rare":2.4,"epic":3.4,"legendary":4.4},"eliteMult":2,"price":{"herb":3,"potion":5,"slime_jelly":4,"wolf_fang":6,"stone_fragment":8,"secret_key":20,"junk_scrap":2,"mana_stone":12,"sample_t1":7,"sample_t2":23,"sample_t3":39,"sample_t4":54,"sample_t5":69,"sample_t6":85,"sample_t7":100,"sample_t8":115,"sample_t9":130,"sample_t10":146,"fish_siw":4,"fish_kad":6,"fish_ayu":6,"fish_tu":7,"fish_nil":8,"fish_saba":14,"fish_takhian":12,"fish_salid":12,"fish_duk":15,"fish_chon":30,"fish_koi":34,"fish_fugu":36,"fish_madai":38,"fish_unagi":70,"fish_kaphong":64,"fish_katsuo":66,"fish_buek":160,"fish_maguro":180,"green_slime_card":11,"pink_slime_card":11,"goblin_card":25,"wolf_card":25,"skeleton_card":56,"stone_king_card":280,"kings_oath_secret":280},"eqPrice":{"common":15,"uncommon":35,"rare":80,"epic":180,"legendary":400},"starter":["sword_1","heavy_1","bow_1","orb_1"],"shopOnly":["herb","potion"],"stack":["herb","potion","slime_jelly","wolf_fang","stone_fragment","secret_key","old_letter","junk_scrap","mana_stone","sample_t1","sample_t2","sample_t3","sample_t4","sample_t5","sample_t6","sample_t7","sample_t8","sample_t9","sample_t10","bark_tag","barrier_lantern","inscribed_wrap","fish_siw","fish_kad","fish_ayu","fish_tu","fish_nil","fish_saba","fish_takhian","fish_salid","fish_duk","fish_chon","fish_koi","fish_fugu","fish_madai","fish_unagi","fish_kaphong","fish_katsuo","fish_buek","fish_maguro","green_slime_card","pink_slime_card","goblin_card","wolf_card","skeleton_card","stone_king_card","kings_oath_secret"],"cards":["green_slime_card","pink_slime_card","goblin_card","wolf_card","skeleton_card","stone_king_card","kings_oath_secret"],"rankExp":[0,500,1500,3500,7000,13000,23000,40000,70000,120000],"skill":{"sword":[[1,2],[3,2],[5,2],[7,2],[9,2]],"heavy":[[1,2],[3,2],[5,2],[7,2],[9,2]],"bow":[[1,2],[3,2],[5,2],[7,2],[9,2]],"orb":[[1,2],[3,2],[5,2],[7,2],[9,2]]},"titles":{"first_blood":["kills",100],"reaper":["kills",1000],"death_walker":["kills",5000],"calamity":["kills",20000],"slime_hunter":["slimeKills",100],"one_beat":["perfectHits",300],"flawless_blade":["perfectHits",3000],"rhythm_sage":["perfectHits",15000],"perfect_warrior":["bestPerfectStreak",50],"swaying_shadow":["perfectDodges",50],"formless_wind":["perfectDodges",500],"shadowless":["perfectDodges",2500],"counter_art":["counters",50],"mirror_blade":["counters",500],"keen_eye":["crits",500],"fortune_chosen":["crits",5000],"star_assassin":["crits",25000],"unscathed":["flawless",50],"invisible_armor":["flawless",500],"survivor":["survivor",1],"never_give_up":["deaths",25],"elite_hunter":["eliteKills",10],"star_breaker":["eliteKills",100],"elite_bane":["eliteKills",500],"boss_slayer":["bossKills",10],"throne_hunter":["bossKills",50],"king_of_kings":["bossKills",200],"untouchable":["untouchable",1],"five_realms":["bossTiers",5],"ten_kings":["bossTiers",10],"wanderer":["reach",3],"pathfinder":["reach",6],"worlds_edge":["reach",10],"story_c1":["chapters",1],"story_c2":["chapters",2],"story_c3":["chapters",3],"story_c5":["chapters",5],"story_c7":["chapters",7],"story_c10":["chapters",10],"whisper_listener":["listened",1],"secret_seeker":["secrets",5],"secret_keeper":["secrets",30],"dungeon_diver":["dungeons",1],"labyrinth_lord":["dungeons",10],"underworld_ruler":["dungeons",30],"treasure_hunter":["chests",10],"rising_hero":["level",25],"menalars_hero":["level",50],"peak":["level",100],"barrier_breaker":["maxDim",2],"dimension_walker":["maxDim",3],"void_voyager":["maxDim",5],"novice_collector":["colPct",10],"monster_hunter":["monstersHalf",1],"monster_master":["monstersAll",1],"card_collector":["cards",3],"full_deck":["allCards",1],"half_collector":["colPct",50],"curator":["colPct",75],"full_collector":["colPct",100],"treasure_bearer":["epics",5],"legend_chosen":["legends",1],"legend_vault":["legends",10],"apprentice_smith":["refines",10],"artisan":["bestRefine",5],"forge_master":["bestRefine",10],"new_rich":["goldEarned",10000],"tycoon":["goldEarned",100000],"gold_king":["goldEarned",1000000],"mind_trainee":["meditations",10],"still_water":["meditations",100],"fish_novice":["fish",10],"fish_master":["fish",200],"fish_sage":["fishSpecies",18],"town_friend":["junkQuest",1],"letter_reader":["lettersRead",15],"letter_keeper":["lettersRead",40],"letter_all":["lettersRead",60],"shadow_unmasker":["spyUnmasked",1],"courier":["letters",3],"skill_student":["skills",5],"weapon_scholar":["skills",15],"weapon_master":["bestRank",5],"four_arms":["rankedWeapons",4],"transcender":["bestRank",9]},"quests":{"c1_wake":[40,60,0,1,0],"c1_town":[50,95,0,1,0],"c1_squad":[50,95,0,1,0],"c1_test":[100,190,0,1,0],"c1_wreck":[100,190,0,1,0],"c1_bark":[100,190,0,1,0],"c1_mind":[100,190,0,1,0],"c1_counter":[100,190,0,1,0],"c1_boss":[270,510,1,1,1],"c2_child":[350,600,0,2,0],"c2_lantern":[350,600,0,2,0],"c2_incense":[350,600,0,2,0],"c2_preacher":[350,600,0,2,0],"c2_lost":[350,600,0,2,0],"c2_boss":[930,1600,1,2,1],"c3_tablets":[580,980,0,3,0],"c3_wrap":[580,980,0,3,0],"c3_vent":[580,980,0,3,0],"c3_heat":[580,980,0,3,0],"c3_boss":[1540,2600,1,3,1],"c4_hut":[810,1365,0,4,0],"c4_frozen":[810,1365,0,4,0],"c4_ice":[810,1365,0,4,0],"c4_still":[810,1365,0,4,0],"c4_boss":[2150,3600,1,4,1],"c5_brother":[1040,1750,0,5,0],"c5_ore":[1040,1750,0,5,0],"c5_camp":[1040,1750,0,5,0],"c5_dark":[1040,1750,0,5,0],"c5_boss":[2760,4600,1,5,1],"c6_cure":[1270,2135,0,6,0],"c6_drowned":[1270,2135,0,6,0],"c6_ferry":[1270,2135,0,6,0],"c6_calm":[1270,2135,0,6,0],"c6_boss":[3370,5600,1,6,1],"c7_mirror":[1500,2520,0,7,0],"c7_cage":[1500,2520,0,7,0],"c7_home":[1500,2520,0,7,0],"c7_sight":[1500,2520,0,7,0],"c7_boss":[3980,6600,1,7,1],"c8_mural":[1730,2905,0,8,0],"c8_pilgrims":[1730,2905,0,8,0],"c8_doubt":[1730,2905,0,8,0],"c8_sun":[1730,2905,0,8,0],"c8_boss":[4590,7600,1,8,1],"c9_edge":[1960,3290,0,9,0],"c9_echo":[1960,3290,0,9,0],"c9_warriors":[1960,3290,0,9,0],"c9_untouched":[1960,3290,0,9,0],"c9_boss":[5200,8600,1,9,1],"c10_saints":[2190,3675,0,10,0],"c10_mind":[2190,3675,0,10,0],"c10_throne":[2190,3675,0,10,0],"c10_boss":[5810,9600,1,10,1]},"letters":["L01","L02","L03","L04","L05","L06","L07","L08","L09","L10","L11","L12","L13","L14","L15","L16","L17","L18","L19","L20","L21","L22","L23","L24","L25","L26","L27","L28","L29","L30","L31","L32","L33","L34","L35","L36","L37","L38","L39","L40","L41","L42","L43","L44","L45","L46","L47","L48","L49","L50","L51","L52","L53","L54","L55","L56","L57","L58","L59","L60"],"totals":{"mon":6,"card":7,"eq":561},"base":{"atk":6,"hp":50,"atkLv":2,"hpLv":10,"spLv":3,"spDim":3,"masteryMax":100,"refineMax":10,"sanityMax":100,"tierMax":10,"bag":48,"storage":100}}'::jsonb $$;

-- 2) 👥 ปาร์ตี้: ตาราง + ฟังก์ชัน
-- ---------- v67 👥 parties (max 4) — no "create party" button: accepting an invite forms one, and a party
-- that drops to a single member dissolves. The bonus: +10% kill EXP per party mate on the same map (the client
-- counts mates it can see on its map channel); econ_check allows up to that many mates (party_bonus).
create table if not exists public.parties (
  id         bigserial primary key,
  leader     uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
create table if not exists public.party_members (
  user_id   uuid primary key references auth.users(id) on delete cascade,
  party_id  bigint not null references public.parties(id) on delete cascade,
  joined_at timestamptz not null default now()
);
create table if not exists public.party_invites (        -- valid 2 minutes
  from_id    uuid not null references auth.users(id) on delete cascade,
  to_id      uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (from_id, to_id)
);
create table if not exists public.party_bonus (          -- how many mates' EXP bonus a save may carry (kept 10 min after changes)
  user_id uuid primary key references auth.users(id) on delete cascade,
  mates   int not null default 0,
  until   timestamptz not null default now()
);
create index if not exists party_members_party_idx on public.party_members (party_id);
create index if not exists party_invites_to_idx on public.party_invites (to_id);
alter table public.parties enable row level security;
alter table public.party_members enable row level security;
alter table public.party_invites enable row level security;
alter table public.party_bonus enable row level security;
revoke all on public.parties, public.party_members, public.party_invites, public.party_bonus from anon, authenticated;

-- helpers (not callable from the game)
create or replace function public.party_touch(pid bigint) returns void language plpgsql security definer set search_path = public as $$
declare n int;
begin
  select count(*) into n from public.party_members where party_id = pid;
  if n <= 1 then delete from public.parties where id = pid; return; end if;   -- one left = no party (cascade drops the member row)
  insert into public.party_bonus (user_id, mates, until)
    select user_id, least(n - 1, 3), now() + interval '10 minutes' from public.party_members where party_id = pid
    on conflict (user_id) do update set mates = greatest(excluded.mates, case when party_bonus.until > now() then party_bonus.mates else 0 end),
                                         until = excluded.until;
end $$;
create or replace function public.party_of(u uuid) returns bigint language sql stable security definer set search_path = public as $$
  select party_id from public.party_members where user_id = u $$;
create or replace function public.party_mates_allowed(u uuid) returns int language sql stable security definer set search_path = public as $$
  select least(3, greatest(
    coalesce((select count(*) - 1 from public.party_members where party_id = public.party_of(u)), 0),
    coalesce((select mates from public.party_bonus where user_id = u and until > now()), 0)))::int $$;
create or replace function public.party_info(me uuid) returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'party', (select jsonb_build_object('id', p.id, 'leader', p.leader, 'members',
               (select coalesce(jsonb_agg(jsonb_build_object('id', m.user_id, 'name', public.soc_name(m.user_id),
                   'level', (select (data -> 'player' ->> 'level')::int from public.saves where user_id = m.user_id),
                   'online', public.soc_online(m.user_id), 'map', s.map, 'dim', s.dim) order by m.user_id = p.leader desc, m.joined_at), '[]')
                  from public.party_members m left join public.player_status s on s.user_id = m.user_id where m.party_id = p.id))
              from public.parties p where p.id = public.party_of(me)),
    'inv', (select coalesce(jsonb_agg(jsonb_build_object('from', i.from_id, 'name', public.soc_name(i.from_id),
               'level', (select (data -> 'player' ->> 'level')::int from public.saves where user_id = i.from_id)) order by i.created_at), '[]')
             from public.party_invites i where i.to_id = me and i.created_at > now() - interval '2 minutes')) $$;
revoke execute on function public.party_touch(bigint), public.party_of(uuid), public.party_mates_allowed(uuid), public.party_info(uuid) from public, anon, authenticated;

-- invite: only the leader (or anyone not yet in a party — accepting then makes them the leader)
create or replace function public.party_invite(p_to uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); pid bigint;
begin
  if me is null then raise exception 'not signed in'; end if;
  if p_to = me or not exists (select 1 from public.saves where user_id = p_to) then return jsonb_build_object('ok', false, 'reason', 'invalid'); end if;
  if public.soc_blocked(me, p_to) then return jsonb_build_object('ok', false, 'reason', 'blocked'); end if;
  if not public.soc_online(p_to) then return jsonb_build_object('ok', false, 'reason', 'offline'); end if;
  pid := public.party_of(me);
  if pid is not null and (select leader from public.parties where id = pid) <> me then return jsonb_build_object('ok', false, 'reason', 'notleader'); end if;
  if pid is not null and (select count(*) from public.party_members where party_id = pid) >= 4 then return jsonb_build_object('ok', false, 'reason', 'pfull'); end if;
  if public.party_of(p_to) is not null then return jsonb_build_object('ok', false, 'reason', 'inparty'); end if;
  if (select count(*) from public.party_invites where from_id = me and created_at > now() - interval '10 seconds') >= 3 then return jsonb_build_object('ok', false, 'reason', 'fast'); end if;
  insert into public.party_invites (from_id, to_id) values (me, p_to) on conflict (from_id, to_id) do update set created_at = now();
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.party_answer(p_from uuid, p_accept boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); pid bigint;
begin
  if me is null then raise exception 'not signed in'; end if;
  if not exists (select 1 from public.party_invites where from_id = p_from and to_id = me and created_at > now() - interval '2 minutes') then
    delete from public.party_invites where from_id = p_from and to_id = me;
    return jsonb_build_object('ok', false, 'reason', 'expired');
  end if;
  delete from public.party_invites where from_id = p_from and to_id = me;
  if not p_accept then return jsonb_build_object('ok', true, 'state', 'declined'); end if;
  if public.party_of(me) is not null then return jsonb_build_object('ok', false, 'reason', 'inparty'); end if;
  pid := public.party_of(p_from);
  if pid is null then
    insert into public.parties (leader) values (p_from) returning id into pid;
    insert into public.party_members (user_id, party_id, joined_at) values (p_from, pid, now() - interval '1 second'); -- the leader joined first
  end if;
  if (select count(*) from public.party_members where party_id = pid) >= 4 then return jsonb_build_object('ok', false, 'reason', 'pfull'); end if;
  insert into public.party_members (user_id, party_id) values (me, pid);
  delete from public.party_invites where to_id = me;          -- other pending invites no longer apply
  perform public.party_touch(pid);
  return jsonb_build_object('ok', true, 'state', 'joined');
end $$;

create or replace function public.party_leave()
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); pid bigint;
begin
  if me is null then raise exception 'not signed in'; end if;
  pid := public.party_of(me);
  if pid is null then return jsonb_build_object('ok', true); end if;
  delete from public.party_members where user_id = me;
  update public.parties set leader = (select user_id from public.party_members where party_id = pid order by joined_at limit 1)
   where id = pid and leader = me and exists (select 1 from public.party_members where party_id = pid);
  perform public.party_touch(pid);
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.party_kick(p_who uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); pid bigint;
begin
  if me is null then raise exception 'not signed in'; end if;
  pid := public.party_of(me);
  if pid is null or p_who = me or public.party_of(p_who) is distinct from pid then return jsonb_build_object('ok', false, 'reason', 'invalid'); end if;
  if (select leader from public.parties where id = pid) <> me then return jsonb_build_object('ok', false, 'reason', 'notleader'); end if;
  delete from public.party_members where user_id = p_who;
  perform public.party_touch(pid);
  return jsonb_build_object('ok', true);
end $$;
grant execute on function public.party_invite(uuid), public.party_answer(uuid, boolean), public.party_leave(), public.party_kick(uuid) to authenticated;


-- 3) ส่งข้อมูลปาร์ตี้ไปกับ net_poll (เพิ่มคีย์ 'pt' — เกมเวอร์ชันเก่าไม่สนใจ)
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
    'pt', public.party_info(me),   -- v67 👥 { party: {id, leader, members[]} | null, inv: [{from, name, level}] }
    'pv', (select count(*) from public.polls p where p.status = 'open' and p.closes_at > now()
             and not exists (select 1 from public.poll_votes v where v.poll_id = p.id and v.user_id = me))); -- open votes I haven't cast (town board "!")
end $$;

-- 4) ตัวเลขฉายา (+ ปลา)
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

-- 5) ตัวตรวจกันโกง: ปลาเข้ากระเป๋าได้ตามเวลาที่ตก · EXP โบนัสปาร์ตี้สูงสุด +30%
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
  pmates int := 0;       -- v67 👥 party mates whose +10% kill EXP this save may carry
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
  pmates := public.party_mates_allowed(me);
  lim_x := ceil((lim_x * dm + delite * (C -> 'tiers' -> tr::text -> 'x' ->> 4)::numeric * dm * ((C ->> 'eliteMult')::numeric - 1) + dk * dm) * (1 + 0.1 * pmates)) + 80 + qx;
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

-- 6) บอกเกมว่าเซิร์ฟเวอร์พร้อมแล้ว (เกมจะเปิดปุ่มตกปลา/ปาร์ตี้เอง)
-- v66: systems the client may switch on (it asks once at login; missing function = all off)
create or replace function public.game_features() returns jsonb language sql immutable as $$ select '{"fish":1,"party":1}'::jsonb $$;
grant execute on function public.game_features() to anon, authenticated;

-- 7) ตัวตรวจถูกสร้างใหม่ → ปิดไม่ให้ผู้เล่นเรียกตรงๆ (เหมือนเดิม)
revoke execute on function public.econ_data(), public.econ_title_stats(jsonb), public.econ_check(uuid, jsonb, jsonb, jsonb, numeric) from public, anon, authenticated;
