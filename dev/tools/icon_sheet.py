# usage: python3 icon_sheet.py <sheet.jpg> <out_dir> key1 key2 ... key16   (use "-" to skip a cell)
# Cuts a Gemini 4×4 icon sheet (plain white background) into 16 transparent square icons:
# removes the white that touches each cell's border (flood fill, soft edge), crops to the icon,
# pads to a square and saves <out_dir>/<key>.png at 256×256.
import sys, os
import numpy as np
from PIL import Image
from scipy import ndimage

SIZE = 256
sheet, out_dir, keys = sys.argv[1], sys.argv[2], sys.argv[3:]
assert len(keys) == 16, "need 16 keys (use - to skip)"
os.makedirs(out_dir, exist_ok=True)
im = Image.open(sheet).convert("RGB")
W, H = im.size
cw, ch = W / 4, H / 4
for idx, key in enumerate(keys):
    if key == "-": continue
    r, c = divmod(idx, 4)
    ins = float(os.environ.get("INSET", "0")) * cw   # INSET=0.02 trims grid lines Gemini sometimes draws between cells
    cell = im.crop((round(c * cw + ins), round(r * ch + ins), round((c + 1) * cw - ins), round((r + 1) * ch - ins)))
    a = np.asarray(cell).astype(np.int16)
    mn, mx = a.min(axis=2), a.max(axis=2)
    whiteish = (mn > 218) & (mx - mn < 30)
    lab, _ = ndimage.label(whiteish)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = ndimage.binary_opening(np.isin(lab, list(edge)), iterations=1, border_value=1)
    dist = ndimage.distance_transform_edt(~bg)
    alpha = np.clip(dist / 2.0, 0, 1)
    light = np.clip((mn - 180) / 60.0, 0, 1)
    alpha = np.where(dist < 3, alpha * (1 - 0.7 * light), alpha)
    # keep only the biggest blobs (drops stray sparkles from the neighbour cell at the edges)
    fg = alpha > 0.05
    lab2, n2 = ndimage.label(fg)
    if n2 > 1:
        sizes = ndimage.sum(fg, lab2, range(1, n2 + 1))
        keep = [i + 1 for i, s in enumerate(sizes) if s >= sizes.max() * 0.02]
        alpha = np.where(np.isin(lab2, keep), alpha, 0)
    # glow halos painted onto the white (flames, golden light): turn "whiteness" into transparency
    # near the background (colour-to-alpha), so the halo stays coloured instead of a pale sticker edge
    rgb = a.astype(np.float32)
    ca = np.clip((255 - rgb).max(axis=2) / 255 * 1.6, 0, 1)
    # halo = light pixels OUTSIDE the ink outline: reachable from the background without crossing dark ink
    passable = (mn > 110) | bg
    lab3, _ = ndimage.label(passable)
    outside = np.isin(lab3, np.unique(lab3[bg])) & (lab3 > 0)
    halo = outside & ~bg & (dist < 40)
    alpha = np.where(halo, np.minimum(alpha, np.maximum(ca, np.clip((dist - 18) / 10, 0, 1))), alpha)
    safe = np.maximum(alpha, 1e-3)[..., None]
    rgb = np.where(halo[..., None], np.clip((rgb - (1 - alpha[..., None]) * 255) / safe, 0, 255), rgb)
    a = rgb.astype(np.int16)
    rgba = Image.fromarray(np.dstack([a.astype(np.uint8), (alpha * 255).astype(np.uint8)]), "RGBA")
    ys, xs = np.where(alpha > 0.05)
    box = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
    icon = rgba.crop(box)
    side = int(max(icon.size) * 1.06)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.paste(icon, ((side - icon.width) // 2, (side - icon.height) // 2))
    sq.resize((SIZE, SIZE), Image.LANCZOS).save(f"{out_dir}/{key}.png")
    print(key, icon.size)
