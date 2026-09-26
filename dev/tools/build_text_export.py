#!/usr/bin/env python3
"""Build the player-facing text export of Menalars (for an outside editor/AI).
Inputs : index.html, text_export/_data.json (tools: dump via harness), text_export/_scan.json (tools/text_scan.py)
Outputs: text_export/01_…05_*.txt  +  text_export/_map.json (ID → where it lives, original text) for re-import."""
import json, re, html
from html.parser import HTMLParser

W = "/tmp/mw/"
SRC = open(W + "index.html", encoding="utf8").read()
D = json.load(open(W + "text_export/_data.json", encoding="utf8"))
SCAN = json.load(open(W + "text_export/_scan.json", encoding="utf8"))
TH = re.compile(r'[฀-๿]')

PLAYER = "ผู้เล่น (นักกวาดล้าง)"
NARR = "ผู้บรรยาย (Narrator)"
SYS = "System (ระบบ)"
BTN = "ผู้เล่น (ปุ่มตัวเลือก)"
NPC = {k: v for k, v in D["STORY_NPC_NAME"].items()}
NPC_FULL = {k: v["name"] for k, v in D["NPC_TALK_PROFILE"].items()}

MAP = {}          # id -> {src, original}
def rec(i, src, text):
    assert i not in MAP, i
    MAP[i] = {"src": src, "text": text}

class Out:
    def __init__(self, title, intro):
        self.parts = [title, "=" * 72, intro.strip(), ""]
    def h(self, t, ch="="):
        self.parts += ["", ch * 72, t, ch * 72, ""]
    def note(self, t):
        self.parts += [t, ""]
    def e(self, i, typ, speaker, listener, text, ctx=None, src=None):
        if src is not None: rec(i, src, text)
        self.parts.append(f"[{i}] - [{typ}]")
        if ctx: self.parts.append(f"บริบท (Context): {ctx}")
        self.parts.append(f"ผู้พูด (Speaker): {speaker}")
        self.parts.append(f"ผู้ฟัง (Listener): {listener}")
        self.parts.append("ข้อความ (Text):")
        self.parts.append(text.strip("\n"))
        self.parts.append("-" * 40)
    def save(self, name):
        open(W + "text_export/" + name, "w", encoding="utf8").write("\n".join(self.parts).rstrip() + "\n")

# ---------- JS literal → readable text (code parts become {placeholders}) ----------
def js_unescape(body):
    out, i = [], 0
    while i < len(body):
        c = body[i]
        if c == "\\" and i + 1 < len(body):
            n = body[i + 1]
            if n == "n": out.append("\n"); i += 2; continue
            if n == "t": out.append("\t"); i += 2; continue
            if n == "u": out.append(chr(int(body[i + 2:i + 6], 16))); i += 6; continue
            out.append(n); i += 2; continue
        out.append(c); i += 1
    return "".join(out)
WRAP = ("netEsc", "talkMarkup", "esc", "String", "Math.round", "Math.floor", "Math.max", "Math.min", "fmtNum", "tutMd", "clean")
HINT_TH = {"name": "ชื่อ", "gold": "ทอง", "exp": "EXP", "ch": "เลขบท", "qty": "จำนวน", "n": "จำนวน", "count": "จำนวน", "need": "จำนวน",
           "storyPillarsLit": "จำนวนเสา", "next": "เลขมิติ", "tier": "เลขแมพ", "level": "เลเวล", "lv": "เลเวล", "price": "ราคา",
           "total": "รวม", "left": "เวลาที่เหลือ", "icon": "ไอคอน", "label": "ชื่อ", "title": "ชื่อ", "desc": "คำอธิบาย"}
def hint(expr):
    e = expr.strip()
    if "?" in e or "`" in e or "=>" in e: return "{…}"
    m = re.match(r'([\w.]+)\((.*)\)$', e, re.S)
    if m and m.group(1) in WRAP: e = m.group(2)
    ids = re.findall(r'[A-Za-z_]\w*', e)
    h = ids[-1] if ids else "ค่า"
    if m and m.group(1) not in WRAP: h = m.group(1).split(".")[-1]
    return "{" + HINT_TH.get(h, h) + "}"
TAG = re.compile(r'<(/?)([a-zA-Z][\w-]*)([^<>]*)>')
def clean_tags(t):
    def f(m):
        name = m.group(2).lower()
        if name == "br": return "\n"
        if name in ("b", "kbd"): return f"<{m.group(1)}{name}>"
        return " "
    t = TAG.sub(f, t)
    t = re.sub(r"[ \t]{2,}", " ", t)
    return "\n".join(x.strip() for x in t.split("\n")).strip()
def piece_text(p):
    st, en, q, exprs = p
    if q != "`":
        return js_unescape(SRC[st + 1:en - 1])
    raw = lambda a, b: js_unescape(re.sub(r"\n\s*", " ", SRC[a:b]))
    out, i = [], st + 1
    for (x, y) in exprs:
        out.append(raw(i, x)); out.append(hint(SRC[x + 2:y - 1])); i = y
    out.append(raw(i, en - 1))
    return "".join(out)
