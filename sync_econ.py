import json, subprocess, sys
P = sys.argv[1] if len(sys.argv) > 1 else "game.html"
data = subprocess.check_output(["node", "gen_econ.js", P]).decode()
json.loads(data)
s = open(P, encoding="utf8").read()
a = s.index("-- ECON_DATA_BEGIN\n") + len("-- ECON_DATA_BEGIN\n"); b = s.index("-- ECON_DATA_END")
assert "'" not in data
line = "create or replace function public.econ_data() returns jsonb language sql immutable as $$ select '" + data + "'::jsonb $$;\n"
s = s[:a] + line + s[b:]
open(P, "w", encoding="utf8").write(s)
print("econ_data", len(data))
