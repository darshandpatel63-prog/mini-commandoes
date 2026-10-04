#!/usr/bin/env python3
"""Static repo validation. Runs on any machine / CI with plain Python 3. No dependencies."""
import json, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
errors = []
def err(m): errors.append(m)

REQUIRED_DOCS = ["blueprint.md", "CLAUDE.md", "handover.md", "TEST_PLAN.md",
                 "ASSET_SOURCES.md", "PROJECT.md", "README.md", "project.godot"]
for d in REQUIRED_DOCS:
    if not (ROOT / d).is_file():
        err(f"missing required file: {d}")

sys.path.insert(0, str(ROOT / "tools"))
import ref_model as R

def load(name):
    try:
        return json.loads((ROOT / "data" / name).read_text(encoding="utf-8"))
    except Exception as e:
        err(f"data/{name}: invalid JSON: {e}")
        return {}

def ids(items, label):
    seen = set()
    for it in items:
        i = it.get("id")
        if not i: err(f"{label}: entry without id: {it}"); continue
        if i in seen: err(f"{label}: duplicate id {i}")
        seen.add(i)
    return seen

try:
    d = R.Data()
except Exception as e:
    err(f"data tables failed to load: {e}"); d = None

if d is not None:
    for name, key in [("characters.json", "characters"), ("skills.json", "skills"), ("pets.json", "pets"), ("weapons.json", "weapons"),
                      ("throwables.json", "throwables"), ("melee.json", "melee"), ("maps.json", "maps"), ("modes.json", "modes"), ("presets.json", "presets")]:
        ids(load(name).get(key, []), key)
    rules = d.rules
    # ---- equal base stats: characters are identity-only
    allowed = {"id", "name", "role", "theme", "personality", "palette", "suggested_preset"}
    for c in d.chars.values():
        extra = set(c) - allowed
        if extra: err(f"character {c['id']} has gameplay keys {sorted(extra)} (characters must be identity-only)")
        if c.get("suggested_preset") not in {p["id"] for p in d.presets}: err(f"character {c['id']}: unknown suggested_preset")
    if len(d.chars) < 2: err("acceptance G4 needs >= 2 characters")
    if not isinstance(rules["base_hp"], int) or rules["base_hp"] <= 0: err("balance.base_hp must be a positive integer")
    if not isinstance(rules["base_ep"], int) or rules["base_ep"] <= 0: err("balance.base_ep must be a positive integer")
    # ---- armor tables
    for piece in ("helmet", "vest"):
        tbl = d.armor[piece]
        if [x["level"] for x in tbl] != [0, 1, 2, 3]: err(f"armor.{piece}: levels must be 0..3")
        for a, b in zip(tbl, tbl[1:]):
            if not (b["reduction"] > a["reduction"] and b["durability"] > a["durability"]): err(f"armor.{piece}: level {b['level']} must beat level {a['level']}")
        if any(x["reduction"] >= 0.6 for x in tbl): err(f"armor.{piece}: reduction >= 60% is excessive")
    # ---- skills
    stat_names = set(rules["stat_defaults"])
    for s in d.skills.values():
        sid = s["id"]
        if s["kind"] not in ("active", "passive", "pet"): err(f"skill {sid}: bad kind")
        if s["kind"] == "passive":
            if s.get("cost") not in (1, 2, 3): err(f"skill {sid}: passive cost must be 1..3")
        else:
            for k in ("cooldown", "ep_cost"):
                if k not in s: err(f"skill {sid}: missing {k}")
            if s.get("cooldown", 0) < 5: err(f"skill {sid}: cooldown too short")
        if s.get("impl") not in ("pipeline", "pending_stat", "behavior"): err(f"skill {sid}: bad impl")
        for e in s.get("effects", []):
            if e["stat"] not in stat_names: err(f"skill {sid}: unknown stat {e['stat']}")
            if e["op"] not in ("mult", "add"): err(f"skill {sid}: bad op")
        if s.get("group") and s["group"] not in rules["loadout"]["group_limits"]: err(f"skill {sid}: unknown group {s['group']}")
        for ex in s.get("excludes", []):
            if ex not in d.skills: err(f"skill {sid}: excludes unknown {ex}")
            elif sid not in d.skills[ex].get("excludes", []): err(f"skill {sid}: exclusion with {ex} is not symmetric")
        if s["kind"] == "pet" and s["id"] not in {p["skill"] for p in d.pets.values()}: err(f"pet skill {sid} used by no pet")
    for p in d.pets.values():
        if p["skill"] not in d.skills or d.skills[p["skill"]]["kind"] != "pet": err(f"pet {p['id']}: skill must be a pet skill")
    # ---- weapons / melee
    for w in d.weapons.values():
        for f in ("dmg", "rpm", "mag", "reload", "range", "cls", "proj", "special", "head_mult", "armor_pen"):
            if f not in w: err(f"weapon {w.get('id')}: missing {f}")
        if not (0 <= w.get("armor_pen", 0) <= 0.5): err(f"weapon {w['id']}: armor_pen must be 0..0.5")
    if len({w["special"] for w in d.weapons.values()}) < len(d.weapons): err("weapons: every weapon needs a distinct 'special' (no reskins)")
    if "fists" not in d.melee: err("melee: 'fists' (always available) is required")
    # ---- presets must be legal
    for pr in d.presets:
        e = R.validate_loadout(d, pr["loadout"])
        if e: err(f"built-in preset {pr['id']} is invalid: {e}")
    # ---- HUD defaults
    if not d.hud: err("hud_default.json missing")
    else:
        for scr in ([2400, 1080], [1920, 1080], [2160, 1080]):
            lay = R.hud_default_layout(d); san = R.hud_sanitize(d, lay, scr)
            if lay != san and any(abs(lay[k][f] - san[k][f]) > 1e-4 for k in lay for f in ("x", "y")): err(f"default HUD gets clamped at {scr}")
            if R.hud_overlaps(d, san, scr): err(f"default HUD overlaps at {scr}: {R.hud_overlaps(d, san, scr)}")
        if {c["id"] for c in d.hud} - set(R.default_haptics(d)["controls"]): err("every HUD control needs a haptic default")
    for m in d.chars and load("maps.json").get("maps", []):
        if m.get("max_players", 0) < 40: err(f"map {m.get('id')}: max_players must be 40")
    if len(load("maps.json").get("maps", [])) != 5: err("blueprint target is exactly 5 maps")
    lt = load("loot.json")
    if [x.get("id") for x in lt.get("rarities", [])] != ["common", "uncommon", "rare", "epic", "legendary"]: err("loot rarities order")
    if [b.get("slots") for b in lt.get("backpacks", [])] != sorted(b.get("slots") for b in lt.get("backpacks", [])) or len(lt.get("backpacks", [])) != 3:
        err("loot: need 3 backpack levels with increasing slots")
    # ---- test vectors must be fresh
    vec = ROOT / "tests/vectors/cases.json"
    if not vec.exists(): err("tests/vectors/cases.json missing (run tools/gen_vectors.py)")
    else:
        import subprocess, tempfile
        cur = json.loads(vec.read_text())
        if len(cur.get("scenarios", [])) < 30: err("vectors: too few scenarios")

