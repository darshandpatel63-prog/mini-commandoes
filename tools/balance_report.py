#!/usr/bin/env python3
"""Prints effective-HP / shots-to-kill tables from the reference model (analysis tool, not shipped)."""
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import ref_model as R
d = R.Data()

def shots_to_kill(weapon, zone, helm, vest, passives=()):
    w = d.weapons[weapon]; n = 0
    st = R.make_state(d, {"helmet": [helm], "vest": [vest], "passives": list(passives)})
    per = w.get("pellets", 1)
    while st["alive"] and n < 500:
        for _ in range(per):
            hit = {"damage": w["dmg"], "zone": zone, "head_mult": w["head_mult"], "armor_pen": w["armor_pen"]}
            st, _ = R.apply_hit(d, st, hit, 0.0)
        n += 1
    return n

def ehp_ratio(zone, level, weapon="vanguard_ar"):
    w = d.weapons[weapon]
    dmg = w["dmg"] * (w["head_mult"] if zone == "head" else 1)
    st = R.make_state(d, {"helmet": [level] if zone == "head" else [0], "vest": [level] if zone == "body" else [0]})
    total = 0.0
    while st["alive"]:
        st, rep = R.apply_hit(d, st, {"damage": w["dmg"], "zone": zone, "head_mult": w["head_mult"], "armor_pen": w["armor_pen"]}, 0.0)
        total += dmg
    return total / d.rules["base_hp"]

print("Base HP", d.rules["base_hp"], " Base EP", d.rules["base_ep"], "(identical for every character)\n")
print("Effective HP multiplier (damage needed to kill / base HP), AR-7, fresh armor")
print("level | helmet(head) | vest(body)")
for lv in range(4): print(f"  L{lv}  |   x{ehp_ratio('head', lv):.2f}      |  x{ehp_ratio('body', lv):.2f}")
print("\nShots to kill (one weapon, fresh armor)")
print(f"{'weapon':<20}{'zone':<6}" + "".join(f"L{l}/L{l:<4}" for l in range(4)))
for wid in ["vanguard_ar", "sidewinder_smg", "hammerhead_sg", "longshot_sr", "peacekeeper_pistol", "scrapper_dmr"]:
    for zone in ("body", "head"):
        row = "".join(f"{shots_to_kill(wid, zone, l, l):<7}" for l in range(4))
        print(f"{wid:<20}{zone:<6}{row}")
print("\nBuilds: AR-7 body shots to kill with skills (vest L2)")
for name, ps in [("none", []), ("combat_conditioning", ["combat_conditioning"]), ("energy_barrier (EP 100)", ["energy_barrier"]), ("both mitigation (illegal)", ["combat_conditioning", "energy_barrier"])]:
    print(f"  {name:<28}", shots_to_kill("vanguard_ar", "body", 0, 2, ps))
