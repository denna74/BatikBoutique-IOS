import glob
import numpy as np
from PIL import Image
import scipy.ndimage as ndi

SPECIAL = {
    "001": [(68, 349)],
    "002": [(68, 355)],
    "003": [(86, 352)],
    "004": [(106, 349)],
    "005": [(130, 341)],
    "006": [(115, 344, 357)],
    "007": [(75, 361)],
    "051": [(100, 340)],
}
SECOND_ARC = {"037", "038", "050", "051"}
SECOND_ARC_ANCHOR = (84, 330)
SECOND_ARC_YS = (326, 335)


def dark_label(a):
    band = a[300:384]
    dark = (band[:, :, :3].max(axis=2) < 100) & (band[:, :, 3] > 10)
    lab, _ = ndi.label(dark)
    return lab, dark


def comp_near(lab, x, y, radius=14):
    yb = y - 300
    best = None
    best_dist = 1e9
    for i in range(1, lab.max() + 1):
        ys, xs = np.where(lab == i)
        if len(ys) < 10:
            continue
        cx, cy = (xs.min() + xs.max()) / 2, (ys.min() + ys.max()) / 2
        dist = max(abs(cx - x), abs(cy - yb))
        if dist < best_dist:
            best_dist = dist
            best = (lab == i)
    if best_dist > radius:
        return None
    return best


def whiten(name):
    a = np.array(Image.open(f"assets/character/coming/sprite_{name}.png").convert("RGBA"))
    lab, dark = dark_label(a)
    changed = 0
    handled = []

    if name in SPECIAL:
        for spec in SPECIAL[name]:
            if len(spec) == 3:
                ax, ay, ymax = spec
            else:
                ax, ay = spec
                ymax = None
            mask = comp_near(lab, ax, ay)
            if mask is None:
                handled.append((ax, ay, "no component"))
                continue
            ys, xs = np.where(mask)
            ys = ys + 300
            keep = np.ones(len(ys), dtype=bool)
            if ymax is not None:
                keep &= ys <= ymax
            n = int(keep.sum())
            a[ys[keep], xs[keep], 0:3] = 255
            changed += n
            handled.append((ax, ay, f"whitened {n}px"))
    else:
        mask = comp_near(lab, 88, 340)
        if mask is None:
            handled.append((88, 340, "no component"))
        else:
            ys, xs = np.where(mask)
            ys = ys + 300
            n = len(ys)
            a[ys, xs, 0:3] = 255
            changed += n
            handled.append((88, 340, f"whitened {n}px"))

    if name in SECOND_ARC:
        mask = comp_near(lab, *SECOND_ARC_ANCHOR)
        if mask is None:
            handled.append((SECOND_ARC_ANCHOR, "second arc: no component"))
        else:
            ys, xs = np.where(mask)
            ys = ys + 300
            keep = (ys >= SECOND_ARC_YS[0]) & (ys <= SECOND_ARC_YS[1])
            n = int(keep.sum())
            a[ys[keep], xs[keep], 0:3] = 255
            changed += n
            handled.append((SECOND_ARC_ANCHOR, f"second arc whitened {n}px"))

    Image.fromarray(a).save(f"assets/character/coming/sprite_{name}.png", optimize=True)
    return changed, handled


if __name__ == "__main__":
    for f in sorted(glob.glob("assets/character/coming/sprite_*.png")):
        name = f.split("_")[-1].split(".")[0]
        changed, handled = whiten(name)
        print(name, changed, handled)
