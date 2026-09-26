# Menalars — คู่มือสำหรับ Claude (อ่านก่อนทำงานทุกครั้ง)

เกม RPG บนเบราว์เซอร์ **ไฟล์เดียว** `index.html` (HTML/CSS/JS ล้วน ไม่มี framework/npm) + โฟลเดอร์ `assets/` (รูป .webp, เสียง .mp3)
ออนไลน์ด้วย **Supabase** และโฮสต์บน **GitHub Pages** จาก repo นี้ (`fortpark21/menalars`, branch `main`) — ตอนนี้เป็น **เบต้า** (จะล้างเซิร์ฟก่อนเปิดจริง)
เวอร์ชันล่าสุด: **`GAME_VERSION = 63`** (26 ก.ย. 2026) · ประวัติงานละเอียด v52–v63: `dev/docs/history-v52-v63.md`

## 👤 เจ้าของ (Andy)
- **ไม่ใช่โปรแกรมเมอร์** — อธิบายเป็น **ภาษาไทยง่ายๆ ทีละขั้น** ห้ามใช้ศัพท์เทคนิคโดยไม่อธิบาย
- เวลามีทางเลือก ให้ **ถามครั้งเดียวด้วยปุ่มตัวเลือก** (AskUserQuestion) ใส่ "(แนะนำ)" ที่ตัวเลือกแรก · ระดมสมองให้กระชับ · ชอบทำ "รวดเดียว"
- ชอบเกมท้าทาย, UI ต้องดูเป็นเกม (ไอคอนใหญ่ + hover) ไม่ใช่ตาราง, ชื่อไทยเท่ๆ, สำนวนโบราณ (เจ้า/ข้า) ในบทพูด
- เจ้าของอัปเดตเกมด้วยการ **merge งานเข้า `main`** (GitHub Pages อัปเดตเองใน 1–3 นาที) → บอกขั้นตอนกดปุ่มบน GitHub ให้ชัด และบอกให้เปิดเกมด้วย **Ctrl+F5**
- repo ต้อง **เป็น Public** (GitHub Pages ฟรีใช้กับ repo ส่วนตัวไม่ได้ — เคยปิดแล้วเกมพัง) · ไฟล์เกมบนเบราว์เซอร์ใครก็เซฟได้อยู่แล้ว การซ่อน repo ไม่ได้กันอะไร

## ⛔ กฎเหล็ก
1. **ห้ามใช้/ขอ Secret key ของ Supabase** — ใช้แค่ publishable key (เปิดเผยได้): URL `https://oidvrclhnndjnhjfcvyp.supabase.co`, key `sb_publishable_9XOnf5NmpCL9XWkXOiGIeg_rTxfwnrX` อยู่ที่ `NET_CONFIG` ใน index.html
2. **ห้าม replace-all ชื่อตัวแปรทั้งไฟล์** (เคยพังมาแล้วใน v5) — แก้ทีละจุดด้วยสคริปต์ `rep(old, new)` ที่ `assert s.count(old) == 1` (หรือจำนวนที่ตั้งใจ)
3. **ทุกครั้งที่ส่งงาน เพิ่ม `GAME_VERSION` ทีละ 1** (แท็บที่เปิดค้างจะขึ้นป้ายมีเวอร์ชันใหม่)
4. **SQL ที่ต้องรัน** ให้ใส่เป็นกล่องโค้ดในแชท + บอกชัดว่า "ต้องรัน" หรือ "ไม่ต้องรัน" + วิธีรัน (Supabase → SQL Editor → New query → วางทั้งกล่อง → Run) และอัปเดตบล็อก `SUPABASE SETUP SQL` ท้าย index.html ด้วย · **ห้ามเปลี่ยน signature ของ RPC ที่ client เก่าเรียกอยู่** (เพิ่มข้อมูลใน JSON แทน)
5. แก้ไอเทม/มอน/ฉายา/ราคา/เควส → ต้องอัปเดต `econ_data()` ด้วย `dev/t/gen_econ.js` + `dev/t/sync_econ.py` (ไม่งั้นเซิร์ฟเวอร์ปฏิเสธเซฟ) แล้วส่ง SQL ให้รัน
6. **ทดสอบก่อนส่งทุกครั้ง** (ด้านล่าง) — `story_test` ต้อง `errors: []` + Playwright ถ่ายภาพจุดที่แก้แล้วดูด้วยตา
7. รางวัลใหม่ที่ไม่ได้มาจากการฆ่ามอน ต้องอยู่ในเพดานของ econ guard (ดู "ข้อจำกัดเซิร์ฟเวอร์") ไม่งั้นเซฟผู้เล่นจะโดนปฏิเสธ

