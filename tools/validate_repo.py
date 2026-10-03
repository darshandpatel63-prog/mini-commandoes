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

def load(name):
    p = ROOT / "data" / name
    try:
        return json.loads(p.read_text(encoding="utf-8"))
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

chars = load("characters.json").get("characters", [])
skills = load("skills.json").get("skills", [])
pets = load("pets.json").get("pets", [])
weapons = load("weapons.json").get("weapons", [])
throw = load("throwables.json").get("throwables", [])
maps = load("maps.json").get("maps", [])
modes = load("modes.json").get("modes", [])
loot = load("loot.json")

skill_ids = ids(skills, "skills"); pet_ids = ids(pets, "pets")
ids(chars, "characters"); ids(weapons, "weapons"); ids(throw, "throwables"); ids(maps, "maps"); ids(modes, "modes")
skill_by_id = {s["id"]: s for s in skills if "id" in s}

# G10: each character = 1 active + 4 passive + 1 pet skill
for c in chars:
    cid = c.get("id", "?")
    if c.get("active") not in skill_ids: err(f"{cid}: unknown active skill")
    elif skill_by_id[c["active"]]["kind"] != "active": err(f"{cid}: active slot is not kind=active")
    ps = c.get("passives", [])
    if len(ps) != 4: err(f"{cid}: needs exactly 4 passives, has {len(ps)}")
    for p in ps:
        if p not in skill_ids: err(f"{cid}: unknown passive {p}")
        elif skill_by_id[p]["kind"] != "passive": err(f"{cid}: {p} is not kind=passive")
    if c.get("pet") not in pet_ids: err(f"{cid}: unknown pet {c.get('pet')}")
    ps_id = c.get("pet_skill")
    if ps_id not in skill_ids: err(f"{cid}: unknown pet skill")
    elif skill_by_id[ps_id]["kind"] != "pet": err(f"{cid}: pet_skill not kind=pet")
for p in pets:
    if p.get("skill") not in skill_ids: err(f"pet {p.get('id')}: unknown skill")
used = set()
for c in chars: used.update([c.get("active"), c.get("pet_skill")] + c.get("passives", []))
for s in skills:
    if s["id"] not in used: err(f"skill {s['id']} is not used by any character")
if len(chars) < 2: err("acceptance G6 needs >= 2 characters")

for w in weapons:
    for f in ("dmg", "rpm", "mag", "reload", "range", "cls", "proj", "special"):
        if f not in w: err(f"weapon {w.get('id')}: missing {f}")
if len({w["special"] for w in weapons if "special" in w}) < len(weapons):
    err("weapons: every weapon needs a distinct 'special' (no reskins)")
for m in maps:
    if m.get("max_players", 0) < 40: err(f"map {m.get('id')}: max_players must be 40")
if len(maps) != 5: err("blueprint target is exactly 5 maps")
r = loot.get("rarities", [])
if [x.get("id") for x in r] != ["common", "uncommon", "rare", "epic", "legendary"]: err("loot rarities order")
if [b.get("slots") for b in loot.get("backpacks", [])] != sorted(b.get("slots") for b in loot.get("backpacks", [])) or len(loot.get("backpacks", [])) != 3:
    err("loot: need 3 backpack levels with increasing slots")

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
