"""Render the stylized, painterly overland map of Harvard, Mass. from OSM + terrain data.

Outputs (into ../../game/assets/map/):
  overland.png      painted map
  overland_mask.png collision/terrain mask (R=water, G=road, B=outside town)
  overland.json     projection + landmark pixel positions
"""
import glob
import json
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "game", "assets", "map")
FONTS = os.path.join(HERE, "..", "fonts")
os.makedirs(OUT, exist_ok=True)

LON0, LON1, LAT0, LAT1 = -71.652, -71.518, 42.438, 42.566
W = 3200
KX = W / ((LON1 - LON0) * math.cos(math.radians(42.5)))
H = int((LAT1 - LAT0) * KX)
random.seed(1995)
np.random.seed(1995)


def proj(lon, lat):
    return ((lon - LON0) * math.cos(math.radians(42.5)) * KX, (LAT1 - lat) * KX)


osm = json.load(open(os.path.join(HERE, "osm.json")))


def tag(e, k):
    return e.get("tags", {}).get(k)


def way_pts(geom):
    return [proj(p["lon"], p["lat"]) for p in geom]


def rings(e):
    """Return list of (outer?, pts) rings for ways and multipolygon relations."""
    if e["type"] == "way" and "geometry" in e:
        return [(True, way_pts(e["geometry"]))]
    out = []
    if e["type"] == "relation":
        # stitch member ways into rings
        segs = {"outer": [], "inner": []}
        for m in e.get("members", []):
            if "geometry" in m and m.get("role") in segs:
                segs[m["role"]].append([(p["lon"], p["lat"]) for p in m["geometry"]])
        for role, ss in segs.items():
            for ring in stitch(ss):
                out.append((role == "outer", [proj(*p) for p in ring]))
    return out


def stitch(segs):
    segs = [list(s) for s in segs if len(s) > 1]
    result = []
    while segs:
        cur = segs.pop(0)
        changed = True
        while changed and cur[0] != cur[-1]:
            changed = False
            for i, s in enumerate(segs):
                if s[0] == cur[-1]:
                    cur += s[1:]
                elif s[-1] == cur[-1]:
                    cur += s[::-1][1:]
                elif s[-1] == cur[0]:
                    cur = s[:-1] + cur
                elif s[0] == cur[0]:
                    cur = s[::-1][:-1] + cur
                else:
                    continue
                segs.pop(i)
                changed = True
                break
        result.append(cur)
    return result


def poly_mask(elems, scale=1.0):
    m = Image.new("L", (int(W * scale), int(H * scale)), 0)
    d = ImageDraw.Draw(m)
    for e in elems:
        rs = rings(e)
        for outer, pts in rs:
            if len(pts) > 2 and outer:
                d.polygon([(x * scale, y * scale) for x, y in pts], fill=255)
        for outer, pts in rs:
            if len(pts) > 2 and not outer:
                d.polygon([(x * scale, y * scale) for x, y in pts], fill=0)
    return m


def select(pred):
    return [e for e in osm["elements"] if pred(e)]


# ---------------------------------------------------------------- terrain
def load_dem():
    z = 13
    tiles = {}
    for f in glob.glob(os.path.join(HERE, "dem", "*.png")):
        x, y = map(int, os.path.basename(f)[:-4].split("_"))
        tiles[(x, y)] = np.asarray(Image.open(f).convert("RGB")).astype(np.float32)
    xs = sorted({k[0] for k in tiles}); ys = sorted({k[1] for k in tiles})
    big = np.zeros((len(ys) * 256, len(xs) * 256), np.float32)
    for (x, y), a in tiles.items():
        h = a[..., 0] * 256 + a[..., 1] + a[..., 2] / 256 - 32768
        big[(y - ys[0]) * 256:(y - ys[0] + 1) * 256, (x - xs[0]) * 256:(x - xs[0] + 1) * 256] = h
    n = 2 ** z
    # sample per output pixel (at quarter res for speed, upsample later)
    s = 4
    gx = np.arange(0, W, s); gy = np.arange(0, H, s)
    lon = LON0 + gx / (KX * math.cos(math.radians(42.5)))
    lat = LAT1 - gy / KX
    px = ((lon + 180) / 360 * n - xs[0]) * 256
    py = ((1 - np.arcsinh(np.tan(np.radians(lat))) / math.pi) / 2 * n - ys[0]) * 256
    PX, PY = np.meshgrid(px, py)
    elev = big[np.clip(PY.astype(int), 0, big.shape[0] - 1), np.clip(PX.astype(int), 0, big.shape[1] - 1)]
    from scipy.ndimage import gaussian_filter
    img = np.asarray(Image.fromarray(elev.astype(np.float32)).resize((W, H), Image.BICUBIC))
    return gaussian_filter(img, 3)