## 🧪 ทดสอบ
```bash
bash dev/setup_work.sh          # สร้าง /tmp/mw (สำเนา offline: NET_CONFIG ว่าง → ไม่ต้องล็อกอิน) + เปิดเซิร์ฟเวอร์ localhost:8765
cd /tmp/mw/t && node story_test.js          # เล่นเนื้อเรื่องหลัก 54 เควสจนจบ → ต้องได้ errors: []
node music_test.js                          # เพลง/เสียง
cd /tmp/mw && NODE_PATH=$(npm root -g) node t/secret_test.js     # จุดลับ (Playwright)
W=sword NODE_PATH=$(npm root -g) node t/tut_e2e.js               # ลานฝึกด้วยเมาส์/คีย์จริง (W=sword|heavy|bow|orb) ภาพที่ t/tut/
```
- **รัน `setup_work.sh` ใหม่ทุกครั้งหลังแก้ index.html ใน repo** (มันก๊อปไฟล์ล่าสุดไปทำสำเนา offline)
- Playwright: `npm i -g playwright` + `npx playwright install chromium` ถ้ายังไม่มี · สคริปต์ Playwright อ้าง `http://localhost:8765/index.html`
- `dev/t/harness.js` = DOM ปลอมสำหรับ Node (`loadGame("game.html")`, `g.run(src)`, `g.get(expr)`, `g.clock.advance(ms)`, `g.errors()`) — ไม่มี setTimeout/fetch/WebSocket, canvas mock ไม่มี `getTransform` (โค้ดต้องมี fallback)
- ตอนเปิดหน้าต่างคุย NPC ในเทสต์ ต้องย้ายตัวละครไปใกล้ NPC ก่อน (เดินห่าง = ปิดเอง) · หน้าต่างสรุปผล/ป้ายต่างๆ อาจบังภาพ
- เซิร์ฟเวอร์: `dev/sql/setup.sql` คือ SQL เต็ม (สำเนาเดียวกับบล็อกท้าย index.html) · `story_db_test.js`/econ tests ต้องมี Postgres ในเครื่อง (ถ้าไม่มี ข้ามได้ แต่ต้องคิดเพดาน econ ด้วยมือ)
- เครื่องมืออื่นที่ **อยู่ใน Cowork Project "Menalars Game" เท่านั้น** (ขอให้ Andy ดาวน์โหลดมาถ้าต้องใช้): `sim.js`/`sim_run.js` (จำลองสมดุลการต่อสู้), `legit_bot.js`/`cheat_test.js` (ทดสอบกันโกงกับ Postgres), `regression_diff.js`, `market_*`, เอกสารสถานะเก่า (v8–v50), `main-quest-design.md`, `art-prompts-v1.md`

