#!/usr/bin/env python3
"""Scan index.html: every JS string literal (and HTML text) that contains Thai.
Writes text_export/_scan.json: [{kind, line, fn, key, call, raw, pieces:[[start,end]...]}]"""
import re, json, sys
SRC = sys.argv[1] if len(sys.argv) > 1 else "/tmp/mw/index.html"
s = open(SRC, encoding="utf8").read()
TH = re.compile(r'[฀-๿]')
a = s.index("<script>", s.index("<body")) + len("<script>")
b = s.index("</script>", a)
lines_start = [0]
for m in re.finditer("\n", s): lines_start.append(m.end())
import bisect
def line_of(pos): return bisect.bisect_right(lines_start, pos)

lits = []  # (start, end, quote, depth)
def scan_code(i, end, depth, stop_brace=False):
    """scan JS code from i; returns position after matching '}' if stop_brace"""
    brace = 0
    while i < end:
        c = s[i]
        if c == "/" and s[i+1] == "/":
            i = s.index("\n", i); continue
        if c == "/" and s[i+1] == "*":
            i = s.index("*/", i) + 2; continue
        if c in "\"'":
            j = i + 1
            while s[j] != c:
                j += 2 if s[j] == "\\" else 1
            lits.append((i, j + 1, c, depth)); i = j + 1; continue
        if c == "`":
            i = scan_template(i, depth); continue
        if c == "/" :
            # regex literal? previous significant char decides
            k = i - 1
            while k > 0 and s[k] in " \t": k -= 1
            if s[k] in "(,=:[!&|?{};\n" or s[k-5:k+1].endswith("return"):
                j = i + 1; incls = False
                while True:
                    ch = s[j]
                    if ch == "\\": j += 2; continue
                    if ch == "[": incls = True
                    elif ch == "]": incls = False
                    elif ch == "/" and not incls: break
                    elif ch == "\n": break
                    j += 1
                i = j + 1; continue
        if stop_brace:
            if c == "{": brace += 1
            elif c == "}":
                if brace == 0: return i + 1
                brace -= 1
        i += 1
    return i
def scan_template(i, depth):
    j = i + 1; exprs = []
    while s[j] != "`":
        if s[j] == "\\": j += 2; continue
        if s[j] == "$" and s[j+1] == "{":
            k = scan_code(j + 2, b, depth + 1, stop_brace=True)
            exprs.append((j, k)); j = k; continue
        j += 1
    lits.append((i, j + 1, "`", depth, exprs))
    return j + 1
scan_code(a, b, 0)

# top-level declaration names by line
decl = []
for m in re.finditer(r'^(?:async\s+)?function\s+(\w+)|^(?:const|let|var)\s+(\w+)\s*=|^document\.getElementById\("(\w+)"\)', s[a:b], re.M):
    decl.append((a + m.start(), m.group(1) or m.group(2) or ("#" + m.group(3))))
dpos = [d[0] for d in decl]
def owner(pos):
    k = bisect.bisect_right(dpos, pos) - 1
    return decl[k][1] if k >= 0 else "(top)"

out = []
for t in lits:
    st, en, q = t[0], t[1], t[2]
    raw = s[st:en]
    if q == "`":
        # text of the template minus the ${} parts must contain Thai
        body = raw; 
        for (x, y) in reversed(t[4]): body = body[:x-st] + body[y-st:]
        if not TH.search(body): continue
    elif not TH.search(raw): continue
    ls = s.rfind("\n", 0, st) + 1
    before = s[ls:st]
    km = re.search(r'(\w+)\s*:\s*$', before)
    cm = re.search(r'(\w+(?:\.\w+)*)\s*\(\s*$', before)
    out.append(dict(start=st, end=en, q=q, line=line_of(st), fn=owner(st), key=km.group(1) if km else "",
                    call=cm.group(1) if cm else "", exprs=[[x, y] for (x, y) in (t[4] if q == "`" else [])], nested=t[3]))
out.sort(key=lambda o: o["start"])
# merge "a" + "b" chains
merged = []
for o in out:
    if merged:
        p = merged[-1]
        gap = s[p["pieces"][-1][1]:o["start"]]
        if re.fullmatch(r'\s*\+\s*', gap) and p["fn"] == o["fn"]:
            p["pieces"].append([o["start"], o["end"], o["q"], o["exprs"]]); continue
    o["pieces"] = [[o["start"], o["end"], o["q"], o["exprs"]]]
    merged.append(o)
json.dump(merged, open("/tmp/mw/text_export/_scan.json", "w"), ensure_ascii=False)
print(len(lits), len(out), len(merged))
