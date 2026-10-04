#!/usr/bin/env python3
"""REFERENCE MODEL of the Mini Commandoes rules (damage pipeline, EP, recovery, stats, loadout validation,
haptics, HUD layout, authority admission). It exists because the authoring sandbox cannot run Godot:
the same rules are executed here, hand-checked in tools/gen_vectors.py, and exported as test vectors that the
GDScript implementation must reproduce in CI (tests/run_tests.gd). Keep both implementations in lock-step.
Spec: docs/combat.md, docs/loadout.md, docs/controls_haptics.md."""
import copy, json, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
EPS = 1e-9

def _load(n): return json.loads((ROOT / "data" / n).read_text())

class Data:
    def __init__(self):
        self.rules = _load("balance.json")
        self.armor = _load("armor.json")
        self.skills = {s["id"]: s for s in _load("skills.json")["skills"]}
        self.pets = {s["id"]: s for s in _load("pets.json")["pets"]}
        self.chars = {s["id"]: s for s in _load("characters.json")["characters"]}
        self.weapons = {s["id"]: s for s in _load("weapons.json")["weapons"]}
        self.melee = {s["id"]: s for s in _load("melee.json")["melee"]}
        self.throwables = {s["id"]: s for s in _load("throwables.json")["throwables"]}
        self.presets = _load("presets.json")["presets"]
        self.hud = _load("hud_default.json")["controls"] if (ROOT / "data/hud_default.json").exists() else []

def clamp(v, lo, hi): return max(lo, min(hi, v))

# ---------------------------------------------------------------- stats
def resolve_stats(rules, mods):
    out = dict(rules["stat_defaults"])
    for m in mods:
        s = m["stat"]
        if s not in out: continue
        if m["op"] == "mult": out[s] *= m["value"]
        elif m["op"] == "add": out[s] += m["value"]
    for s, (lo, hi) in rules["stat_caps"].items():
        out[s] = clamp(out[s], lo, hi)
    return out

def stats_of(d, st, now):
    mods = list(st["passive_mods"]) + [m for m in st["temp_mods"] if m["expires"] > now]
    return resolve_stats(d.rules, mods)

# ---------------------------------------------------------------- state
def _piece(d, name, spec):
    level = int(spec[0]) if spec else 0
    dur = float(spec[1]) if len(spec) > 1 else float(d.armor[name][level]["durability"])
    return {"level": level, "dur": dur}

def make_state(d, spec):
    r = d.rules
    st = {"alive": True, "downed": False, "allow_knockdown": bool(spec.get("allow_knockdown", False)),
          "hp": float(spec.get("hp", r["base_hp"])), "max_hp": float(r["base_hp"]), "down_hp": 0.0,
          "ep": float(spec.get("ep", r["base_ep"])), "ep_last_spent": -1000.0,
          "shield": 0.0, "shield_expires": 0.0, "invuln_until": 0.0,
          "helmet": _piece(d, "helmet", spec.get("helmet", [0])), "vest": _piece(d, "vest", spec.get("vest", [0])),
          "passive_mods": [], "temp_mods": [], "flags": [], "hots": [], "converts": [],
          "cooldowns": {}, "heal_cd_until": 0.0, "using": None, "triage_ready_at": 0.0,
          "inventory": dict(spec.get("inventory", r["default_inventory"]))}
    for sid in spec.get("passives", []):
        s = d.skills[sid]
        st["passive_mods"] += copy.deepcopy(s.get("effects", []))
        st["flags"] += list(s.get("rules", []))
    return st

def max_ep(d, st, now):
    return d.rules["base_ep"] + stats_of(d, st, now)["ep_max_bonus"]

