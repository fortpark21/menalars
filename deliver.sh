#!/usr/bin/env bash
# Copies the OFFLINE working file /tmp/mw/index.html back into the repo with the live NET_CONFIG filled in.
# Only needed when you edited /tmp/mw/index.html (e.g. with the text tools); normal edits go straight into the repo file.
set -e
REPO="$(cd "$(dirname "$0")/.." && pwd)"
python3 - /tmp/mw/index.html "$REPO/index.html" <<'PY'
import sys
s = open(sys.argv[1], encoding="utf8").read()
o = 'NET_CONFIG = { url: "", anonKey: "" }'
assert s.count(o) == 1, "offline NET_CONFIG not found exactly once"
s = s.replace(o, 'NET_CONFIG = { url: "https://oidvrclhnndjnhjfcvyp.supabase.co", anonKey: "sb_publishable_9XOnf5NmpCL9XWkXOiGIeg_rTxfwnrX" }')
open(sys.argv[2], "w", encoding="utf8").write(s)
print("repo index.html updated")
PY
