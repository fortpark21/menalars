# usage: python3 add_art_many.py <prefix> <png files...>   → assets/<prefix><name>.webp + ART lines (one index.html write)
import sys, re, hashlib
from PIL import Image
prefix, files = sys.argv[1], sys.argv[2:]
s = open("index.html", encoding="utf-8").read()
for src in files:
    key = prefix + re.sub(r"\.[^.]+$", "", src.split("/")[-1])
    dst = f"assets/{key}.webp"
    Image.open(src).save(dst, "WEBP", quality=86, method=4)
    h = hashlib.md5(open(dst, "rb").read()).hexdigest()[:8]
    line = f'  {key}: "assets/{key}.webp?v={h}"'
    pat = re.compile(r'^  ' + re.escape(key) + r': "assets/[^"]*"', re.M)
    if pat.search(s): s = pat.sub(line, s, count=1)
    else:
        i = s.index("const ART = {\n") + len("const ART = {\n")
        s = s[:i] + line + ",\n" + s[i:]
open("index.html", "w", encoding="utf-8").write(s)
print(len(files), "images")