## 🗂️ โครงสร้างโค้ด (ค้นด้วยชื่อ — ไฟล์ ~17,600 บรรทัด)
- ค่าคงที่/ระบบเรียงเป็นหมวดมีหัวคอมเมนต์ `/* ==== ... ==== */` · คอมเมนต์บอกเหตุผลแทบทุกจุด — **ยึดโค้ดจริงเป็นหลัก**
- เซฟ: `buildSaveData()` / `continueGame()` / `SAVE_GAME_FIELDS` (field บน `game` ที่เซฟ) · offline = localStorage, online = RPC `save_game`
- แมพ: `warpToMap(tier, dim)`, `TOWN_TIER`, `MAP_TIER_COUNT = 10`, มิติ `game.dimension` (`DIM_RULES` กฎหลอมรวม) · state แมพในเซสชัน `game.mapStates`
- ต่อสู้: `enterBattle` / `updateBattle` / `battleAttack` / `exitBattle(result)` · ท่าบอส (v62) `BOSS_MOVES` / `startBossComboHit` · เกจ Perfect `getPerfectZoneStart` · สติ `drainSanity`, `SANITY_*` · พรพระ `p.monkBuff` (`monkBuffActive`)
- หน้าต่างคุยทุกอย่าง: `openTalk({ npcKind | emoji, name, role, bg, text, extra, choices, anchor })` — `**คำ**` = ตัวทอง, `\n` ขึ้นบรรทัด
- จุดลับ (v60): `SECRET_LOCATION_DEFS` 13 defs (จุดจดหมาย 2 แบบใช้ช่องเดียว → 12 แบบ), สุ่ม 5 จุด/แมพ `generateRandomSecretLocations`, บันทึกลงเซฟ `game.secretSaved` ผ่าน `secretSpotsFor`, ตัวจัดการ `interactWithLocation` / `secretSpotInteract`, มิมิก `m.mimic` → `mimicWon`
- เนื้อเรื่องหลัก 10 บท `STORY_QUESTS` (54 เควส), จดหมาย 60 ฉบับ `LETTER_DEFS` (L60 = จดหมายสายลับ มีรหัสลับคำแรกของบรรทัด ห้ามแก้), ฉายา `TITLE_DEFS`
- ลานฝึก (tutorial) `TUT`, `tutBuildSteps`, `tutFrame` (ลูกศรชี้ใช้ getBoundingClientRect หาร zoom)
- เสียง: `AUDIO` (บรรทัดเดียว), `sfx.*`, `playJingle` (`JINGLE_MAX_S` ตัดเพลงชนะ 3 วิ), `SFX_FILE_GAIN` · v63: ระหว่าง jingle เพลงเงียบ + เสียงรางวัลเข้าคิว (`sfxHoldBegin`, `SFX_AFTER_JINGLE`)
- ชื่อบนหัว (v61): ทุก `fillText/strokeText` ของ world ctx ระหว่าง `renderOverworld()` ถูกวาดซ้ำที่ `#labelCanvas` ความละเอียดจอจริง (`labelFlush`) — แคนวาสโลกสูง 720 แล้วยืด
- UI zoom: `document.body.style.zoom = UI_ZOOM` (จอใหญ่เมนูโต) — ระวังเวลาคำนวณตำแหน่ง DOM
- ชื่อคล้ายกัน: "สมาธิ" (สเตตัส MEDITATE) / "สติ" (sanity) / "ทำสมาธิ" (โหมด) / "เจตจำนง" (STR + สีออร่า) · ใช้ "แต้มสเตตัส" (ไม่ใช่ "แต้มสถานะ"), "แมพ" (ไม่ใช่ "แผนที่"), "ตั้งค่า", "ติดตัว" (passive), "แถบสกิล"
- TDZ: `const` ที่ประกาศทีหลังใช้ในโค้ดที่รันตอนโหลดไม่ได้

