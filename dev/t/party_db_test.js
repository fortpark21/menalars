// v67 👥 party server rules on the local Postgres (see story_db_test.js). Run: cd /tmp/mw/t && DB=b2 node party_db_test.js
const { execFileSync } = require("child_process");
const DB = process.env.DB || "b2";
const psql = sql => execFileSync("psql", ["-h", "/tmp", "-p", "5433", "-U", "postgres", "-d", DB, "-At", "-q", "-v", "ON_ERROR_STOP=1"], { input: sql, encoding: "utf8" }).trim();
const U = n => "00000000-0000-0000-0000-0000000067" + String(n).padStart(2, "0");
const as = (n, body) => { const out = psql(`begin; set local role authenticated; select set_config('request.jwt.claim.sub', '${U(n)}', true) \\g /dev/null\n${body};\ncommit;`).split("\n").pop(); try{ return JSON.parse(out); }catch(e){ return out; } };
const fails = [], check = (label, got, want) => { const ok = JSON.stringify(got) === JSON.stringify(want); if(!ok) fails.push(`${label}: got ${JSON.stringify(got)} want ${JSON.stringify(want)}`); };
for(let i = 1; i <= 5; i++){
  psql(`delete from auth.users where id = '${U(i)}'; insert into auth.users (id) values ('${U(i)}');
        insert into public.saves (user_id, data) values ('${U(i)}', '{"player":{"name":"P${i}","level":${10 * i}}}');`);
  as(i, "select public.net_poll(1, 2, 100, 100)");
}
const info = n => as(n, "select public.net_poll(1, 2, 100, 100) -> 'pt'");
const members = n => { const p = info(n).party; return p ? p.members.map(m => m.name) : null; };
check("invite 1→2", as(1, `select public.party_invite('${U(2)}')`), { ok: true });
check("2 sees the invite", info(2).inv.map(i => i.name), ["P1"]);
check("no party before accepting", info(1).party, null);
check("2 accepts", as(2, `select public.party_answer('${U(1)}', true)`).ok, true);
check("party of 2", members(1), ["P1", "P2"]);
check("leader is 1", info(2).party.leader, U(1));
check("2 (not leader) can't invite", as(2, `select public.party_invite('${U(3)}')`).reason, "notleader");
as(1, `select public.party_invite('${U(3)}')`); as(3, `select public.party_answer('${U(1)}', true)`);
as(1, `select public.party_invite('${U(4)}')`); as(4, `select public.party_answer('${U(1)}', true)`);
check("party of 4", members(4), ["P1", "P2", "P3", "P4"]);
check("5th: invite refused (full)", as(1, `select public.party_invite('${U(5)}')`).reason, "pfull");
check("EXP allowance 3 mates", psql(`select public.party_mates_allowed('${U(2)}')`), "3");
check("declined invite", (as(5, `select public.party_invite('${U(1)}')`) || {}).reason, "inparty");
check("kick by non-leader refused", as(3, `select public.party_kick('${U(4)}')`).reason, "notleader");
check("leader kicks 4", as(1, `select public.party_kick('${U(4)}')`).ok, true);
check("4 is out", info(4).party, null);
check("4 still gets the bonus for a while", psql(`select public.party_mates_allowed('${U(4)}')`), "3");
check("leader leaves → oldest member leads", (as(1, "select public.party_leave()"), info(2).party.leader), U(2));
check("party of 2 left", members(2), ["P2", "P3"]);
check("last mate leaves → dissolved", (as(3, "select public.party_leave()"), info(2).party), null);
check("expired invite", (psql(`insert into public.party_invites (from_id, to_id, created_at) values ('${U(5)}', '${U(2)}', now() - interval '5 minutes')`), as(2, `select public.party_answer('${U(5)}', true)`).reason), "expired");
psql(`update public.party_bonus set until = now() - interval '1 second'`);
check("bonus gone once expired and partyless", psql(`select public.party_mates_allowed('${U(4)}')`), "0");
console.log("fails", JSON.stringify(fails, null, 1));