print("terrain…")
elev = load_dem()
gy, gx = np.gradient(elev)
mpp = 1 / KX * 111000  # meters per pixel
slope_x, slope_y = gx / mpp, gy / mpp
# light from northwest, exaggerated for a painted look
shade = np.clip(0.62 + (-slope_x * 0.9 - slope_y * 0.9) * 2.2, 0.25, 1.25)
emin, emax = np.percentile(elev, 2), np.percentile(elev, 98)
height01 = np.clip((elev - emin) / (emax - emin), 0, 1)


def noise(scale, octaves=3, seed=0):
    rng = np.random.default_rng(seed)
    acc = np.zeros((H, W), np.float32)
    amp = 1.0
    for o in range(octaves):
        sw, sh = max(2, int(W / scale)), max(2, int(H / scale))
        n = rng.random((sh, sw)).astype(np.float32)
        acc += np.asarray(Image.fromarray(n).resize((W, H), Image.BICUBIC)) * amp
        scale /= 2.3; amp *= 0.5
    return acc / acc.max()


print("noise…")
n_big = noise(220, 4, 1)
n_small = noise(28, 2, 2)

# ---------------------------------------------------------------- masks
print("masks…")
water_e = select(lambda e: tag(e, "natural") == "water" or tag(e, "landuse") == "reservoir")
wet_e = select(lambda e: tag(e, "natural") == "wetland")
field_e = select(lambda e: tag(e, "landuse") in ("farmland", "meadow", "grass") or tag(e, "leisure") in ("golf_course", "park"))
orchard_e = select(lambda e: tag(e, "landuse") == "orchard")
cem_e = select(lambda e: tag(e, "landuse") == "cemetery")
res_e = select(lambda e: tag(e, "landuse") == "residential")
mil_e = select(lambda e: tag(e, "landuse") == "military")
town_e = select(lambda e: tag(e, "boundary") == "administrative")

water = np.asarray(poly_mask(water_e)) > 0
wet = np.asarray(poly_mask(wet_e)) > 0
field = np.asarray(poly_mask(field_e)) > 0
orch = np.asarray(poly_mask(orchard_e)) > 0
cem = np.asarray(poly_mask(cem_e)) > 0
resid = np.asarray(poly_mask(res_e)) > 0
mil = np.asarray(poly_mask(mil_e)) > 0
town = np.asarray(poly_mask(town_e)) > 0

# Roads drawn into a mask (also used for "cleared" land along roads: houses/yards)
roads = [e for e in osm["elements"] if e["type"] == "way" and tag(e, "highway") and "geometry" in e]
RW = {"motorway": 13, "motorway_link": 6, "trunk": 11, "primary": 9, "secondary": 8, "secondary_link": 5,
      "tertiary": 7, "tertiary_link": 5, "unclassified": 5, "residential": 4.5, "track": 2.5}
clear_img = Image.new("L", (W, H), 0)
cd = ImageDraw.Draw(clear_img)
for e in roads:
    hw = tag(e, "highway")
    if hw in ("motorway", "motorway_link", "track"):
        continue
    pts = way_pts(e["geometry"])
    cd.line(pts, fill=255, width=int(RW.get(hw, 4) * 7))
clear_img = clear_img.filter(ImageFilter.GaussianBlur(22))
cleared = (np.asarray(clear_img) / 255.0) * (0.45 + 0.5 * n_big + 0.35 * n_small) > 0.55

