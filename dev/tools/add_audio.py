#!/usr/bin/env python3
"""add_audio.py <key> <audio file> ["ชื่อเพลงที่โชว์ในเกม"]

Adds or replaces one sound in the game:
  bgm_*  = music  -> trim silence, loudness -16 LUFS, stereo MP3 128k
  jgl_*  = short music jingle (victory/defeat) -> same as music
  sfx_*  = sound effect -> trim silence, loudness -14 LUFS peak -1 dB, mono MP3 96k
Writes assets/<key>.mp3 and updates the one-line `const AUDIO = {...};` in index.html
(key -> "assets/<key>.mp3?v=<md5 8>"), plus the AUDIO_TITLE line when a title is given.
"""
import sys, os, re, json, hashlib, subprocess

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # /tmp/mw (tools/ lives inside it)
HTML = os.path.join(HERE, "index.html")
ASSETS = os.path.join(HERE, "assets")

def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stderr[-2000:]); sys.exit("ffmpeg failed")
    return r

def main():
    if len(sys.argv) < 3: sys.exit(__doc__)
    key, src = sys.argv[1], sys.argv[2]
    title = sys.argv[3] if len(sys.argv) > 3 else None
    if not re.fullmatch(r"(bgm|jgl|sfx)_[A-Za-z0-9_]+", key): sys.exit("key must look like bgm_xxx / jgl_xxx / sfx_xxx")
    os.makedirs(ASSETS, exist_ok=True)
    out = os.path.join(ASSETS, key + ".mp3")
    trim = ("silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.05,"
            "areverse,silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.25,areverse")
    if key.startswith("sfx_"):
        af = trim + ",loudnorm=I=-14:TP=-1:LRA=11"
        enc = ["-ac", "1", "-ar", "44100", "-b:a", "96k"]
    else:
        af = trim + ",loudnorm=I=-16:TP=-1.5:LRA=11"
        enc = ["-ac", "2", "-ar", "44100", "-b:a", "128k"]
    run(["ffmpeg", "-y", "-hide_banner", "-i", src, "-vn", "-map_metadata", "-1", "-af", af,
         "-c:a", "libmp3lame"] + enc + [out])
    dur = float(run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", out]).stdout.strip())
    md5 = hashlib.md5(open(out, "rb").read()).hexdigest()[:8]

    html = open(HTML, encoding="utf-8").read()
    m = re.search(r"^const AUDIO = (\{.*\});$", html, re.M)
    assert m, "AUDIO line not found"
    audio = json.loads(m.group(1))
    audio[key] = f"assets/{key}.mp3?v={md5}"
    audio = dict(sorted(audio.items()))
    html = html[:m.start(1)] + json.dumps(audio, ensure_ascii=False) + html[m.end(1):]
    if title:
        t = re.search(r"^const AUDIO_TITLE = (\{.*\});$", html, re.M)
        assert t, "AUDIO_TITLE line not found"
        titles = json.loads(t.group(1)); titles[key] = title
        html = html[:t.start(1)] + json.dumps(dict(sorted(titles.items())), ensure_ascii=False) + html[t.end(1):]
    open(HTML, "w", encoding="utf-8").write(html)
    print(f"{key}: {os.path.getsize(out)/1e6:.2f} MB, {dur:.1f}s, v={md5}")

main()