## 🌐 ออนไลน์ & กันโกง (econ guard)
- ไม่มี SDK: fetch (Auth REST + PostgREST RPC) + WebSocket Realtime · ล็อกอิน อีเมล/Google/Guest · redirect ใช้ `location.origin + location.pathname`
- ทุก autosave ผ่าน `save_game` → `econ_check(old, new)` เทียบกับเซฟก่อนหน้า: รายได้/ของใหม่ต้องผูกกับการฆ่า, ตัวนับจำกัดตามเวลา · `econ_data()` = ตารางค่าจากเกม (อยู่ระหว่าง `-- ECON_DATA_BEGIN/END`)
- **ข้อจำกัดเซิร์ฟเวอร์ที่ต้องจำเวลาเพิ่มรางวัล** (ต่อ 1 เซฟ ไม่นับการฆ่า): EXP ตัวละคร ~+80 · EXP อาวุธ +800 · เงิน +120 (+50 ต่อ `stats.chestsOpened`, +60 ต่อจดหมาย) · `chestsOpened` ≤ การฆ่า+1 · `stats.secrets` ≤ 5 + เวลา/10วิ · ของใหม่ 3 ชิ้น + 1 ต่อจุดลับ/หีบ/จดหมาย · อุปกรณ์ใหม่ ≤ 3/การฆ่า (+จุดลับ/จดหมาย)
- บังคับอัปเดต: `update public.app_config set value = <GAME_VERSION> where key = 'min_version';` (ใช้เมื่อแก้ SQL/ช่องโหว่เท่านั้น)
- GM: ตาราง `public.admins`, ปุ่ม 🛡️ GM · `window.debug.*` ใช้ได้เฉพาะ GM ในออนไลน์ (offline ใช้ได้เสมอ)
- ล้างเซิร์ฟวันเปิดจริง (เก็บ GM): ลบ `saves`, `item_registry`, `auth.users` ที่ไม่ใช่ admins (ตรวจตารางใหม่ๆ ก่อนรัน)

## 🎨 assets
- รูป: `python3 tools/add_art.py <key> <ไฟล์>` (รันใน /tmp/mw → เขียน assets/ + บรรทัด `ART` ใน /tmp/mw/index.html → `bash dev/deliver.sh`)
- เสียง: `python3 tools/add_audio.py <bgm_|jgl_|sfx_key> <ไฟล์> ["ชื่อ"]` (ffmpeg ตัดเงียบ + loudnorm → assets/*.mp3 + บรรทัด `AUDIO`) แล้ว `dev/deliver.sh`
- เคยสร้างเพลงด้วย Gemini (Lyria), SFX ด้วย ElevenLabs, รูปมอน/ฉากด้วย Gemini — Andy ต้องเป็นคนกดในบัญชีตัวเอง
- เมื่อเพิ่มไฟล์ใน assets/ ต้องบอก Andy ว่ามีไฟล์ใหม่ (เขาเคยอัปโหลดไม่ครบ)

## 📝 ข้อความในเกม (text pipeline)
- ส่งออกข้อความทั้งเกมให้ AI อื่นแก้สำนวน: `cd /tmp/mw/t && node ../tools/dump_text_data.js && cd .. && python3 tools/text_scan.py && python3 tools/build_text_export.py` → `/tmp/mw/text_export/` (01–05 .txt + `_map.json`)
- ตรวจไฟล์ที่แก้กลับมา: `MAP=text_export/_map.json python3 tools/check_revised.py <ไฟล์>` (เช็กตัวหนา/ตัวเลข/{…}/อีโมจิ/บรรทัด/แท็ก/ความยาว) → ใส่ด้วย `tools/apply_text.py` (SRC.* ต้องแก้มือ, {ชื่อ} → `${…}`) → `dev/deliver.sh`
- งานแก้ข้อความไฟล์ 01–05 **เสร็จครบแล้ว** (v54–v59)

## 🗺️ ยังไม่ได้ทำ / ข้อสังเกต
- มอนธรรมดาแทบไม่ได้ตีผู้เล่น (ไฟต์สั้น), ค้อน DPS ต่ำกว่าอาวุธอื่น ~15%, วงกลมสื่อเวทย์ยาก, คริเพดาน 85% จากเลเวล, ยังไม่รัน sim รวมโบนัสฉายา
- บอสโลก (มิติสูง), ปุ่มใช้ยา/สมุนไพร (ตอนนี้ขายได้อย่างเดียว), Realtime private channels, CAPTCHA สำหรับ Guest, SMTP ของตัวเองก่อนเปิดจริง
- เพลงชนะบอส/แพ้ ยังยาวเต็มเพลง (ถ้า Andy อยากตัด ใช้ `JINGLE_MAX_S`)