def lit_text(o):
    return clean_tags("".join(hint(SRC[p[1]:p[2]]) if p[0] == "expr" else piece_text(p) for p in o["pieces"]))

# ---------- scanned literals grouped by owner function ----------
DATA_CONSTS = set("""STORY_QUESTS STORY_CHAPTERS STORY_NPC_NAME LETTER_DEFS LETTER_CATS LETTER_SPY_PAGES RESEARCHER_LINES DOCTOR_LINES
MONK_LINES TOWN_LORD_LORE QUEST_DEFS MERCHANT_TIPS BLACKSMITH_TIPS TUTORIAL_STEPS TUT_INPUT NPC_TALK_PROFILE STAT_INFO SANITY_MADNESS
SANITY_ALERT_TITLES DIM_RULES SKILL_DEFS WEAPON_SKILL_TREES TITLE_DEFS TITLE_CATS TITLE_TIERS SECRET_LOCATION_DEFS DUNGEON_ROOM_INFO
MONK_GRADES ITEM_TABLE CARD_DEFS MILESTONE_DEFS MAP_DEFS TOWN_DEF PLAYER_PRESETS WILL_COLORS ACHIEVEMENT_DEFS""".split())
EXPR = r'[\w.$]+(?:\([^()"\'`;{}]*\))?(?:\[[^\]]*\])?(?:\.[\w$]+(?:\([^()"\'`;{}]*\))?)*'
GAP = re.compile(r'\s*\+\s*(' + EXPR + r')\s*\+\s*')
by_fn = {}
for o in SCAN:
    if o["fn"] in DATA_CONSTS: continue
    lst = by_fn.setdefault(o["fn"], [])
    if lst:
        prev = lst[-1]; pend = prev["pieces"][-1][1] if prev["pieces"][-1][0] != "expr" else prev["pieces"][-1][2]
        m = GAP.fullmatch(SRC[pend:o["start"]]) if o["start"] - pend < 80 else None
        if m:
            prev["pieces"].append(["expr", pend + m.start(1), pend + m.end(1)])
            prev["pieces"].extend(o["pieces"]); continue
    lst.append(o)
used_fn = set()
def fn_group(pred):
    fns = [f for f in by_fn if f not in used_fn and pred(f)]
    fns.sort(key=lambda f: by_fn[f][0]["start"])
    used_fn.update(fns)
    return fns
FN_SPEAKER = {"renderTownLordDialog": NPC_FULL["town_lord"], "renderTempleDialog": NPC_FULL["temple"],
              "openMerchantDialog": NPC_FULL["merchant"], "openBlacksmithDialog": NPC_FULL["blacksmith"],
              "letterDeliverAll": NPC_FULL["town_lord"], "letterSpyConfront": NPC_FULL["town_lord"],
              "storyAfterStart": "NPC ผู้ให้ภารกิจ", "storyAfterComplete": "NPC ที่เพิ่งส่งภารกิจ"}
def who(o, fn):
    key, call = o["key"], o["call"]
    if key in ("label", "sub"): return BTN, (FN_SPEAKER.get(fn) or SYS)
    if call.endswith("showToast") or call.endswith("showDiscoveryBanner"): return SYS + " — แจ้งเตือนมุมจอ", PLAYER
    if fn == "storyNpcDialog" and key in ("researcher", "doctor", "monk"): return NPC_FULL[key], PLAYER
    if fn.startswith("tut") and key in ("text", "title", "tip", ""): return "โค้ชลานฝึก (การ์ดคำแนะนำ)", PLAYER
    if re.search(r'<(span|div|h5|b class|p[ >])', SRC[o["start"]:o["pieces"][-1][1] if o["pieces"][-1][0] != "expr" else o["pieces"][-1][2]]): return SYS + " — ป้าย/การ์ดในหน้าต่าง", PLAYER
    if fn in FN_SPEAKER and key in ("text", "") and call in ("", "renderTownLordDialog", "openTalk", "renderTempleDialog", "storyNpcDialog"):
        return FN_SPEAKER[fn], PLAYER
    return SYS, PLAYER
def emit_fns(out, fns, typ, header=True):
    for fn in fns:
        items = by_fn[fn]
        if header: out.h(f"จากส่วนโค้ด: {fn}  ({len(items)} ข้อความ)", "-")
        for n, o in enumerate(items, 1):
            t = lit_text(o)
            if not TH.search(t): continue
            sp, li = who(o, fn)
            ctxs = [f"บรรทัด {o['line']}"]
            if o["key"]: ctxs.append(f"ช่อง {o['key']}")
            if o["call"]: ctxs.append(f"ใช้ใน {o['call']}()")
            out.e(f"SRC.{fn}.{n}", typ, sp, li, t, " · ".join(ctxs),
                  src={"kind": "js", "pieces": [[p[0], p[1]] for p in o["pieces"] if p[0] != "expr"], "line": o["line"]})