# ---------------------------------------------------------------- base paint
print("paint…")
# autumn lowland grass to upland brown
low = np.array([150, 150, 86], np.float32)
high = np.array([168, 132, 82], np.float32)
base = low[None, None] * (1 - height01[..., None]) + high[None, None] * height01[..., None]
base += ((n_big - 0.5) * 40)[..., None] * np.array([1.0, 0.8, 0.4])
fieldcol = np.array([196, 176, 98], np.float32) + ((n_small - .5) * 30)[..., None]
img = base.copy()
open_land = field | resid | cem | cleared
img[open_land] = img[open_land] * 0.35 + fieldcol[open_land] * 0.65
img[orch] = np.array([150, 160, 84], np.float32)
img[cem] = np.array([128, 146, 92], np.float32)
img[mil & ~open_land] = img[mil & ~open_land] * 0.9
img[wet] = np.array([122, 120, 72], np.float32) + ((n_small[wet] - .5) * 30)[..., None]
img = img * shade[..., None]

canvas = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).convert("RGBA")

# ---------------------------------------------------------------- trees
print("trees…")
forest = ~(open_land | water | wet | orch)
forest_small = Image.fromarray((forest * 255).astype(np.uint8))
tree_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
shadow_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
td = ImageDraw.Draw(tree_layer)
sd = ImageDraw.Draw(shadow_layer)
palette = [(196, 72, 34), (222, 112, 40), (232, 164, 52), (176, 46, 36), (120, 110, 48), (58, 82, 52),
           (44, 70, 46), (206, 136, 44), (150, 60, 40), (90, 100, 50)]
weights = [10, 12, 9, 6, 6, 9, 8, 8, 5, 6]
step = 12
stand = noise(160, 3, 7)
conifer = noise(90, 2, 9)
maple = [(190, 70, 36), (214, 104, 42), (226, 150, 54), (168, 52, 38), (200, 124, 48)]
oak = [(150, 96, 52), (128, 84, 46), (170, 120, 60), (110, 92, 50)]
pine = [(52, 76, 50), (44, 66, 46), (64, 88, 56)]
birch = [(214, 176, 70), (230, 196, 90)]
pts = []
for y in range(0, H, step):
    for x in range(0, W, step):
        jx = x + random.randint(-6, 6); jy = y + random.randint(-6, 6)
        if 0 <= jx < W and 0 <= jy < H and forest[jy, jx]:
            pts.append((jy, jx))
pts.sort()
for jy, jx in pts:
    st = stand[jy, jx]
    if conifer[jy, jx] > 0.62 or random.random() < 0.12:
        pal = pine
    elif st < 0.38:
        pal = oak
    elif st > 0.72:
        pal = birch if random.random() < 0.5 else maple
    else:
        pal = maple
    c = random.choice(pal)
    s_ = shade[jy, jx]
    k = 0.6 + 0.45 * s_
    c2 = tuple(int(min(255, ch * k)) for ch in c)
    dark = tuple(int(ch * 0.62) for ch in c2)
    hl = tuple(min(255, int(ch * 1.22 + 10)) for ch in c2)
    r = random.randint(8, 12)
    sd.ellipse((jx - r + 6, jy - r + 7, jx + r + 6, jy + r + 7), fill=(28, 24, 18, 110))
    td.ellipse((jx - r, jy - r, jx + r, jy + r), fill=dark + (255,))
    td.ellipse((jx - r + 1, jy - r, jx + r - 2, jy + r - 3), fill=c2 + (255,))
    td.ellipse((jx - r + 3, jy - r + 2, jx + 1, jy - 1), fill=hl + (220,))
# orchard rows
for y in range(0, H, 14):
    for x in range(0, W, 14):
        if orch[y, x]:
            sd.ellipse((x - 3, y - 2, x + 9, y + 9), fill=(30, 26, 20, 80))
            c = random.choice([(96, 128, 52), (112, 140, 58), (150, 140, 52)])
            td.ellipse((x - 5, y - 5, x + 5, y + 5), fill=c + (255,))
            if random.random() < 0.4:
                td.ellipse((x - 1, y - 2, x + 2, y + 1), fill=(200, 40, 30, 255))
