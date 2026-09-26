#!/usr/bin/env bash
# Builds the scratch workspace /tmp/mw that every dev script expects (same layout as the old Cowork sandbox):
#   /tmp/mw/index.html   = OFFLINE copy of the repo's index.html (NET_CONFIG blank → no login, localStorage save)
#   /tmp/mw/t/game.html  = same file, for the Node harness tests
#   /tmp/mw/assets       → symlink to the repo's assets/
# and serves /tmp/mw on http://localhost:8765 for Playwright. Re-run after every edit of the repo's index.html.
set -e
REPO="$(cd "$(dirname "$0")/.." && pwd)"
W=/tmp/mw
mkdir -p "$W/t/tut" "$W/tools" "$W/text_export"
cp -r "$REPO/dev/t/." "$W/t/"; cp -r "$REPO/dev/tools/." "$W/tools/"
ln -sfn "$REPO/assets" "$W/assets"
python3 - "$REPO/index.html" "$W/index.html" <<'PY'
import re, sys
s = open(sys.argv[1], encoding="utf8").read()
s, n = re.subn(r'NET_CONFIG = \{ url: "[^"]*", anonKey: "[^"]*" \}', 'NET_CONFIG = { url: "", anonKey: "" }', s)
assert n == 1, "NET_CONFIG line not found exactly once"
open(sys.argv[2], "w", encoding="utf8").write(s)
PY
cp "$W/index.html" "$W/t/game.html"
if ! curl -s -o /dev/null http://localhost:8765/index.html; then (cd "$W" && nohup python3 -m http.server 8765 >/dev/null 2>&1 &); sleep 1; fi
echo "workspace ready: $W  (GAME_VERSION $(grep -o 'const GAME_VERSION = [0-9]*' "$W/index.html" | grep -o '[0-9]*$'))"