# ---------- HTML text nodes ----------
class HP(HTMLParser):
    def __init__(self, base):
        super().__init__(convert_charrefs=True); self.base = base; self.stack = []; self.items = []
    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag not in ("br", "input", "img", "hr", "meta", "link", "path", "circle", "line", "source") :
            self.stack.append((tag, a.get("id")))
        for k in ("placeholder", "title", "aria-label"):
            if a.get(k) and TH.search(a[k]): self.items.append((self.ctx(a.get("id")), f"[{k}] " + a[k], self.getpos()[0] + self.base))
    def handle_startendtag(self, tag, attrs):
        a = dict(attrs)
        for k in ("placeholder", "title", "aria-label"):
            if a.get(k) and TH.search(a[k]): self.items.append((self.ctx(a.get("id")), f"[{k}] " + a[k], self.getpos()[0] + self.base))
    def handle_endtag(self, tag):
        for k in range(len(self.stack) - 1, -1, -1):
            if self.stack[k][0] == tag: del self.stack[k:]; break
    def ctx(self, own=None):
        ids = [i for _, i in self.stack if i]
        if own: ids.append(own)
        return "#" + ids[-1] if ids else "(หน้าเว็บ)"
    def handle_data(self, data):
        t = " ".join(data.split())
        if TH.search(t): self.items.append((self.ctx(), t, self.getpos()[0] + self.base))
b0 = SRC.index("<body>"); s0 = SRC.index("<script>", b0)
p = HP(SRC.count("\n", 0, b0)); p.feed(SRC[b0:s0])
HTML_ITEMS = p.items  # (ctx id, text, line)
def html_group(pred):
    return [it for it in HTML_ITEMS if pred(it[0])]
def html_container_owner(ctx):
    return ctx
# group consecutive HTML items under their top container (id) for readability
def emit_html(out, items, typ, prefix):
    cur, cnt = None, {}
    for ctx, t, line in items:
        if ctx != cur:
            out.h(f"หน้าจอ/กล่อง: {ctx}", "-"); cur = ctx
        cnt[ctx] = n = cnt.get(ctx, 0) + 1
        out.e(f"HTML{ctx}.{n}", typ, SYS, PLAYER, t, f"บรรทัด {line} (ข้อความบนหน้าจอ)", src={"kind": "html", "line": line})

# =====================================================================================
# 01 — main story
# =====================================================================================
o1 = Out("Menalars — 01 เนื้อเรื่องหลัก (Main Quest) · เรียงตามลำดับที่ผู้เล่นเจอจริง", """
ภารกิจหลัก "ฟื้นเสาบาเรีย 10 ต้น" — 10 บท 54 ภารกิจ เดินเป็นเส้นเดียว บทที่ N เกิดในแมพ N
ลำดับข้อความในแต่ละภารกิจ = ลำดับที่ผู้เล่นเห็น:
  ① name (ชื่อภารกิจ)  ② give (ตอนรับภารกิจ)  ③ desc (เป้าหมายบนแถบติดตาม)  ④ จุดสำรวจ/ตัวเลือก  ⑤ fight (ตอนเริ่มสู้บอส)  ⑥ done (ตอนภารกิจสำเร็จ/ส่งภารกิจ)
• give ที่ผู้พูดเป็น "ผู้บรรยาย" = ขึ้นในหน้าต่าง 📜 ต่อจากภารกิจก่อนหน้าทันที (ไม่มี NPC ยื่นให้)
• done ที่ผู้พูดเป็น "ผู้บรรยาย" = ภารกิจจบกลางแมพเอง (ไม่ต้องกลับไปหา NPC)
• ตัวเลือกของผู้เล่น (Choice) มีผลแค่ข้อความตอบกลับ ไม่เปลี่ยนเส้นเรื่อง
""")
o1.h("บทนำ (หน้าสร้างตัวละคร — ก่อนเริ่มเกม)")
for ctx, t, line in html_group(lambda c: c in ("#creationCard", "#creation-screen")):
    pass
# prologue = heading + sub paragraph of the creation card
pro = [it for it in HTML_ITEMS if it[1].startswith("คุณฟื้นขึ้นข้างเกวียน") or it[1].startswith("บาเรียบนฟ้าเพิ่งแตก")]
for k, (ctx, t, line) in enumerate(pro, 1):
    o1.e(f"PROLOGUE.{k}", "Prologue", NARR, PLAYER, t, "หน้าสร้างตัวละคร (ก่อนเข้าเกมครั้งแรก)" + (" · หัวเรื่อง" if k == 1 else " · คำบรรยายใต้หัวเรื่อง"), src={"kind": "html", "line": line})
HTML_USED = set(it[2] for it in pro)

o1.h("ชื่อบท (Chapter names)")
for n, c in D["STORY_CHAPTERS"].items():
    o1.e(f"STORY.chapter{n}", "Main Quest – Chapter Title", SYS, PLAYER, c["name"], f"ชื่อบทที่ {n}", src={"kind": "data", "path": ["STORY_CHAPTERS", n, "name"]})