# ---------------------------------------------------------------- damage pipeline
def apply_hit(d, st0, hit, now):
    st = copy.deepcopy(st0)
    rep = {"hp_damage": 0.0, "armor_absorbed": 0.0, "shield_absorbed": 0.0, "ep_absorbed": 0.0, "piece": "",
           "piece_broken": False, "killed": False, "downed": False, "interrupted": False, "blocked": False}
    if not st["alive"]: return st, rep
    if st["invuln_until"] > now:
        rep["blocked"] = True; return st, rep
    stats = stats_of(d, st, now)
    zone = hit.get("zone", "body")
    raw = float(hit["damage"])
    if zone == "head": raw *= float(hit.get("head_mult", 1.0))
    piece_name = "helmet" if zone == "head" else "vest"
    piece = st[piece_name]
    ignore = bool(hit.get("ignore_armor", False))
    if not ignore and piece["level"] > 0 and piece["dur"] > EPS:
        before = piece["dur"]
        tbl = d.armor[piece_name][piece["level"]]
        absorbed = raw * tbl["reduction"] * (1.0 - float(hit.get("armor_pen", 0.0)))
        cost = absorbed * stats["durability_loss_mult"]
        if cost > piece["dur"]:
            absorbed *= piece["dur"] / cost
            cost = piece["dur"]
        piece["dur"] -= cost
        raw -= absorbed
        rep["armor_absorbed"] = absorbed; rep["piece"] = piece_name
        ab = float(hit.get("armor_break", 0.0))
        if ab > 0: piece["dur"] = max(0.0, piece["dur"] - ab)
        if piece["dur"] <= EPS:
            piece["dur"] = 0.0
            if before > EPS: rep["piece_broken"] = True
    raw *= stats["damage_taken_mult"]
    if zone == "head": raw *= stats["head_damage_taken_mult"]
    if st["shield"] > 0 and st["shield_expires"] > now:
        s = min(st["shield"], raw)
        st["shield"] -= s; raw -= s; rep["shield_absorbed"] = s
    ratio = stats["ep_barrier"]
    if ratio > 0 and st["ep"] > 0 and raw > 0:
        per = d.rules["ep"]["barrier_hp_per_ep"]
        use = min(raw * ratio / per, st["ep"])
        absorbed = use * per
        st["ep"] -= use; st["ep_last_spent"] = now
        raw -= absorbed; rep["ep_absorbed"] = absorbed
    rep["hp_damage"] = raw
    if raw > 0 and st["using"] is not None and st["using"].get("interruptible", True):
        st["using"] = None; rep["interrupted"] = True
    if st["downed"]:
        st["down_hp"] -= raw
        if st["down_hp"] <= 0:
            st["down_hp"] = 0.0; st["alive"] = False; st["downed"] = False; rep["killed"] = True
    else:
        st["hp"] -= raw
        if st["hp"] <= 0:
            st["hp"] = 0.0
            if st["allow_knockdown"]:
                st["downed"] = True; st["down_hp"] = float(d.rules["knockdown_hp"]); rep["downed"] = True
            else:
                st["alive"] = False; rep["killed"] = True
    return st, rep

# ---------------------------------------------------------------- EP / recovery / tick
def ep_spend(st, amount, now):
    if st["ep"] + EPS < amount: return False
    st["ep"] -= amount
    if amount > 0: st["ep_last_spent"] = now
    return True

def item_start(d, st0, item_id, now):
    st = copy.deepcopy(st0)
    it = d.rules["items"].get(item_id)
    if it is None: return st, "UNKNOWN_ITEM"
    if not st["alive"] or st["downed"]: return st, "DOWNED"
    if st["using"] is not None: return st, "BUSY"
    if now < st["heal_cd_until"]: return st, "COOLDOWN"
    if st["inventory"].get(item_id, 0) <= 0: return st, "NONE"
    stats = stats_of(d, st, now)
    if it["kind"] == "hp" and st["hp"] >= st["max_hp"] - EPS: return st, "FULL"
    if it["kind"] == "ep" and st["ep"] >= max_ep(d, st, now) - EPS: return st, "FULL"
    if it["kind"] == "durability" and not _repair_target(d, st): return st, "FULL"
    st["using"] = {"item": item_id, "finish_at": now + it["apply_time"] * stats["heal_apply_time_mult"],
                   "interruptible": bool(it["interruptible"])}
    return st, ""

def _repair_target(d, st):
    best, ratio = "", 2.0
    for name in ("helmet", "vest"):
        p = st[name]; full = d.armor[name][p["level"]]["durability"]
        if p["level"] > 0 and p["dur"] < full - EPS:
            r = p["dur"] / full
            if r < ratio: best, ratio = name, r
    return best