# a few lone trees on open land and along stone walls
for _ in range(9000):
    x = random.randrange(W); y = random.randrange(H)
    if open_land[y, x] and not water[y, x]:
        r = random.randint(5, 9)
        c = random.choices(palette, weights)[0]
        sd.ellipse((x - r + 4, y - r + 5, x + r + 4, y + r + 5), fill=(30, 26, 20, 80))
        td.ellipse((x - r, y - r, x + r, y + r), fill=c + (255,))
shadow_layer = shadow_layer.filter(ImageFilter.GaussianBlur(2))
canvas = Image.alpha_composite(canvas, shadow_layer)

# ---------------------------------------------------------------- water
print("water…")
wm = Image.fromarray((water * 255).astype(np.uint8))
edge = np.asarray(wm.filter(ImageFilter.GaussianBlur(4))) > 20
shore = edge & ~water
deep = np.asarray(wm.filter(ImageFilter.GaussianBlur(8))) > 235
wcol = np.zeros((H, W, 4), np.uint8)
wcol[water] = (64, 104, 128, 255)
wcol[deep] = (44, 78, 108, 255)
wcol[shore] = (110, 96, 66, 255)
wimg = Image.fromarray(wcol)
gd = ImageDraw.Draw(canvas)
# rivers and streams
for e in select(lambda e: tag(e, "waterway") in ("river", "stream") and "geometry" in e):
    w = 9 if tag(e, "waterway") == "river" else 3
    pts = way_pts(e["geometry"])
    gd.line(pts, fill=(110, 96, 66, 255), width=w + 4, joint="curve")
    gd.line(pts, fill=(60, 100, 126, 255), width=w, joint="curve")

canvas = Image.alpha_composite(canvas, wimg)
# glints
gd = ImageDraw.Draw(canvas)
for _ in range(5000):
    x = random.randrange(W); y = random.randrange(H)
    if deep[y, x]:
        L = random.randint(6, 16)
        gd.line((x, y, x + L, y), fill=(140, 176, 196, 160), width=2)
canvas = Image.alpha_composite(canvas, tree_layer)
gd = ImageDraw.Draw(canvas)
for e in select(lambda e: tag(e, "waterway") in ("river", "stream") and "geometry" in e):
    w = 12 if tag(e, "waterway") == "river" else 3
    pts = way_pts(e["geometry"])
    gd.line(pts, fill=(96, 84, 58, 255), width=w + 5, joint="curve")
    gd.line(pts, fill=(64, 104, 130, 255), width=w, joint="curve")
water_lines = Image.new("L", (W, H), 0)
ImageDraw.Draw(water_lines)

# ---------------------------------------------------------------- roads
print("roads…")
order = ["track", "residential", "unclassified", "tertiary_link", "tertiary", "secondary_link", "secondary",
         "primary", "trunk", "motorway_link", "motorway"]
road_mask = Image.new("L", (W, H), 0)
rmd = ImageDraw.Draw(road_mask)
rd = ImageDraw.Draw(canvas)
for pass_ in (0, 1):
    for hw in order:
        for e in roads:
            if tag(e, "highway") != hw:
                continue
            pts = way_pts(e["geometry"])
            w = RW.get(hw, 4)
            if hw == "track":
                if pass_ == 1:
                    for i in range(0, len(pts) - 1, 2):
                        rd.line(pts[i:i + 2], fill=(110, 80, 50, 200), width=2)
                continue
            if pass_ == 0:
                rd.line(pts, fill=(70, 52, 36, 255), width=int(w + 5), joint="curve")
                for p in pts:
                    rd.ellipse((p[0] - (w + 5) / 2, p[1] - (w + 5) / 2, p[0] + (w + 5) / 2, p[1] + (w + 5) / 2), fill=(70, 52, 36, 255))
            else:
                col = (226, 210, 168, 255) if hw not in ("motorway", "motorway_link", "trunk") else (150, 146, 140, 255)
                rd.line(pts, fill=col, width=int(w), joint="curve")
                for p in pts:
                    rd.ellipse((p[0] - w / 2, p[1] - w / 2, p[0] + w / 2, p[1] + w / 2), fill=col)
                rmd.line(pts, fill=255, width=int(w + 8), joint="curve")