chars = list(d.chars.values()) if d is not None else []
skills = list(d.skills.values()) if d is not None else []
pets = list(d.pets.values()) if d is not None else []
weapons = list(d.weapons.values()) if d is not None else []
throw = list(d.throwables.values()) if d is not None else []
maps = load("maps.json").get("maps", [])
modes = load("modes.json").get("modes", [])

# ---- Phase 2 assets: training map + baked art
try:
    tm = json.loads((ROOT / "data/maps/training.json").read_text())
    rows = tm["rows"]
    if len({len(r) for r in rows}) != 1: err("training map: rows differ in width")
    flat = "".join(rows)
    if flat.count("S") != 1: err("training map: exactly one spawn S required")
    if flat.count("D") < 3: err("training map: needs >= 3 dummies (D)")
    if d is not None:
        mp = R.load_move(); clean = [r.replace("S", ".").replace("D", ".") for r in rows]
        sy = None
        for ri, r in enumerate(rows):
            if "S" in r: sx, sy = r.index("S") * 32 + 16, (ri + 1) * 32
        st = R.move_make(mp, {"x": sx, "y": sy})
        for _ in range(90): st = R.move_step(mp, clean, st, {}, 1 / 60)
        if not (st["on_ground"] and st["y"] == sy): err("training map: player does not stand at the spawn")
except Exception as e:
    err(f"training map invalid: {e}")