def tick(d, st0, dt, now):
    st = copy.deepcopy(st0)
    st["temp_mods"] = [m for m in st["temp_mods"] if m["expires"] > now]
    if st["shield"] > 0 and st["shield_expires"] <= now: st["shield"] = 0.0
    stats = stats_of(d, st, now)
    mx = d.rules["base_ep"] + stats["ep_max_bonus"]
    if now - st["ep_last_spent"] >= d.rules["ep"]["regen_delay"]:
        st["ep"] = min(mx, st["ep"] + d.rules["ep"]["regen_per_s"] * stats["ep_regen_mult"] * dt)
    else:
        st["ep"] = min(st["ep"], mx)
    if not st["alive"] or st["downed"]:
        st["hots"] = []; st["converts"] = []; st["using"] = None
        return st
    # heal over time (global cap)
    if st["hots"]:
        amts = [min(h["rate"] * dt, h["remaining"]) for h in st["hots"]]
        total = sum(amts); cap = d.rules["max_heal_per_s"] * dt
        scale = 1.0 if total <= cap else cap / total
        healed = 0.0
        for h, a in zip(st["hots"], amts):
            h["remaining"] -= a * scale; healed += a * scale
        st["hp"] = min(st["max_hp"], st["hp"] + healed)
        st["hots"] = [h for h in st["hots"] if h["remaining"] > EPS and h["expires_at"] > now]
    # EP -> HP conversion
    ratio = d.rules["ep"]["convert_ep_per_hp"]
    keep = []
    for c in st["converts"]:
        use = min(c["ep_rate"] * dt, c["remaining"], st["ep"], (st["max_hp"] - st["hp"]) * ratio)
        if use > 0:
            st["hp"] += use / ratio; st["ep"] -= use; c["remaining"] -= use; st["ep_last_spent"] = now
        if c["remaining"] > EPS and st["hp"] < st["max_hp"] - EPS: keep.append(c)
    st["converts"] = keep
    # item completion
    u = st["using"]
    if u is not None and now + EPS >= u["finish_at"]:
        it = d.rules["items"][u["item"]]
        if it["kind"] == "hp": st["hp"] = min(st["max_hp"], st["hp"] + it["amount"])
        elif it["kind"] == "ep": st["ep"] = min(mx, st["ep"] + it["amount"])
        elif it["kind"] == "durability":
            t = _repair_target(d, st)
            if t:
                full = d.armor[t][st[t]["level"]]["durability"]
                st[t]["dur"] = min(float(full), st[t]["dur"] + it["amount"])
        st["inventory"][u["item"]] -= 1
        st["heal_cd_until"] = now + d.rules["item_cooldown"]
        st["using"] = None
    # triage passive
    if "triage" in st["flags"] and st["hp"] < 0.30 * st["max_hp"] and now >= st["triage_ready_at"]:
        st["hots"].append({"rate": 2.0, "remaining": 0.40 * st["max_hp"] - st["hp"], "expires_at": now + 60.0})
        st["triage_ready_at"] = now + 20.0
    return st

# ---------------------------------------------------------------- skills
def activate(d, st0, skill_id, now):
    st = copy.deepcopy(st0)
    s = d.skills.get(skill_id)
    if s is None or s["kind"] not in ("active", "pet"): return st, "UNKNOWN_SKILL"
    if not st["alive"] or st["downed"]: return st, "DOWNED"
    if now < st["cooldowns"].get(skill_id, 0.0): return st, "COOLDOWN"
    eff = s.get("active_effect")
    if eff and eff["type"] == "convert_ep" and st["hp"] >= st["max_hp"] - EPS: return st, "NOTHING_TO_DO"
    if not ep_spend(st, s.get("ep_cost", 0), now): return st, "NO_EP"
    stats = stats_of(d, st, now)
    st["cooldowns"][skill_id] = now + s["cooldown"] * stats["skill_cooldown_mult"]
    if eff:
        t = eff["type"]
        if t == "shield":
            st["shield"] = max(st["shield"], float(eff["amount"])); st["shield_expires"] = now + eff["duration"]
        elif t == "heal_over_time":
            st["hots"].append({"rate": eff["total"] / eff["duration"], "remaining": float(eff["total"]), "expires_at": now + eff["duration"]})
        elif t == "convert_ep":
            st["converts"].append({"ep_rate": eff["ep_total"] / eff["duration"], "remaining": float(eff["ep_total"])})
        elif t == "temp_mods":
            for e in eff["effects"]:
                m = dict(e); m["expires"] = now + eff["duration"]; st["temp_mods"].append(m)
    return st, ""

