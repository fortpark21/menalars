#!/usr/bin/env python3
"""sync_sql.py — run from the repo root after editing dev/sql/setup.sql or game data (items/titles/quests…):
  1) rebuilds econ_data() from the game itself (dev/t/gen_econ.js on the offline copy /tmp/mw/t/game.html — run
     dev/setup_work.sh first so that copy is current)
  2) writes it between -- ECON_DATA_BEGIN / -- ECON_DATA_END in dev/sql/setup.sql
  3) copies the whole dev/sql/setup.sql into the SUPABASE SETUP SQL block at the end of index.html
"""
import json, subprocess, sys, os
REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SQL, HTML = os.path.join(REPO, "dev/sql/setup.sql"), os.path.join(REPO, "index.html")
data = subprocess.check_output(["node", "gen_econ.js", "game.html"], cwd="/tmp/mw/t").decode()
json.loads(data); assert "'" not in data
line = "create or replace function public.econ_data() returns jsonb language sql immutable as $$ select '" + data + "'::jsonb $$;\n"
s = open(SQL, encoding="utf8").read()
a = s.index("-- ECON_DATA_BEGIN\n") + len("-- ECON_DATA_BEGIN\n"); b = s.index("-- ECON_DATA_END")
s = s[:a] + line + s[b:]
open(SQL, "w", encoding="utf8").write(s)
h = open(HTML, encoding="utf8").read()
i = h.index("<!-- SUPABASE SETUP SQL")
a = h.index("\n-----", i); a = h.index("\n", a + 1) + 1
b = h.index("\n-----", a)
h = h[:a] + s.rstrip("\n") + "\n" + h[b + 1:]
open(HTML, "w", encoding="utf8").write(h)
print("econ_data", len(data), "· setup.sql → index.html synced")