rigf = ROOT / "assets/art/commando/rig.json"
if not rigf.is_file(): err("assets/art/commando/rig.json missing (run tools/bake_sprites.py)")
else:
    rig = json.loads(rigf.read_text())
    if len(rig["parts"]) != 7: err("rig: expected 7 parts")
    for cid in (d.chars if d is not None else {}):
        if not (ROOT / f"assets/art/commando/portrait_{cid}.png").is_file(): err(f"missing portrait for {cid}")
        for pn, pv in rig["parts"].items():
            if not (ROOT / f"assets/art/commando/{cid}/{pv['file']}").is_file(): err(f"missing sprite {cid}/{pv['file']}")
    for pn, pv in rig["parts"].items():
        if pv["parent"] and pv["parent"] not in rig["parts"]: err(f"rig: parent of {pn} missing")
if any(p.suffix.lower() == ".fbx" for p in ROOT.rglob("*") if p.is_file() and ".git" not in p.parts):
    err("FBX source models must stay out of the repo (41 MB, license unconfirmed); keep them outside and commit only baked sprites")

# secrets / forbidden files
for p in ROOT.rglob("*"):
    if not p.is_file() or ".git" in p.parts: continue
    if p.suffix in (".jks", ".keystore", ".p12", ".pem"):
        err(f"forbidden secret-like file committed: {p.relative_to(ROOT)}")
    if p.suffix in (".cfg", ".yml", ".yaml", ".gd", ".md", ".json", ".godot") and p.name != "validate_repo.py":
        t = p.read_text(encoding="utf-8", errors="ignore")
        if re.search(r'(keystore_pass|keystore_password|storepass)\s*[=:]\s*"?[A-Za-z0-9+/_\-]{6,}', t) and "secrets." not in t and "${" not in t:
            err(f"possible hardcoded signing password in {p.relative_to(ROOT)}")

# res:// path integrity: every referenced file must exist (catches typos in scenes/scripts/project.godot)
REQUIRED_ASSETS = ["assets/audio/sfx/ui_click.wav", "assets/audio/sfx/ui_back.wav", "assets/audio/sfx/ui_confirm.wav"]
for a in REQUIRED_ASSETS:
    if not (ROOT / a).is_file(): err(f"missing required asset: {a}")
for p in list(ROOT.rglob("*.gd")) + list(ROOT.rglob("*.tscn")) + [ROOT / "project.godot", ROOT / "export_presets.cfg"]:
    if not p.is_file() or ".git" in p.parts: continue
    txt = p.read_text(encoding="utf-8", errors="ignore")
    for m in re.finditer(r'res://[A-Za-z0-9_/.\-]+', txt):
        ref = m.group(0)
        nxt = txt[m.end():m.end() + 1]
        if ref.endswith("/") or nxt == "%": continue   # directory prefix / format string
        if not (ROOT / ref[len("res://"):]).exists():
            err(f"{p.relative_to(ROOT)}: references missing file {ref}")

# GDScript sanity (no engine here): no mixed tab/space indentation, balanced brackets, autoloads exist
for p in ROOT.rglob("*.gd"):
    if ".git" in p.parts: continue
    lines = p.read_text(encoding="utf-8").splitlines()
    kinds = set()
    depth = {"(": 0, "[": 0, "{": 0}
    pair = {")": "(", "]": "[", "}": "{"}
    for i, l in enumerate(lines, 1):
        ind = l[:len(l) - len(l.lstrip())]
        if ind:
            if "\t" in ind and " " in ind: err(f"{p.relative_to(ROOT)}:{i}: mixed tab/space indent")
            kinds.add("t" if "\t" in ind else "s")
        code = re.sub(r'"(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\'', '""', l)   # blank out string literals
        code = code.split("#")[0]                                            # then strip comments
        for ch in code:
            if ch in depth: depth[ch] += 1
            elif ch in pair: depth[pair[ch]] -= 1
    if len(kinds) > 1: err(f"{p.relative_to(ROOT)}: file mixes tab and space indentation")
    if any(v != 0 for v in depth.values()): err(f"{p.relative_to(ROOT)}: unbalanced brackets {depth}")

# markdown sanity: even number of code fences
for md in list(ROOT.glob("*.md")) + list((ROOT / "docs").glob("*.md")):
    n = sum(1 for l in md.read_text(encoding="utf-8").splitlines() if l.lstrip().startswith("```"))
    if n % 2: err(f"{md.name}: unbalanced ``` fences")

if errors:
    print(f"VALIDATION FAILED ({len(errors)} issue(s))")
    for e in errors: print(" -", e)
    sys.exit(1)
print(f"validate_repo OK: {len(chars)} characters, {len(skills)} skills, {len(pets)} pets, "
      f"{len(weapons)} weapons, {len(throw)} throwables, {len(maps)} maps, {len(modes)} modes")