# ---------------------------------------------------------------- loadout validation
def _empty(x): return x == "" or x is None

def _sid(v):
    """Returns the id string, or None when the value is not a usable string (hostile/garbage input)."""
    return v if isinstance(v, str) else None

def validate_loadout(d, lo):
    errs = []
    L = d.rules["loadout"]
    if not isinstance(lo, dict): return ["E_FORMAT"]
    ch = _sid(lo.get("character"))
    if ch is None or ch not in d.chars: errs.append("E_CHARACTER")
    active = lo.get("active", "")
    if not _empty(active):
        a = _sid(active)
        if a is None or a not in d.skills or d.skills[a]["kind"] != "active": errs.append("E_ACTIVE"); active = ""
    else: active = ""
    passives = lo.get("passives", [])
    if not isinstance(passives, list):
        errs.append("E_PASSIVE_COUNT"); passives = []
    elif len(passives) != L["passive_slots"]:
        errs.append("E_PASSIVE_COUNT")
    filled = []
    for p in passives:
        if _empty(p): continue
        if _sid(p) is None: errs.append("E_PASSIVE_KIND"); continue
        filled.append(p)
    if len(set(filled)) != len(filled): errs.append("E_PASSIVE_DUP")
    cost = 0; groups = {}; good = []
    for p in set(filled):
        if p not in d.skills or d.skills[p]["kind"] != "passive": errs.append("E_PASSIVE_KIND"); continue
        good.append(p); cost += d.skills[p]["cost"]
        g = d.skills[p].get("group")
        if g: groups[g] = groups.get(g, 0) + 1
    if cost > L["passive_budget"]: errs.append("E_BUDGET")
    for g, n in groups.items():
        if n > L["group_limits"].get(g, 99): errs.append("E_GROUP"); break
    pet = lo.get("pet", ""); pet_skill = ""
    if not _empty(pet):
        pp = _sid(pet)
        if pp is None or pp not in d.pets: errs.append("E_PET")
        else: pet_skill = d.pets[pp]["skill"]
    equipped = set([active] if active else []) | set(good) | set([pet_skill] if pet_skill else [])
    for sid in equipped:
        if any(ex in equipped for ex in d.skills.get(sid, {}).get("excludes", [])):
            errs.append("E_EXCLUDES"); break
    pr, se = _sid(lo.get("primary")), _sid(lo.get("secondary"))
    if pr is None or pr not in d.weapons or d.weapons[pr]["cls"] not in L["primary_classes"]: errs.append("E_PRIMARY")
    if se is None or se not in d.weapons or d.weapons[se]["cls"] not in L["secondary_classes"]: errs.append("E_SECONDARY")
    if pr is not None and pr == se and pr in d.weapons: errs.append("E_WEAPON_DUP")
    me, th = _sid(lo.get("melee")), _sid(lo.get("throwable"))
    if me is None or me not in d.melee: errs.append("E_MELEE")
    if th is None or th not in d.throwables: errs.append("E_THROWABLE")
    for k in ("start_helmet", "start_vest"):
        v = lo.get(k)
        if not isinstance(v, int) or isinstance(v, bool) or v < 0 or v > L["start_armor_max_level"]: errs.append("E_START_ARMOR"); break
    return sorted(set(errs))

LOADOUT_KEYS = ["character", "active", "passives", "pet", "primary", "secondary", "melee", "throwable", "start_helmet", "start_vest"]

def admit(d, claimed):
    """Host-side admission: only whitelisted keys of the CLAIMED loadout are read; everything else is ignored."""
    lo = {}
    if isinstance(claimed, dict):
        for k in LOADOUT_KEYS:
            if k in claimed: lo[k] = copy.deepcopy(claimed[k])
    errs = validate_loadout(d, lo)
    if errs: return {"ok": False, "errors": errs}
    return {"ok": True, "errors": [], "max_hp": d.rules["base_hp"]}

