# usage: python3 fish_key.py <in.png> <out.png> [--flip]
# Removes the plain white background that touches the image border (flood fill), feathers the edge,
# crops to the fish and scales to 640 px wide (max 400 tall). --flip mirrors so the fish faces right.
import sys
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

src, dst = sys.argv[1], sys.argv[2]
im = Image.open(src).convert("RGB")
if "--flip" in sys.argv: im = im.transpose(Image.FLIP_LEFT_RIGHT)
a = np.asarray(im).astype(np.int16)
mn, mx = a.min(axis=2), a.max(axis=2)
whiteish = (mn > 222) & (mx - mn < 26)          # near-white, low saturation
lab, _ = ndimage.label(whiteish)
edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
bg = np.isin(lab, list(edge))
bg = ndimage.binary_opening(bg, iterations=1, border_value=1)
# soft alpha: fully transparent inside background, ramp over ~2 px at the border
dist = ndimage.distance_transform_edt(~bg)
alpha = np.clip(dist / 2.0, 0, 1)
# pixels right at the border that are still light get extra transparency (removes white halo)
light = np.clip((mn - 180) / 60.0, 0, 1)
alpha = np.where(dist < 3, alpha * (1 - 0.7 * light), alpha)
rgba = np.dstack([a.astype(np.uint8), (alpha * 255).astype(np.uint8)])
out = Image.fromarray(rgba, "RGBA")
ys, xs = np.where(alpha > 0.05)
pad = 6
box = (max(xs.min() - pad, 0), max(ys.min() - pad, 0), min(xs.max() + pad + 1, a.shape[1]), min(ys.max() + pad + 1, a.shape[0]))
out = out.crop(box)
k = min(640 / out.width, 400 / out.height)
out = out.resize((round(out.width * k), round(out.height * k)), Image.LANCZOS)
out.save(dst)
print(dst, out.size)
