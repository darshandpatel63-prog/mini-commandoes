#!/usr/bin/env python3
"""Bakes the 'Iron Vanguard' 3D mesh (FBX, kept OUTSIDE the repo) into 2D cut-out sprites for the Godot game.
Dev-machine tool (needs numpy, scipy, Pillow). Output is committed; the FBX is not.
  python3 tools/bake_sprites.py /path/Iron_Vanguard.fbx [--preview-dir DIR]
Writes assets/art/commando/<character>/<part>.png, portrait_<character>.png and rig.json.
The FBX is one untextured, un-rigged, 1.4M-triangle mesh: we segment it into 7 rigid parts, render each from the
side with cartoon shading + zone colours (palette per character) and describe the cut-out rig in rig.json."""
import sys, json, math, pathlib
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import fbx_reader as F

ROOT = pathlib.Path(__file__).resolve().parent.parent
UNIT_PX, SS = 82.0, 3                         # texture px per mesh unit (character ~156 px tall), supersampling
VIEW = (-1.0, 0.0, 0.0)                       # camera at -X: character faces screen-right (front = -Y)
CX, Z_FEET, Z_HIP, Z_KNEE, Z_SHOULDER = 0.055, -0.952, -0.20, -0.56, 0.585
ARM_HALF, PLUG_R = 0.285, 0.13
PARTS = ["body", "arm_near", "arm_far", "thigh_near", "shin_near", "thigh_far", "shin_far"]
ZONES = ["uniform", "vest", "helmet", "skin", "glove", "boot", "pack", "gear"]
PALETTES = {
 "rook":    dict(uniform="#B59A6A", vest="#3C4247", helmet="#5F6B3B", skin="#C68E6A", glove="#2A2D30", boot="#3B2A1E", pack="#6A593A", gear="#30343A"),
 "juno":    dict(uniform="#3F5D78", vest="#8A97A0", helmet="#1F2D3E", skin="#D9A57B", glove="#E8A33D", boot="#202225", pack="#2B7F7C", gear="#2B3138"),
 "mirelle": dict(uniform="#CBD3D1", vest="#B13A3A", helmet="#E6EBE9", skin="#8A5A3C", glove="#6E7A78", boot="#4A4038", pack="#E6EBE9", gear="#3B4247"),
 "kade":    dict(uniform="#405B3B", vest="#6C5036", helmet="#30492F", skin="#E4BC9C", glove="#5A4330", boot="#1F1F1F", pack="#7B6B46", gear="#2D3027"),
}
def hexrgb(h): h = h.lstrip("#"); return np.array([int(h[i:i+2], 16) for i in (0, 2, 4)], np.float32)/255.0

def load_mesh(fbx):
    v, roots = F.parse(fbx)
    obj = [r for r in roots if r.name == "Objects"][0]
    g = [c for c in obj.children if c.name == "Geometry"][0]
    V = g.first("Vertices").props[0].reshape(-1, 3).astype(np.float32)
    idx = g.first("PolygonVertexIndex").props[0]
    tri = idx.reshape(-1, 3).copy(); tri[:, 2] = -tri[:, 2]-1
    cen = (V[tri[:, 0]]+V[tri[:, 1]]+V[tri[:, 2]])/3.0
    return np.concatenate([V, cen]).astype(np.float32)

def label(P):
    x, y, z = P[:, 0], P[:, 1], P[:, 2]; dx = x-CX
    part = np.zeros(len(P), np.int8)
    arm = (z > Z_HIP+0.02) & (z < Z_SHOULDER+0.12) & (np.abs(dx) > ARM_HALF)
    arm &= ~((z > Z_SHOULDER+0.04) & (np.abs(dx) < 0.34))
    part[arm & (dx < 0)] = 1; part[arm & (dx >= 0)] = 2
    leg = z <= Z_HIP
    part[leg & (dx < 0) & (z > Z_KNEE)] = 3; part[leg & (dx < 0) & (z <= Z_KNEE)] = 4
    part[leg & (dx >= 0) & (z > Z_KNEE)] = 5; part[leg & (dx >= 0) & (z <= Z_KNEE)] = 6
    return part

def plug_shoulders(P, part, piv):
    """Arm points close to a shoulder pivot stay with the body so no hole is left when the arm swings."""
    for pi, key in ((1, "shoulder_near"), (2, "shoulder_far")):
        ys, zs = piv[key]
        near = (part == pi) & ((P[:, 1]-ys)**2 + (P[:, 2]-zs)**2 < PLUG_R**2)
        part[near] = 0
    return part