# ---------------------------------------------------------------- haptics
def default_haptics(d):
    p = d.rules["haptics"]["presets"]
    pre = {"fire": "medium", "jump": "low", "melee": "medium", "grenade": "medium", "skill": "high", "pet": "low", "reload": "low",
           "jet": "low", "swap": "low", "interact": "low", "heal": "medium", "ep_item": "medium", "crouch": "low",
           "move": "low", "aim": "low", "ui_button": "low"}
    return {"master_enabled": True, "master_intensity": 1.0,
            "controls": {k: {"enabled": True, "preset": v, "intensity": p[v]["intensity"], "duration_ms": p[v]["duration_ms"]} for k, v in pre.items()}}

def haptic_resolve(d, cfg, cid):
    if not cfg["master_enabled"]: return {"fire": False}
    c = cfg["controls"].get(cid)
    if c is None or not c["enabled"]: return {"fire": False}
    amp = clamp(c["intensity"] * cfg["master_intensity"], 0.0, 1.0)
    if amp <= 0.001: return {"fire": False}
    lo, hi = d.rules["haptics"]["duration_range_ms"]
    return {"fire": True, "duration_ms": int(clamp(c["duration_ms"], lo, hi)), "amplitude": round(amp, 4)}

# ---------------------------------------------------------------- HUD layout
def hud_ctl(d): return {c["id"]: c for c in d.hud}

def hud_default_layout(d):
    return {c["id"]: {"x": c["x"], "y": c["y"], "scale": c["scale"], "opacity": c["opacity"], "visible": c["visible"]} for c in d.hud}

def hud_sanitize(d, layout, screen, insets=(0, 0, 0, 0)):
    H = d.rules["hud"]; ctl = hud_ctl(d); default = hud_default_layout(d); out = {}
    il, it, ir, ib = insets
    for cid, c in ctl.items():
        e = layout.get(cid, default[cid]) if isinstance(layout, dict) else default[cid]
        scale = clamp(float(e.get("scale", 1.0)), *H["scale_range"])
        opacity = clamp(float(e.get("opacity", 0.7)), *H["opacity_range"])
        visible = True if c["required"] else bool(e.get("visible", True))
        hw = c["size"] * scale / 2.0 / screen[0]; hh = c["size"] * scale / 2.0 / screen[1]
        m = H["margin"]
        xmin = max(m, il / screen[0]) + hw; xmax = 1.0 - max(m, ir / screen[0]) - hw
        ymin = max(H["top_reserved"], it / screen[1]) + hh; ymax = 1.0 - max(m, ib / screen[1]) - hh
        x = clamp(float(e.get("x", default[cid]["x"])), xmin, xmax) if xmin <= xmax else 0.5
        y = clamp(float(e.get("y", default[cid]["y"])), ymin, ymax) if ymin <= ymax else 0.5
        out[cid] = {"x": round(x, 5), "y": round(y, 5), "scale": round(scale, 4), "opacity": round(opacity, 4), "visible": visible}
    return out

def hud_overlaps(d, layout, screen):
    ctl = hud_ctl(d); f = d.rules["hud"]["overlap_factor"]; ids = [i for i in ctl if layout[i]["visible"]]
    pairs = []
    for a in range(len(ids)):
        for b in range(a + 1, len(ids)):
            ia, ib = ids[a], ids[b]
            ra = ctl[ia]["size"] * layout[ia]["scale"] / 2; rb = ctl[ib]["size"] * layout[ib]["scale"] / 2
            dx = (layout[ia]["x"] - layout[ib]["x"]) * screen[0]; dy = (layout[ia]["y"] - layout[ib]["y"]) * screen[1]
            if (dx * dx + dy * dy) ** 0.5 < (ra + rb) * f: pairs.append([ia, ib])
    return pairs

def hud_preset(d, name):
    lay = hud_default_layout(d)
    if name == "left_handed":
        for v in lay.values(): v["x"] = round(1.0 - v["x"], 5)
    elif name == "compact":
        for v in lay.values(): v["scale"] = round(v["scale"] * 0.85, 4)
    return lay

# ================================================================= movement (Phase 2)
import math as _math
MOVE_EPS = 1e-6

def load_move(): return _load("movement.json")

def grid_tile(rows, cx, cy):
    w = max(len(r) for r in rows); h = len(rows)
    if cx < 0 or cx >= w or cy >= h: return "#"
    if cy < 0: return "."
    row = rows[cy]
    return row[cx] if cx < len(row) else "."

