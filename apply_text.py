#!/usr/bin/env python3
"""Put revised texts (from a *_improved.txt parsed by check_revised.py) back into index.html, one literal at a time."""
import json, re, sys
W = "/tmp/mw/"
R = json.load(open(sys.argv[1]))          # {'ents':{id:text}, 'changed':[ids]}
FIX = json.load(open(sys.argv[2])) if len(sys.argv) > 2 else {}   # id -> [[old,new],...] extra fixes on the revised text
M = json.load(open(__import__('os').environ.get('MAP','/tmp/mw/text_export/_map.json'),encoding='utf8'))
src = open(W + "index.html", encoding="utf8").read()
def js_unescape(body):
    return json.loads('"' + body.replace('"', '\\"').replace("\\'", "'") + '"') if "\\" in body else body
done, skipped = [], []
for k in R["changed"]:
    new = R["ents"][k]
    for a, b in FIX.get(k, []):
        assert new.count(a) >= 1, (k, a); new = new.replace(a, b)
    old = M[k]["text"]; kind = M[k]["src"]["kind"]
    if kind == "data":
        # find the one JS string literal whose value is exactly the old text
        cands = []
        for q in ('"', "'"):
            lit = json.dumps(old, ensure_ascii=False) if q == '"' else None
            if lit and src.count(lit): cands.append(lit)
        assert len(cands) == 1 and src.count(cands[0]) == 1, (k, len(cands), src.count(cands[0]) if cands else 0)
        src = src.replace(cands[0], json.dumps(new, ensure_ascii=False), 1)
    elif kind == "html":
        assert src.count(old) == 1, (k, src.count(old))
        src = src.replace(old, new, 1)
    else:
        skipped.append(k); continue
    done.append(k)
open(W + "index.html", "w", encoding="utf8").write(src)
print("applied", len(done), "skipped (do by hand):", skipped)