# railway
for e in select(lambda e: tag(e, "railway") == "rail" and "geometry" in e):
    pts = way_pts(e["geometry"])
    rd.line(pts, fill=(60, 50, 44, 255), width=4)
    for i, p in enumerate(pts):
        if i % 2 == 0:
            rd.line((p[0] - 3, p[1] - 3, p[0] + 3, p[1] + 3), fill=(60, 50, 44, 255), width=2)

# ---------------------------------------------------------------- brush texture
print("texture…")
arr = np.asarray(canvas).astype(np.float32)
grain = (np.random.default_rng(3).random((H, W)) - 0.5) * 14
arr[..., :3] += grain[..., None]
arr[..., :3] *= (0.94 + 0.12 * n_small)[..., None]

# outside town: misty, desaturated, darker
out = ~town
gray = arr[..., :3].mean(axis=2, keepdims=True)
fog = np.array([118, 112, 120], np.float32)
fo = out & ~water
arr[fo, :3] = arr[fo, :3] * 0.45 + gray[fo] * 0.25 + fog * 0.3
canvas = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))

# town line: dotted, like an old survey map
bd = ImageDraw.Draw(canvas)
for e in town_e:
    for outer, pts in rings(e):
        for i in range(0, len(pts) - 1):
            a, b = pts[i], pts[i + 1]
            L = math.dist(a, b)
            nseg = max(1, int(L / 14))
            for k in range(nseg):
                if k % 2:
                    continue
                t0, t1 = k / nseg, min(1, (k + 0.6) / nseg)
                bd.line((a[0] + (b[0] - a[0]) * t0, a[1] + (b[1] - a[1]) * t0,
                         a[0] + (b[0] - a[0]) * t1, a[1] + (b[1] - a[1]) * t1), fill=(90, 30, 30), width=5)

# ---------------------------------------------------------------- labels
print("labels…")
fsc = os.path.join(FONTS, "IMFellEnglishSC-Regular.ttf")
fit = os.path.join(FONTS, "IMFellEnglish-Italic.ttf")