GOALTXT = {"kill": "ปราบมอน", "boss": "ปราบบอส", "win": "ชนะการต่อสู้", "stat": "ทำสถิติ", "spot": "สำรวจจุด 📜",
           "drop": "เก็บของจากมอน", "give": "นำของไปให้", "meditate": "ทำสมาธิ", "talk": "ไปคุย"}
cur_ch = None
for qi, q in enumerate(D["STORY_QUESTS"]):
    if q["ch"] != cur_ch:
        cur_ch = q["ch"]
        o1.h(f"บทที่ {cur_ch} · {D['STORY_CHAPTERS'][str(cur_ch)]['name']}  (แมพ {cur_ch})")
    frm, npc, g = q.get("from"), q.get("npc"), q["goal"]
    turn_in = g.get("npc") if g["type"] == "talk" else npc
    o1.note(f"### ภารกิจ {q['id']} — \"{q['name']}\" · ผู้ให้: {NPC.get(frm, 'ขึ้นเอง') if frm else 'ขึ้นเอง'} · ส่งที่: {NPC.get(turn_in) if turn_in else 'จบกลางแมพ'} · เป้าหมาย: {GOALTXT.get(g['type'], g['type'])}")
    base = ["STORY_QUESTS", qi]
    o1.e(f"STORY.{q['id']}.name", "Main Quest – ชื่อภารกิจ", SYS, PLAYER, q["name"], f"บทที่ {q['ch']}", src={"kind": "data", "path": base + ["name"]})
    if q.get("give"):
        if frm: o1.e(f"STORY.{q['id']}.give", "Main Quest", NPC[frm], PLAYER, q["give"], f"ตอนเสนอภารกิจ (ผู้เล่นกดคุยกับ{NPC[frm]} → ปุ่ม ✅ รับภารกิจ)", src={"kind": "data", "path": base + ["give"]})
        else: o1.e(f"STORY.{q['id']}.give", "Main Quest", NARR, PLAYER, q["give"], "ขึ้นทันทีเมื่อเข้าเกมครั้งแรก (ฉากเปิดเรื่อง)" if qi == 0 else "ขึ้นเองในหน้าต่าง 📜 ภารกิจหลัก ต่อจากภารกิจก่อนหน้า", src={"kind": "data", "path": base + ["give"]})
    o1.e(f"STORY.{q['id']}.desc", "Main Quest – Objective", SYS, PLAYER, q["desc"], "เป้าหมายบนแถบติดตามภารกิจ (มุมขวาบน) และการ์ดภารกิจ", src={"kind": "data", "path": base + ["desc"]})
    for k, sp in enumerate(g.get("spots") or [], 1):
        spk = f"{NARR} / {sp['name']}" if ('"' in sp["text"] or "“" in sp["text"] or sp.get("portrait")) else NARR
        o1.e(f"STORY.{q['id']}.spot{k}.name", "Main Quest – ชื่อจุดสำรวจ", SYS, PLAYER, sp["name"], f"จุดสำรวจที่ {k} {sp['icon']} (ป้ายหัวหน้าต่าง)", src={"kind": "data", "path": base + ["goal", "spots", k - 1, "name"]})
        o1.e(f"STORY.{q['id']}.spot{k}.text", "Main Quest", spk, PLAYER, sp["text"], f"เดินถึงจุดสำรวจ {sp['icon']} {sp['name']}", src={"kind": "data", "path": base + ["goal", "spots", k - 1, "text"]})
        ch = sp.get("choice")
        if ch:
            for oi, op in enumerate(ch["options"]):
                o1.e(f"STORY.{q['id']}.spot{k}.choice.{op['val']}.label", "Main Quest – Choice", BTN, sp["name"], f"{op['icon']} {op['label']}", f"ตัวเลือกของผู้เล่นที่จุด {sp['name']} (key {ch['key']})", src={"kind": "data", "path": base + ["goal", "spots", k - 1, "choice", "options", oi, "label"]})
                o1.e(f"STORY.{q['id']}.spot{k}.choice.{op['val']}.text", "Main Quest", NARR, PLAYER, op["text"], f"ผลหลังเลือก \"{op['label']}\"", src={"kind": "data", "path": base + ["goal", "spots", k - 1, "choice", "options", oi, "text"]})
    if q.get("fight"):
        o1.e(f"STORY.{q['id']}.fight", "Main Quest", NARR, PLAYER, q["fight"], "ป้ายข้อความขึ้นกลางจอตอนเริ่มสู้บอส", src={"kind": "data", "path": base + ["fight"]})
    if q.get("done"):
        if turn_in: o1.e(f"STORY.{q['id']}.done", "Main Quest", NPC[turn_in], PLAYER, q["done"], f"ตอนส่งภารกิจที่{NPC[turn_in]} (ปุ่ม 🎁 ส่งภารกิจ)", src={"kind": "data", "path": base + ["done"]})
        else: o1.e(f"STORY.{q['id']}.done", "Main Quest", NARR, PLAYER, q["done"], "ขึ้นเองเมื่อทำเป้าหมายครบกลางแมพ", src={"kind": "data", "path": base + ["done"]})