def zones(P, part):
    x, y, z = P[:, 0], P[:, 1], P[:, 2]; dx = x-CX
    zn = np.zeros(len(P), np.int8)
    zn[(part == 0) & (z > -0.10) & (z < 0.64) & (np.abs(dx) < 0.30)] = 1
    zn[(part == 0) & (z >= 0.64) & (z < 0.74)] = 3
    head = (part == 0) & (z >= 0.74); zn[head] = 2
    zn[head & (z < 0.88) & (y < -0.10) & (np.abs(dx) < 0.13)] = 3
    zn[(part == 0) & (y > 0.12) & (z > -0.10) & (z < 0.66)] = 6
    zn[((part == 1) | (part == 2)) & (z < 0.0)] = 4
    zn[(part >= 3) & (z < -0.76)] = 5
    zn[(part == 0) & (z <= -0.02) & (z > -0.20) & (np.abs(dx) < 0.32)] = 7
    return zn

def part_mask(P, part, name):
    z = P[:, 2]; dx = P[:, 0]-CX; pi = PARTS.index(name); m = part == pi
    inner = np.abs(dx) < ARM_HALF
    if name.startswith("thigh"):
        side = dx < 0 if name.endswith("near") else dx >= 0
        m |= side & inner & (z > Z_KNEE-0.035) & (z <= Z_HIP+0.035) & ((part == 0) | (part == pi) | (part == pi+1))
    if name.startswith("shin"):
        side = dx < 0 if name.endswith("near") else dx >= 0
        m |= side & (z <= Z_KNEE+0.035) & (z > Z_KNEE-0.035) & ((part == pi-1) | (part == pi))
    return m

def centroid(P, m): return float(P[m, 1].mean()), float(P[m, 2].mean())

def pivots(P, part):
    z = P[:, 2]; piv = {}
    for side, pi_arm, pi_th, pi_sh in (("near", 1, 3, 4), ("far", 2, 5, 6)):
        a = (part == pi_arm) & (z > 0.45) & (z < 0.60)
        piv["shoulder_"+side] = (centroid(P, a)[0], Z_SHOULDER-0.02)
        th = part == pi_th
        piv["hip_"+side] = (centroid(P, th & (z < Z_HIP+0.02))[0], Z_HIP+0.02)
        piv["knee_"+side] = (centroid(P, (part == pi_th) & (z < Z_KNEE+0.05) | (part == pi_sh) & (z > Z_KNEE-0.05))[0], Z_KNEE)
        piv["ankle_"+side] = (centroid(P, (part == pi_sh) & (z > -0.88) & (z < -0.80))[0], -0.84)
        piv["wrist_"+side] = (centroid(P, (part == pi_arm) & (z < -0.04) & (z > -0.16))[0], -0.10)
    return piv

def splat(Pm, Zm, scale, origin, W, H):
    d = np.array(VIEW, np.float32); d /= np.linalg.norm(d)
    up = np.array([0, 0, 1], np.float32); r = np.cross(up, d); r /= np.linalg.norm(r); u = np.cross(d, r)
    sx, sy, dep = Pm@r, Pm@u, -(Pm@d)
    px = np.round((sx-origin[0])*scale+W/2).astype(np.int64)
    py = np.round(H-1-(sy-origin[1])*scale).astype(np.int64)
    ok = (px >= 0) & (px < W) & (py >= 0) & (py < H)
    px, py, dep, ids = px[ok], py[ok], dep[ok], Zm[ok]
    pix = py*W+px
    order = np.lexsort((-dep, pix)); ps = pix[order]
    sel = order[np.r_[ps[1:] != ps[:-1], True]]
    D = np.full(W*H, np.inf, np.float32); ID = np.full(W*H, -1, np.int16)
    D[pix[sel]] = dep[sel]; ID[pix[sel]] = ids[sel]
    return D.reshape(H, W), ID.reshape(H, W)

def fill(D, ID, iters=3):
    for _ in range(iters):
        hole = ~np.isfinite(D)
        if not hole.any(): break
        pad = np.pad(D, 1, constant_values=np.inf); padi = np.pad(ID, 1, constant_values=-1)
        best = D.copy(); bid = ID.copy()
        for dy in range(3):
            for dx in range(3):
                c = pad[dy:dy+D.shape[0], dx:dx+D.shape[1]]; ci = padi[dy:dy+D.shape[0], dx:dx+D.shape[1]]
                better = c < best; best = np.where(better, c, best); bid = np.where(better, ci, bid)
        D = np.where(hole, best, D); ID = np.where(hole, bid, ID)
    return D, ID