def label(text, lon, lat, size, font=fsc, fill=(54, 36, 24), spacing=0.18, angle=0, glow=(236, 222, 186)):
    f = ImageFont.truetype(font, size)
    txt = " ".join(text) if spacing else text
    bbox = f.getbbox(txt)
    tw, th = bbox[2] - bbox[0] + 40, bbox[3] - bbox[1] + 40
    layer = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    ld.text((20 - bbox[0], 20 - bbox[1]), txt, font=f, fill=fill, stroke_width=max(2, size // 12), stroke_fill=glow + (230,))
    if angle:
        layer = layer.rotate(angle, expand=True, resample=Image.BICUBIC)
    x, y = proj(lon, lat)
    canvas.paste(layer, (int(x - layer.width / 2), int(y - layer.height / 2)), layer)


label("HARVARD", -71.578, 42.4925, 64)
label("Still River", -71.6195, 42.4800, 46, fit, spacing=0)
label("Shaker Village", -71.5505, 42.5395, 40, fit, spacing=0)
label("Bare Hill Pond", -71.5930, 42.4860, 38, fit, spacing=0, fill=(30, 48, 70))
label("FORT DEVLIN", -71.6150, 42.5560, 46, fill=(70, 50, 40))
label("— restricted —", -71.6150, 42.5512, 26, fit, spacing=0, fill=(110, 40, 30))
label("Nashua River", -71.6420, 42.5050, 30, fit, spacing=0, fill=(30, 48, 70), angle=72)
label("Oxbow", -71.6330, 42.4880, 30, fit, spacing=0, fill=(50, 60, 40))
label("Prospect Hill", -71.6080, 42.5140, 28, fit, spacing=0)
label("Oak Hill", -71.5470, 42.5180, 28, fit, spacing=0)
label("Pin Hill", -71.5690, 42.4705, 26, fit, spacing=0)
label("Bolton", -71.6000, 42.4440, 34, fit, spacing=0, fill=(80, 76, 84), glow=(170, 166, 176))
label("Ayer", -71.5850, 42.5620, 34, fit, spacing=0, fill=(80, 76, 84), glow=(170, 166, 176))
label("Boxborough", -71.5300, 42.4870, 30, fit, spacing=0, fill=(80, 76, 84), glow=(170, 166, 176), angle=90)
label("Lancaster", -71.6440, 42.4560, 30, fit, spacing=0, fill=(80, 76, 84), glow=(170, 166, 176))
label("Route 2", -71.5380, 42.5465, 24, fit, spacing=0, fill=(60, 60, 64))

# compass rose
cx, cy = W - 230, H - 260
cdraw = ImageDraw.Draw(canvas)
cdraw.ellipse((cx - 90, cy - 90, cx + 90, cy + 90), outline=(70, 50, 36), width=4)
cdraw.polygon([(cx, cy - 120), (cx - 18, cy), (cx + 18, cy)], fill=(120, 40, 30))
cdraw.polygon([(cx, cy + 120), (cx - 18, cy), (cx + 18, cy)], fill=(70, 50, 36))
cdraw.polygon([(cx - 120, cy), (cx, cy - 14), (cx, cy + 14)], fill=(70, 50, 36))
cdraw.polygon([(cx + 120, cy), (cx, cy - 14), (cx, cy + 14)], fill=(70, 50, 36))
cdraw.text((cx - 12, cy - 175), "N", font=ImageFont.truetype(fsc, 44), fill=(70, 50, 36))
cdraw.text((W - 540, H - 110), "Harvard, Mass.  ·  autumn 1995", font=ImageFont.truetype(fit, 34), fill=(60, 44, 32))

# vignette
v = np.ones((H, W), np.float32)
yy, xx = np.mgrid[0:H, 0:W]
d = np.sqrt(((xx - W / 2) / (W / 2)) ** 2 + ((yy - H / 2) / (H / 2)) ** 2)
v = np.clip(1.15 - 0.35 * d ** 2, 0.55, 1)
arr = np.asarray(canvas.convert("RGB")).astype(np.float32) * v[..., None]
final = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
final.save(os.path.join(OUT, "overland.png"), optimize=True)
final.resize((W // 4, H // 4)).save(os.path.join(HERE, "preview.jpg"), quality=85)

# ---------------------------------------------------------------- mask + json
rm = np.asarray(road_mask) > 0
mask = np.zeros((H, W, 3), np.uint8)
mask[..., 0] = water * 255
mask[..., 1] = rm * 255
mask[..., 2] = (~town) * 255
Image.fromarray(mask).resize((W // 4, H // 4), Image.NEAREST).save(os.path.join(OUT, "overland_mask.png"))

LANDMARKS = {
    "dillard_farm": (-71.5655, 42.5072),
    "common": (-71.5839, 42.5005),
    "lovers_lane": (-71.5890, 42.5016),
    "bellview": (-71.6048, 42.4950),
    "barehill_beach": (-71.5999, 42.4797),
    "fruitvale": (-71.6111, 42.5072),
    "fort_devlin": (-71.6040, 42.5420),
    "mirror_lake": (-71.6129, 42.5260),
    "observatory": (-71.5576, 42.5054),
    "shaker_village": (-71.5543, 42.5359),
    "abbey": (-71.6211, 42.4869),
    "oxbow": (-71.6254, 42.4969),
    "poor_farm": (-71.5678, 42.5229),
    "carrow_orchard": (-71.5530, 42.5110),
    "cleaves_hill": (-71.5567, 42.5017),
}
json.dump({
    "size": [W, H], "mask_scale": 4,
    "landmarks": {k: [round(c, 1) for c in proj(*v)] for k, v in LANDMARKS.items()},
}, open(os.path.join(OUT, "overland.json"), "w"), indent=1)
print("done", W, H)