o1.h("ประโยคทั่วไปของระบบภารกิจหลัก (ใช้ได้กับหลายภารกิจ)")
emit_fns(o1, fn_group(lambda f: f.startswith("story") or f == "openStoryLog"), "Main Quest – System")
o1.save("01_main_story.txt")

# =====================================================================================
# 02 — letters
# =====================================================================================
o2 = Out("Menalars — 02 จดหมายที่ส่งไม่ถึง (Mails) + เหตุการณ์ 'จดหมายที่ถูกผนึก'", """
จดหมาย 60 ฉบับ ผู้เล่นเก็บได้แบบสุ่มระหว่างสำรวจ (ก็อบลินขโมยมา / คนส่งสารไปไม่ถึง) อ่านได้ทันที แล้วนำไปส่งเจ้าเมืองรับรางวัลเล็กๆ
ไม่มีลำดับเวลาตายตัว — เรียงตามหมวดและเลขฉบับ (หมวดส่วนตัวเจอบ่อยสุด, บันทึก/รายงานรองลงมา, สารลับคณะหนึ่งเดียวหายาก, ฉบับผนึกหายากที่สุด)
หลายฉบับต่อเรื่องกันเป็นคู่ (เช่น L08↔L09 ศิลา–น้ำฝน) และหลายฉบับเป็นเบาะแสเนื้อเรื่องหลัก
รูปแบบในเกม: หัวจดหมาย "จาก … ถึง …" / เนื้อความ / บรรทัดลงชื่อ
""")
cats = D["LETTER_CATS"]
cur = None
for li, L in enumerate(D["LETTER_DEFS"]):
    if L["cat"] != cur:
        cur = L["cat"]; c = cats[cur]
        o2.h(f"{c['icon']} หมวด: {c['label']}")
    ctx = f"{cats[L['cat']]['icon']} {cats[L['cat']]['label']}"
    if L.get("acrostic"):
        ctx += " · ⚠️ ฉบับรหัสลับ: คำแรกของทุกบรรทัดอ่านเรียงลงมาได้ว่า \"" + " ".join(L["acrostic"]) + "\" — ถ้าแก้ ต้องคงคำแรกของแต่ละบรรทัดไว้ตามนี้"
    text = L["body"] + "\n(ลงชื่อ) " + L["sign"]
    if L.get("note"): text += "\n(หมายเหตุใต้จดหมาย) " + L["note"]
    o2.e(f"LETTER.{L['id']}", f"Mail – {cats[L['cat']]['label']}", L["from"], L["to"], text, ctx,
         src={"kind": "data", "path": ["LETTER_DEFS", li], "fields": ["body", "sign", "note", "from", "to"]})
o2.h("🖋️ เหตุการณ์ต่อจากจดหมายผนึก (L60): เปิดโปงเจ้าเมืองตัวปลอม — เรียงตามฉาก")
o2.note("ผู้เล่นยื่นจดหมายผนึกให้เจ้าเมืองดู → เจ้าเมือง (ตัวปลอม) กลายร่าง → สู้ → ฉากต่อไปนี้")
for k, pg in enumerate(D["LETTER_SPY_PAGES"], 1):
    sp = pg["name"] if pg.get("npcKind") else NARR
    o2.e(f"SPY.page{k}", "Mail – Event", sp, PLAYER, pg["text"], f"ฉากที่ {k}/5 · หัวหน้าต่าง: {pg.get('emoji', '')} {pg['name']}", src={"kind": "data", "path": ["LETTER_SPY_PAGES", k - 1, "text"]})
o2.h("ข้อความระบบจดหมาย (ตอนเก็บได้ / อ่าน / ส่งเจ้าเมือง)")
emit_fns(o2, fn_group(lambda f: f.startswith("letter") or f == "turnInOldLetterMerchantUnused"), "Mail – System")
o2.save("02_letters.txt")

# =====================================================================================
# 03 — NPC dialogue + side quest
# =====================================================================================
o3 = Out("Menalars — 03 บทสนทนา NPC ในเมือง + ภารกิจรอง (NPC Dialogue / Side Quest)", """
NPC ทั้ง 8 ในเมือง "แดนมานาอรุณ" — ข้อความทักทาย, คำแนะนำสุ่ม (กด 💬), ภารกิจรอง และบทพูดตามปุ่มต่างๆ
(บทพูดของ NPC ในภารกิจหลักอยู่ในไฟล์ 01 แล้ว)
ผู้พูด "ผู้เล่น (ปุ่มตัวเลือก)" = ข้อความบนปุ่มที่ผู้เล่นกดตอบ
""")
o3.h("รายชื่อ NPC (ชื่อ + ป้ายบทบาทที่หัวหน้าต่างคุย)")
for k, v in D["NPC_TALK_PROFILE"].items():
    o3.e(f"NPC.{k}.profile", "NPC Profile", SYS, PLAYER, f"ชื่อ: {v['name']}\nป้ายบทบาท: {v['role']}", "หัวหน้าต่างคุย", src={"kind": "data", "path": ["NPC_TALK_PROFILE", k], "fields": ["name", "role"]})