def shade(D, ID, pal, scale):
    mask = np.isfinite(D)
    Df = np.where(mask, D, D[mask].max())*scale                  # depth in PIXEL units
    Ds = ndi.gaussian_filter(Df, 1.4)
    gx = ndi.sobel(Ds, axis=1)/8.0; gy = ndi.sobel(Ds, axis=0)/8.0
    n = np.stack([gx*0.9, -gy*0.9, np.ones_like(Ds)], -1); n /= np.linalg.norm(n, axis=-1, keepdims=True)
    Ld = np.array([-0.40, 0.70, 0.60], np.float32); Ld /= np.linalg.norm(Ld)
    lam = np.clip((n@Ld)*0.60+0.50, 0.15, 1.15)
    cav = np.clip((Df-ndi.gaussian_filter(Df, 7))/(0.05*scale), 0, 1)
    ao = 1.0-0.20*cav
    col = np.zeros(D.shape+(3,), np.float32)
    for i, k in enumerate(ZONES): col[ID == i] = hexrgb(pal[k])
    img = col*(lam*ao)[..., None]
    edge = (Df-ndi.minimum_filter(Df, 3)) > 0.11*scale          # only big depth steps (plates, straps, pouches)
    sil = mask & ~ndi.binary_erosion(mask, iterations=SS)
    img[ndi.binary_dilation(edge, iterations=1) & mask] *= 0.55
    img[sil] *= 0.28
    alpha = ndi.binary_closing(mask, iterations=2).astype(np.float32)
    return np.clip(img, 0, 1), alpha