def move_blocked(P, rows, x, y, h):
    T = P["tile"]; hw = P["hw"]
    for cy in range(_math.floor((y - h) / T), _math.floor((y - MOVE_EPS) / T) + 1):
        for cx in range(_math.floor((x - hw) / T), _math.floor((x + hw - MOVE_EPS) / T) + 1):
            if grid_tile(rows, cx, cy) == "#": return True
    return False

def move_make(P, spec):
    return {"x": float(spec["x"]), "y": float(spec["y"]), "vx": 0.0, "vy": 0.0, "on_ground": bool(spec.get("on_ground", False)),
            "crouching": bool(spec.get("crouching", False)), "fuel": float(spec.get("fuel", P["jet_fuel_max"])),
            "jet_lock": 0.0, "jetting": False}

def _approach(a, target, d): return min(a + d, target) if a < target else max(a - d, target)

def move_step(P, rows, st, inp, dt):
    s = dict(st); T = P["tile"]; hw = P["hw"]
    if inp.get("crouch") and s["on_ground"]: s["crouching"] = True
    elif s["crouching"] and not inp.get("crouch"):
        if not move_blocked(P, rows, s["x"], s["y"], P["h_stand"]): s["crouching"] = False
    h = P["h_crouch"] if s["crouching"] else P["h_stand"]
    mv = clamp(float(inp.get("move", 0.0)), -1.0, 1.0)
    speed = P["walk_speed"] * P["crouch_mult"] if (s["crouching"] and s["on_ground"]) else (P["walk_speed"] if s["on_ground"] else P["air_speed"])
    s["vx"] = _approach(s["vx"], mv * speed, (P["ground_accel"] if s["on_ground"] else P["air_accel"]) * dt)
    if inp.get("jump") and s["on_ground"] and not s["crouching"]:
        s["vy"] = -P["jump_speed"]; s["on_ground"] = False
    jetting = False
    if inp.get("jet") and s["fuel"] > 0 and s["jet_lock"] <= 0:
        if s["vy"] > -P["jet_max_rise"]: s["vy"] = max(s["vy"] - P["jet_accel"] * dt, -P["jet_max_rise"])
        s["fuel"] = max(0.0, s["fuel"] - P["jet_drain"] * dt); jetting = True; s["on_ground"] = False
        if s["fuel"] <= 0: s["jet_lock"] = P["jet_lock"]
    s["jetting"] = jetting
    s["vy"] = min(s["vy"] + P["gravity"] * dt, P["max_fall"])
    if not jetting:
        if s["jet_lock"] > 0: s["jet_lock"] = max(0.0, s["jet_lock"] - dt)
        else: s["fuel"] = min(P["jet_fuel_max"], s["fuel"] + (P["jet_regen_ground"] if s["on_ground"] else P["jet_regen_air"]) * dt)
    # horizontal move
    nx = s["x"] + s["vx"] * dt
    r0 = _math.floor((s["y"] - h) / T); r1 = _math.floor((s["y"] - MOVE_EPS) / T)
    if s["vx"] > 0:
        col = _math.floor((nx + hw - MOVE_EPS) / T)
        if any(grid_tile(rows, col, r) == "#" for r in range(r0, r1 + 1)): nx = col * T - hw; s["vx"] = 0.0
    elif s["vx"] < 0:
        col = _math.floor((nx - hw) / T)
        if any(grid_tile(rows, col, r) == "#" for r in range(r0, r1 + 1)): nx = (col + 1) * T + hw; s["vx"] = 0.0
    s["x"] = nx
    # vertical move
    ny = s["y"] + s["vy"] * dt; old_bottom = s["y"]; old_top = s["y"] - h
    c0 = _math.floor((s["x"] - hw) / T); c1 = _math.floor((s["x"] + hw - MOVE_EPS) / T)
    landed = False
    if s["vy"] >= 0:
        r = _math.floor(ny / T); b = r * T
        if old_bottom <= b + MOVE_EPS and any(grid_tile(rows, c, r) in ("#", "=") for c in range(c0, c1 + 1)):
            ny = float(b); s["vy"] = 0.0; landed = True
    else:
        r = _math.floor((ny - h) / T); edge = (r + 1) * T
        if old_top >= edge - MOVE_EPS and any(grid_tile(rows, c, r) == "#" for c in range(c0, c1 + 1)):
            ny = float(edge + h); s["vy"] = 0.0
    s["y"] = ny; s["on_ground"] = landed
    return s