o3.h("👑 เจ้าเมือง — ภารกิจรอง + เรื่องเล่าเมือง")
qd = D["QUEST_DEFS"]["junk_hunt"]
o3.e("SIDE.junk_hunt.name", "Side Quest – ชื่อภารกิจ", SYS, PLAYER, qd["name"], "ภารกิจรองจากเจ้าเมือง (ทำได้ครั้งเดียว)", src={"kind": "data", "path": ["QUEST_DEFS", "junk_hunt", "name"]})
o3.e("SIDE.junk_hunt.give", "Side Quest", NPC_FULL["town_lord"], PLAYER, qd["npcGiveText"], "ตอนเสนอภารกิจ", src={"kind": "data", "path": ["QUEST_DEFS", "junk_hunt", "npcGiveText"]})
o3.e("SIDE.junk_hunt.done", "Side Quest", NPC_FULL["town_lord"], PLAYER, qd["npcCompleteText"], "ตอนส่งภารกิจ", src={"kind": "data", "path": ["QUEST_DEFS", "junk_hunt", "npcCompleteText"]})
for k, t in enumerate(D["TOWN_LORD_LORE"], 1):
    o3.e(f"NPC.town_lord.lore{k}", "NPC Dialogue", NPC_FULL["town_lord"], PLAYER, t, "ปุ่ม 💬 เล่าเรื่องเมืองให้ฟังหน่อย (สุ่ม 1 ประโยค)", src={"kind": "data", "path": ["TOWN_LORD_LORE", k - 1]})
emit_fns(o3, fn_group(lambda f: f == "renderTownLordDialog"), "NPC Dialogue", header=False)
for kind, arr, title in (("researcher", "RESEARCHER_LINES", "🗼 นักวิจัย"), ("doctor", "DOCTOR_LINES", "🩺 หมอ"), ("monk", "MONK_LINES", "🪷 พระ")):
    o3.h(f"{title} — คำแนะนำสุ่ม (ปุ่ม 💬 ขอคำแนะนำ)")
    for k, t in enumerate(D[arr], 1):
        o3.e(f"NPC.{kind}.line{k}", "NPC Dialogue", NPC_FULL[kind], PLAYER, t, "สุ่ม 1 ประโยคเมื่อกด 💬 ขอคำแนะนำ", src={"kind": "data", "path": [arr, k - 1]})
o3.h("นักวิจัย / หมอ / พระ — คำทักทายและปุ่ม")
emit_fns(o3, fn_group(lambda f: f == "storyNpcDialog"), "NPC Dialogue", header=False)
o3.h("🛒 พ่อค้า")
for k, t in enumerate(D["MERCHANT_TIPS"], 1):
    o3.e(f"NPC.merchant.tip{k}", "NPC Tip", NPC_FULL["merchant"], PLAYER, t, "คำแนะนำสุ่มจากพ่อค้า", src={"kind": "data", "path": ["MERCHANT_TIPS", k - 1]})
emit_fns(o3, fn_group(lambda f: f == "openMerchantDialog"), "NPC Dialogue", header=False)
o3.h("🔨 ช่างตีเหล็ก")
for k, t in enumerate(D["BLACKSMITH_TIPS"], 1):
    o3.e(f"NPC.blacksmith.tip{k}", "NPC Tip", NPC_FULL["blacksmith"], PLAYER, t, "คำแนะนำสุ่มจากช่างตีเหล็ก", src={"kind": "data", "path": ["BLACKSMITH_TIPS", k - 1]})
emit_fns(o3, fn_group(lambda f: f == "openBlacksmithDialog"), "NPC Dialogue", header=False)
o3.h("🛕 นักบวชแห่งบาเรีย — พิธีข้ามมิติ")
emit_fns(o3, fn_group(lambda f: f in ("renderTempleDialog", "performDimensionRitual")), "NPC Dialogue", header=False)
o3.h("อื่นๆ ในหน้าต่างคุย / NPC")
emit_fns(o3, fn_group(lambda f: f in ("buildTownNpcs", "TALK_LEAVE", "talkPickLine", "interactWithTravelGate", "interactWithNpcDefault", "npcTalkAnchor")), "NPC Dialogue")
o3.save("03_npc_dialogue.txt")

# =====================================================================================
# 04 — system texts (guide, training, stats, sanity, skills, titles, exploration, items)
# =====================================================================================
o4 = Out("Menalars — 04 คำอธิบายระบบ (System Texts)", """
ข้อความอธิบายระบบที่ผู้เล่นอ่าน: คู่มือ ❓ วิธีเล่น, ลานฝึกจับมือทำ, สเตตัส, สติ/ทำสมาธิ, มินิเกมพระ, มิติ, สกิล, ฉายา, จุดลับ/ดันเจี้ยน, คำอธิบายไอเทม
""")
o4.h("❓ คู่มือวิธีเล่น (หน้าต่างคู่มือ เปิดได้ทุกเมื่อ) — เรียงตามหน้า")
for k, st in enumerate(D["TUTORIAL_STEPS"], 1):
    o4.e(f"GUIDE.page{k}", "System – Guide", SYS, PLAYER, f"หัวข้อ: {st['title']}\n{st['text']}", f"หน้า {k}/{len(D['TUTORIAL_STEPS'])}", src={"kind": "data", "path": ["TUTORIAL_STEPS", k - 1], "fields": ["title", "text"]})