def bake(fbx, out_root, preview_dir=None):
    P = load_mesh(fbx); part = label(P)
    piv = pivots(P, part); part = plug_shoulders(P, part, piv); zone = zones(P, part)
    y_o = float(P[(part == 0) & (P[:, 2] > -0.20) & (P[:, 2] < 0.0), 1].mean())   # pelvis depth = x origin of the rig
    scale = UNIT_PX*SS
    W, H = int(1.5*scale), int(2.1*scale)
    def to_px(y, z): return ((-(y-y_o))*UNIT_PX, (Z_FEET-z)*UNIT_PX)           # x forward-right, y down; origin feet-centre
    rig = {"unit_px": UNIT_PX, "height_px": round(1.903*UNIT_PX, 2), "origin": "feet-centre; x forward(right), y down",
           "order_back_to_front": ["leg_far", "body", "leg_near"], "parts": {}}
    pv = {k: to_px(*v) for k, v in piv.items()}
    def angle(a, b):                                         # rest rotation (rad) that makes a->b point straight down
        vx, vy = b[0]-a[0], b[1]-a[1]; return math.atan2(vx, vy)
    pivots_px = {"body": pv["hip_near"], "arm_near": pv["shoulder_near"], "arm_far": pv["shoulder_far"],
                 "thigh_near": pv["hip_near"], "shin_near": pv["knee_near"], "thigh_far": pv["hip_far"], "shin_far": pv["knee_far"]}
    hip_c = ((pv["hip_near"][0]+pv["hip_far"][0])/2, (pv["hip_near"][1]+pv["hip_far"][1])/2)
    pivots_px["body"] = hip_c
    rest = {"thigh_near": angle(pv["hip_near"], pv["knee_near"]), "shin_near": angle(pv["knee_near"], pv["ankle_near"]),
            "thigh_far": angle(pv["hip_far"], pv["knee_far"]), "shin_far": angle(pv["knee_far"], pv["ankle_far"]),
            "arm_near": angle(pv["shoulder_near"], pv["wrist_near"]), "arm_far": angle(pv["shoulder_far"], pv["wrist_far"]), "body": 0.0}
    parent = {"body": "", "arm_near": "body", "arm_far": "body", "thigh_near": "", "shin_near": "thigh_near", "thigh_far": "", "shin_far": "thigh_far"}
    crops = {}
    for cname, pal in PALETTES.items():
        out = pathlib.Path(out_root)/cname; out.mkdir(parents=True, exist_ok=True)
        for name in PARTS:
            m = part_mask(P, part, name)
            if not m.any(): continue
            D, ID = splat(P[m], zone[m].astype(np.int16), scale, (-(-y_o), Z_FEET), W, H)   # screen-x origin = -(-y_o)... see to_px
            D, ID = fill(D, ID, 3)
            img, a = shade(D, ID, pal, scale)
            big = Image.fromarray((np.concatenate([img, a[..., None]], -1)*255).astype(np.uint8), "RGBA")
            small = big.resize((W//SS, H//SS), Image.LANCZOS)
            bb = small.getbbox()
            crop = small.crop(bb)
            crop.save(out/f"{name}.png", optimize=True)
            crops[name] = bb
    # sprite frame: pixel (cx, H/SS-1 - ...) -> rig coords. canvas column W/2/SS == screen-x of y_o, row H/SS-1 == feet
    cw, ch = (W//SS)/2.0, (H//SS)-1.0
    for name in PARTS:
        l, t, r_, b = crops[name]
        px, py = pivots_px[name]
        rig["parts"][name] = {"file": f"{name}.png", "parent": parent[name], "draw": name,
            "pivot": [round(px, 2), round(py, 2)], "rest_rad": round(rest[name], 5),
            "texture_offset": [round(l-cw-px, 2), round(t-ch-py, 2)], "size": [r_-l, b-t]}
        if name.startswith("arm"):
            side = name.split("_")[1]
            rig["parts"][name]["wrist"] = [round(pv["wrist_"+side][0]-px, 2), round(pv["wrist_"+side][1]-py, 2)]
    pathlib.Path(out_root, "rig.json").write_text(json.dumps(rig, indent=1))
    # portraits: compose rest pose in PIL
    for cname in PALETTES:
        port = compose(rig, pathlib.Path(out_root)/cname, cname)
        bb = port.getbbox(); port = port.crop((max(bb[0]-4, 0), max(bb[1]-4, 0), min(bb[2]+4, port.width), min(bb[3]+4, port.height)))
        port.save(pathlib.Path(out_root)/f"portrait_{cname}.png", optimize=True)
        if preview_dir: port.save(pathlib.Path(preview_dir)/f"portrait_{cname}.png")
    return rig

def compose(rig, folder, cname, scale=1.0, extra_angles=None):
    """Mimics the Godot node hierarchy (pivot + rest rotation, children follow parents) to build a portrait."""
    parts = rig["parts"]; extra_angles = extra_angles or {}
    Wc, Hc = 300, 220
    canvas = Image.new("RGBA", (Wc, Hc), (0, 0, 0, 0))
    ox, oy = Wc/2, Hc-6                                           # feet-centre in the portrait canvas
    def world(name):
        """returns (pivot_world, total_rotation) following the parent chain"""
        p = parts[name]; par = p["parent"]
        if not par:
            return (p["pivot"][0], p["pivot"][1]), p["rest_rad"]+extra_angles.get(name, 0.0)
        (pp, pr) = world(par)
        rel = (p["pivot"][0]-parts[par]["pivot"][0], p["pivot"][1]-parts[par]["pivot"][1])
        c, s = math.cos(pr), math.sin(pr)
        pos = (pp[0]+rel[0]*c-rel[1]*s, pp[1]+rel[0]*s+rel[1]*c)
        return pos, pr+p["rest_rad"]+extra_angles.get(name, 0.0)-0.0 if False else pr+(p["rest_rad"]-parts[par]["rest_rad"])+extra_angles.get(name, 0.0)
    for name in ["arm_far", "thigh_far", "shin_far", "body", "thigh_near", "shin_near", "arm_near"]:
        p = parts[name]; im = Image.open(folder/p["file"]).convert("RGBA")
        pos, rot = world(name)
        # place sprite so its pivot lands on pos, rotated by rot (godot: clockwise) about the pivot
        px_in_img = (-p["texture_offset"][0], -p["texture_offset"][1])
        pad = max(im.size)
        tmp = Image.new("RGBA", (im.width+2*pad, im.height+2*pad), (0, 0, 0, 0)); tmp.paste(im, (pad, pad))
        tmp = tmp.rotate(-math.degrees(rot), resample=Image.BICUBIC, center=(px_in_img[0]+pad, px_in_img[1]+pad))
        canvas.alpha_composite(tmp, (int(round(ox+pos[0]-px_in_img[0]-pad)), int(round(oy+pos[1]-px_in_img[1]-pad))))
    return canvas

if __name__ == "__main__":
    fbx = sys.argv[1]; pv = None
    if "--preview-dir" in sys.argv: pv = sys.argv[sys.argv.index("--preview-dir")+1]; pathlib.Path(pv).mkdir(parents=True, exist_ok=True)
    bake(fbx, ROOT/"assets/art/commando", pv); print("baked")
