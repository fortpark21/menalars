# usage: python3 add_art.py <key> <image file>   → copies to assets/<key>.webp and adds/updates the ART line in index.html
import sys, re, hashlib, shutil
from PIL import Image
key, src = sys.argv[1], sys.argv[2]
dst = f"assets/{key}.webp"
if src.lower().endswith(".webp"): shutil.copy(src, dst)
else: Image.open(src).save(dst, "WEBP", quality=82, method=6)
h = hashlib.md5(open(dst, "rb").read()).hexdigest()[:8]
s = open("index.html", encoding="utf-8").read()
line = f'  {key}: "assets/{key}.webp?v={h}"'
pat = re.compile(r'^  ' + re.escape(key) + r': "assets/[^"]*"', re.M)
if pat.search(s): s = pat.sub(line, s, count=1)
else:
    i = s.index("const ART = {\n") + len("const ART = {\n")
    s = s[:i] + line + ",\n" + s[i:]
open("index.html", "w", encoding="utf-8").write(s)
print(line)