emit_fns(o4, fn_group(lambda f: f in ("renderTutorialStep", "closeTutorial", "#tutorialTrainBtn")), "System – Guide", header=False)
o4.h("🎯 ลานฝึกจับมือทำ (ตัวละครใหม่เล่นก่อนเข้าเกม) — ขั้นตอนตามลำดับ")
o4.note("ตัวแปร {KEY} {SKILL} ในข้อความ = ปุ่มคีย์บอร์ด/ชื่อสกิลที่เกมเติมให้ · <kbd> = กรอบปุ่ม · ขั้นท่าพิเศษอาวุธแยกตามอาวุธที่ผู้เล่นใช้ (ดาบ/ค้อน/ธนู/สื่อเวทย์)")
for w, v in D["TUT_INPUT"].items():
    o4.e(f"TRAIN.input.{w}", "System – Training", "โค้ชลานฝึก", PLAYER, f"หัวข้อ: {v['title']}\n{v['text']}", f"ขั้นท่าพิเศษ (เฉพาะผู้ใช้{ {'sword':'ดาบ','heavy':'ค้อน','bow':'ธนู','orb':'สื่อเวทย์'}[w] })", src={"kind": "data", "path": ["TUT_INPUT", w], "fields": ["title", "text"]})
emit_fns(o4, fn_group(lambda f: f.startswith("tut") or f.startswith("TUT")), "System – Training")
o4.h("📋 สเตตัส 6 ค่า")
for k, v in D["STAT_INFO"].items():
    o4.e(f"STAT.{k}", "System – Stat", SYS, PLAYER, f"ชื่อ: {v['label']}\nคำอธิบาย: {v['desc']}", f"สเตตัส {k}", src={"kind": "data", "path": ["STAT_INFO", k], "fields": ["label", "desc"]})
o4.h("🧘 สติ / อาการเมื่อสติต่ำ / ทำสมาธิ / มินิเกมพระ")
for k, v in enumerate(D["SANITY_MADNESS"], 1):
    o4.e(f"SANITY.madness{k}", "System – Sanity", SYS, PLAYER, f"ชื่ออาการ: {v['name']}\nคำอธิบาย: {v['desc']}\nป้ายสั้น: {v['tag']}", f"เมื่อสติต่ำกว่า {v['below']}%", src={"kind": "data", "path": ["SANITY_MADNESS", k - 1], "fields": ["name", "desc", "tag"]})
for k, t in enumerate(D["SANITY_ALERT_TITLES"]):
    if t: o4.e(f"SANITY.alert{k}", "System – Sanity", SYS, PLAYER, t, f"หัวข้อหน้าต่างเตือนสติระดับ {k}", src={"kind": "data", "path": ["SANITY_ALERT_TITLES", k]})
for k, v in enumerate(D["MONK_GRADES"], 1):
    o4.e(f"MONK.grade{v['grade']}", "System – Monk", SYS, PLAYER, v["title"], f"ผลมินิเกมนั่งสมาธิกับพระ เกรด {v['grade']}", src={"kind": "data", "path": ["MONK_GRADES", k - 1, "title"]})
emit_fns(o4, fn_group(lambda f: any(x in f.lower() for x in ("sanity", "monk", "meditat", "madhead")) or f in ("MAD_HEADS", "MAD_HEAD_ICON")), "System – Sanity")
o4.h("🌌 มิติ (กฎหลอมรวมในมิติสูง)")
for k, v in enumerate(D["DIM_RULES"], 1):
    o4.e(f"DIM.{v['id']}", "System – Dimension", SYS, PLAYER, f"ชื่อ: {v['name']}\nคำอธิบาย: {v['desc']}", "กฎพิเศษของมิติ (สุ่มตามชั้นมิติ)", src={"kind": "data", "path": ["DIM_RULES", k - 1], "fields": ["name", "desc"]})
o4.h("⚔️ สกิล")
for k, v in D["SKILL_DEFS"].items():
    txt = f"ชื่อ: {v['name']}" + (f"\nคำอธิบาย: {v['desc']}" if v.get("desc") else "")
    o4.e(f"SKILL.{k}", "System – Skill", SYS, PLAYER, txt, "สกิลกดใช้" + (f" ({v.get('weaponType')})" if v.get("weaponType") else " (พื้นฐาน)"), src={"kind": "data", "path": ["SKILL_DEFS", k], "fields": ["name", "desc"]})
