-- Menalars v45 — NPC buy-back (ซื้อคืนของที่ขายให้พ่อค้า) · run once in Supabase → SQL Editor → Run (safe to re-run)

-- Items in the buy-back list stay 'owned' for duplicate checks; buying one back must cost its sale price again.

create or replace function public.econ_items_all(d jsonb) returns setof jsonb language sql immutable as $$
  select e from public.econ_items(d) e
  union all
  select e from jsonb_array_elements(public.econ_arr(d -> 'buyback')) e $$;

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
begin
  np := public.econ_obj(d -> 'player');
  if jsonb_typeof(o) is distinct from 'object' or jsonb_typeof(o -> 'player') is distinct from 'object' then o := '{}'::jsonb; end if;
  -- starting over (a new character) = compare with an empty character
  select coalesce(sum(public.econ_n(value)), 0) into hc from jsonb_each(public.econ_obj(d -> 'huntCounts'));
  select coalesce(sum(public.econ_n(value)), 0) into ohc from jsonb_each(public.econ_obj(o -> 'huntCounts'));
  if public.econ_n(np -> 'level') < public.econ_n(o -> 'player' -> 'level') or hc < ohc then o := '{}'::jsonb; ohc := 0; end if;
  op := public.econ_obj(o -> 'player'); st := public.econ_obj(d -> 'stats'); ost := public.econ_obj(o -> 'stats');
  B := C -> 'base';

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
  units := greatest(units - 3 - public.econ_n(st -> 'chestsOpened') + public.econ_n(ost -> 'chestsOpened')
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
