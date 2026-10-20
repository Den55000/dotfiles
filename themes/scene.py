"""Repaint the starry-night wallpaper (code-editor.jpg) as a different time of day.

The picture is flat, layered art: a sky that is one vertical gradient (plus a
radial vignette and stars) over land silhouettes whose brightness rises with
distance. So it splits cleanly into
    sky   = pixels close to the sky colour of their row,
    land  = everything else, ordered dark (near) -> light (far, lake glow),
and each part is repainted from a scene spec in palettes.json:

    "sky":   [[pos, colour], ...]    top of the picture (0) -> horizon (1)
    "land":  [colour, ...]           darkest land -> brightest land
    "glow":  {x, colour, strength, radius}    light source at the horizon
    "sun":   {x, rise, radius, colour}        disc behind the ridge
    "stars": 0..1                    how much of the original stars to keep
    "haze":  {colour, amount}        far land fades towards this colour
    "mist":  {colour, amount}        band of fog at lake level
    "snow":  {colour, count}         falling flakes
    "clouds": {colour, opacity}      a few soft clouds
    "vignette": true                 keep the original corner darkening
    "sparkles": true                 keep the original fireflies on the land
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

LW = np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)


def rgb(h):
    return np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], dtype=np.float32) / 255


def ramp(t, colours, pos=None):
    cs = np.stack([rgb(c) for c in colours])
    pos = np.linspace(0, 1, len(cs)) if pos is None else np.asarray(pos, dtype=np.float32)
    return np.stack([np.interp(t, pos, cs[:, ch]) for ch in range(3)], axis=-1)


def box_blur(x, r, passes=3):
    """Float blur along both image axes (three box passes ~ Gaussian), edges clamped."""
    x = np.asarray(x, dtype=np.float32)
    for _ in range(passes):
        for ax in (0, 1):
            n = x.shape[ax]
            pad = [(0, 0)] * x.ndim
            pad[ax] = (r + 1, r)
            c = np.cumsum(np.pad(x, pad, mode="edge"), axis=ax, dtype=np.float64)
            hi = np.take(c, np.arange(2 * r + 1, 2 * r + 1 + n), axis=ax)
            lo = np.take(c, np.arange(0, n), axis=ax)
            x = ((hi - lo) / (2 * r + 1)).astype(np.float32)
    return x


def blur(mask, radius):
    im = Image.fromarray((np.clip(mask, 0, 1) * 255).astype(np.uint8))
    return np.asarray(im.filter(ImageFilter.GaussianBlur(radius)), dtype=np.float32) / 255


class Night:
    """The analysed source picture, shared by every scene."""

    def __init__(self, path):
        src = Image.open(path).convert("RGB")
        # The source has a faint light border; trim it and scale back up
        b = round(src.width * 0.003)
        src = src.crop((b, b, src.width - b, src.height - b)).resize(src.size, Image.LANCZOS)
        a = np.asarray(src, dtype=np.float32) / 255
        H, W, _ = a.shape
        s = W / 1920  # tuned at 1920 wide
        lum = a @ LW
        yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)

        # Sky colour per row, from columns that are open sky down to the horizon
        cols = np.r_[int(W * .33):int(W * .42), int(W * .58):int(W * .67)]
        prof = np.median(a[:, cols], axis=1)
        hz = int(np.argmax((prof @ LW)[:int(H * .75)]))
        prof[hz:] = prof[hz]
        plum = prof @ LW

        # Radial vignette, fitted on pixels that already match the row's sky
        r = np.sqrt(((xx - W / 2) / (W / 2)) ** 2 + ((yy - H / 2) / (H / 2)) ** 2) / np.sqrt(2)
        seed = (np.linalg.norm(a - prof[:, None, :], axis=-1) < 0.03) & (yy < hz)
        rel = lum / plum[:, None]
        bins = np.linspace(0, 1, 41)
        idx = np.clip(np.digitize(r, bins) - 1, 0, 39)
        ratio, ok = np.ones(40), np.zeros(40, bool)
        for i in range(40):
            m = seed & (idx == i)
            if m.sum() > 200 * s * s:
                ratio[i], ok[i] = np.median(rel[m]), True
        # Smooth falloff 1 - k * max(0, r - r0)^2, so no band edges show once brightened
        mid = (bins[:-1] + bins[1:]) / 2
        r0 = 0.5
        x2 = np.maximum(0, mid[ok] - r0) ** 2
        k_fit = max(0.0, float(np.sum(x2 * (1 - ratio[ok])) / max(np.sum(x2 * x2), 1e-9)))
        vig = (1 - k_fit * np.maximum(0, r - r0) ** 2).astype(np.float32)
        sky_ref = prof[:, None, :] * vig[..., None]

        # Soft sky mask; stars count as sky, then close the dark rings around them
        d = np.linalg.norm(a - sky_ref, axis=-1)
        excess = lum - sky_ref @ LW
        base = np.clip((0.06 - d) / 0.03, 0, 1)
        k = int(9 * s) | 1

        def close(m):
            im = Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(k)).filter(ImageFilter.MinFilter(k))
            return np.asarray(im, dtype=np.float32) / 255

        # Only dots inside the sky are stars; the fireflies over trees and mountains are land
        star = (excess > 0.03) & (yy < hz - 8 * s) & (close(base) > 0.5)
        alpha = np.maximum(base, star)
        alpha *= np.clip((hz + 14 * s - yy) / (20 * s), 0, 1)
        closed = close(alpha)
        upper = yy < hz - 12 * s
        alpha = np.where(upper, np.maximum(alpha, closed), alpha)

        # Land brightness, stretched over the land pixels only
        land = alpha < 0.1
        flat = lum / vig  # without the vignette, or it shows up as rings once the land is brightened
        lo, hi = np.percentile(flat[land], [1, 99.7])
        # Edge pixels are a blend of sky and land. Estimate the land colour there from
        # nearby solid land, then un-blend: how far along land -> sky is the pixel?
        k = int(11 * s) | 1
        solid = np.asarray(Image.fromarray((land * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(k)), dtype=np.float32) / 255
        wsum = box_blur(solid, int(10 * s))
        L = box_blur(a * solid[..., None], int(10 * s)) / np.maximum(wsum, 1e-4)[..., None]
        edge = (np.asarray(Image.fromarray(((alpha > 0.01) * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(k)), dtype=np.float32) > 0)
        edge &= (solid < 0.5) & (alpha < 0.99) & (wsum > 0.02)
        SL = sky_ref - L
        matte = np.clip(np.sum((a - L) * SL, axis=-1) / np.maximum(np.sum(SL * SL, axis=-1), 1e-5), 0, 1)
        alpha = np.where(edge, matte, alpha)
        flat = np.where(edge, (L @ LW) / vig, flat)
        self.land_t = np.clip((flat - lo) / (hi - lo), 0, 1)
        # Sparkles (fireflies) on the land: kept for night scenes, smoothed away otherwise
        med = np.asarray(Image.fromarray((self.land_t * 255).astype(np.uint8)).filter(ImageFilter.MedianFilter(int(13 * s) | 1)),
                         dtype=np.float32) / 255
        spark = blur((self.land_t - med > 0.08).astype(np.float32), 2 * s) > 0.05
        self.land_clean = np.where(spark, med, self.land_t)
        self.stars = np.clip(excess / 0.5, 0, 1) * star
        self.a, self.alpha, self.vig = a, alpha, vig
        self.H, self.W, self.hz, self.s = H, W, hz, s
        self.yy, self.xx = yy, xx

    def render(self, sc):
        H, W, hz, s = self.H, self.W, self.hz, self.s
        yy, xx = self.yy, self.xx
        t_sky = np.clip(yy / hz, 0, 1)
        pos, cols = zip(*sc["sky"])
        sky = ramp(t_sky, cols, pos)
        land_t = self.land_t if sc.get("sparkles") else self.land_clean
        land = ramp(land_t, sc["land"])

        if "haze" in sc:  # far land (bright at night) fades into the haze colour
            hz_amt = sc["haze"]["amount"] * land_t[..., None] ** 1.5
            land = land * (1 - hz_amt) + rgb(sc["haze"]["colour"]) * hz_amt

        if "glow" in sc:
            g = sc["glow"]
            gx, R = g["x"] * W, g["radius"] * W
            fall = np.exp(-(((xx - gx) / R) ** 2 + ((yy - hz) / (R * 0.55)) ** 2))[..., None]
            c = rgb(g["colour"])
            sky = sky + (c - sky) * np.clip(g["strength"] * fall, 0, 1)
            # the lake and the far slopes catch some of it
            catch = np.clip(g["strength"] * 0.7 * fall * land_t[..., None] ** 2, 0, 1)
            land = land + (c - land) * catch

        if "sun" in sc:
            u = sc["sun"]
            cx, cy, rad = u["x"] * W, hz - u["rise"] * H, u["radius"] * W
            disc = blur(((xx - cx) ** 2 + (yy - cy) ** 2 < rad ** 2).astype(np.float32), 1.5 * s)[..., None]
            sky = sky + (rgb(u["colour"]) - sky) * disc

        if "clouds" in sc:
            c = sc["clouds"]
            layer = Image.new("L", (W, H), 0)
            dr = ImageDraw.Draw(layer)
            # (x, y, width, height) as fractions of the picture
            for x, y, w, h in [(.18, .16, .16, .035), (.25, .19, .10, .03), (.62, .10, .2, .04), (.70, .135, .12, .03),
                               (.43, .30, .12, .025), (.85, .33, .1, .025), (.08, .38, .09, .02)]:
                dr.ellipse([(x - w / 2) * W, (y - h / 2) * H, (x + w / 2) * W, (y + h / 2) * H], fill=255)
            cl = np.asarray(layer.filter(ImageFilter.GaussianBlur(14 * s)), dtype=np.float32)[..., None] / 255
            sky = sky + (rgb(c["colour"]) - sky) * cl * c["opacity"]

        if sc.get("stars"):
            sky = sky + (rgb(sc.get("star_colour", "#ffffff")) - sky) * (self.stars[..., None] * sc["stars"] * 2).clip(0, 1)

        # The farthest land (bright, just under the horizon) melts into the horizon sky
        near_hz = np.exp(-np.maximum(0, yy - hz) / (0.035 * H))[..., None] * (yy >= hz - 20 * s)[..., None]
        land = land + (sky[hz][None, :, :] - land) * np.clip(0.75 * near_hz * land_t[..., None] ** 1.5, 0, 1)

        al = self.alpha[..., None]
        out = sky * al + land * (1 - al)

        if "mist" in sc:  # fog lying at lake level, thinning upwards and downwards
            m = sc["mist"]
            band = np.exp(-((yy - (hz + 0.12 * H)) / (0.11 * H)) ** 2)[..., None]
            amt = np.clip(m["amount"] * band * (0.4 + 0.6 * land_t[..., None]), 0, 1)
            out = out + (rgb(m["colour"]) - out) * amt

        if "snow" in sc:
            n = sc["snow"]
            rng = np.random.default_rng(7)
            layer = Image.new("L", (W, H), 0)
            dr = ImageDraw.Draw(layer)
            for _ in range(n["count"]):
                x, y = rng.uniform(0, W), rng.uniform(0, H)
                r = rng.uniform(1.6, 4.0) * s
                dr.ellipse([x - r, y - r, x + r, y + r], fill=int(rng.uniform(90, 200)))
            fl = np.asarray(layer.filter(ImageFilter.GaussianBlur(1.6 * s)), dtype=np.float32)[..., None] / 255
            out = out + (rgb(n["colour"]) - out) * fl

        if sc.get("vignette"):
            out = out * self.vig[..., None]
        return Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8))