for w, tree in D["WEAPON_SKILL_TREES"].items():
    for ti, tier in enumerate(tree["tiers"]):
        for si, sk in enumerate(tier["skills"]):
            if sk.get("active") or not sk.get("name"): continue
            o4.e(f"SKILLTREE.{w}.{sk['id']}", "System – Skill", SYS, PLAYER, f"ชื่อ: {sk['name']}\nคำอธิบาย: {sk.get('desc', '')}", f"พาสสิฟ ต้นสกิล{w} Tier {ti + 1}", src={"kind": "data", "path": ["WEAPON_SKILL_TREES", w, "tiers", ti, "skills", si], "fields": ["name", "desc"]})
o4.h("🏅 ฉายา (ชื่อ + เงื่อนไข)")
for k, v in enumerate(D["TITLE_DEFS"]):
    o4.e(f"TITLE.{v['id']}", "System – Title", SYS, PLAYER, f"ชื่อ: {v['name']}\nคำอธิบาย: {v['desc']}", f"หมวด {v['cat']} · ระดับ {D['TITLE_TIERS'][str(v['tier'])]['label']}", src={"kind": "data", "path": ["TITLE_DEFS", k], "fields": ["name", "desc"]})
for k, v in enumerate(D["MILESTONE_DEFS"]):
    o4.e(f"MILESTONE.{v['id']}", "System – Milestone", SYS, PLAYER, f"ชื่อ: {v['name']}\nคำอธิบาย: {v['desc']}", "เป้าหมายพิเศษ", src={"kind": "data", "path": ["MILESTONE_DEFS", k], "fields": ["name", "desc"]})
o4.h("🗺️ จุดลับ / ดันเจี้ยน / สำรวจ")
for k, v in D["SECRET_LOCATION_DEFS"].items():
    o4.e(f"LOCATION.{k}", "System – Exploration", NARR, PLAYER, f"ชื่อ: {v['name']}\nคำบรรยาย: {v['flavor']}", "จุดลับเรืองแสงในแมพ", src={"kind": "data", "path": ["SECRET_LOCATION_DEFS", k], "fields": ["name", "flavor"]})
for k, v in D["DUNGEON_ROOM_INFO"].items():
    o4.e(f"DUNGEON.{k}", "System – Exploration", NARR, PLAYER, f"ชื่อห้อง: {v['label']}\nคำบรรยาย: {v['desc']}", "ห้องในดันเจี้ยน", src={"kind": "data", "path": ["DUNGEON_ROOM_INFO", k], "fields": ["label", "desc"]})
emit_fns(o4, fn_group(lambda f: any(x in f for x in ("Location", "Dungeon", "dungeon", "WarpPoint", "SecretLocation"))), "System – Exploration")
o4.h("🎒 คำอธิบายไอเทม")
for k, v in enumerate(D["ITEM_TABLE"]):
    if v.get("desc"):
        o4.e(f"ITEM.{v['id']}", "System – Item", SYS, PLAYER, f"ชื่อ: {v['name']}\nคำอธิบาย: {v['desc']}", "ไอเทม (กระเป๋า/ร้าน)", src={"kind": "data", "path": ["ITEM_TABLE", k], "fields": ["name", "desc"]})
for k, v in D["CARD_DEFS"].items():
    o4.e(f"CARD.{k}", "System – Item", SYS, PLAYER, f"ชื่อ: {v['name']}\nคำอธิบาย: {v['desc']}", "การ์ดสะสม", src={"kind": "data", "path": ["CARD_DEFS", k], "fields": ["name", "desc"]})
o4.save("04_system_texts.txt")

# =====================================================================================
# 05 — everything else the player can read (UI, toasts, panels, online)
# =====================================================================================
o5 = Out("Menalars — 05 ข้อความหน้าจอ / ปุ่ม / แจ้งเตือน (UI & System Messages) — ภาคผนวก", """
ข้อความอื่นทั้งหมดที่ผู้เล่นเห็น: ปุ่ม เมนู หน้าต่าง ป้ายแจ้งเตือน ข้อความออนไลน์ ฯลฯ — เรียงตามส่วนของโค้ด/หน้าจอ
ความสำคัญต่ำกว่าไฟล์ 01–04 (ส่วนใหญ่เป็นคำสั้นๆ) · ส่วนท้ายสุด "GM เท่านั้น" ผู้เล่นทั่วไปไม่เห็น
""")
o5.h("ข้อความบนหน้าเว็บ (HTML)")
rest_html = [it for it in HTML_ITEMS if it[2] not in HTML_USED]
emit_html(o5, rest_html, "UI Text", "HTML")
gm = lambda f: f.lower().startswith("gm") or f.startswith("renderGm") or f.startswith("GM_")
o5.h("ข้อความจากโค้ดเกม")
emit_fns(o5, fn_group(lambda f: not gm(f)), "UI Message")
o5.h("GM เท่านั้น (ผู้เล่นทั่วไปไม่เห็น — ไม่ต้องแก้ก็ได้)")
emit_fns(o5, fn_group(gm), "GM Console")
o5.save("05_ui_messages.txt")

json.dump(MAP, open(W + "text_export/_map.json", "w", encoding="utf8"), ensure_ascii=False)
print("entries:", len(MAP), "unused fns:", [f for f in by_fn if f not in used_fn][:20])
